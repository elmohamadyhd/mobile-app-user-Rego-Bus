import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:rego/features/wallet/presentation/widgets/wallet_app_bar.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

/// Terminal outcome signalled by a wallet top-up WebView navigation — same
/// `success-payment`/`failed-payment` redirect targets as the bus payment
/// flow (both go through the MyFatoorah gateway). Copied rather than shared
/// with the bus feature; see the wallet design spec.
enum WalletPaymentNavResult { success, failure, pending }

/// Pure classifier for a wallet payment WebView navigation [uri].
WalletPaymentNavResult classifyWalletPaymentNav(Uri uri) {
  final path = uri.path.toLowerCase();
  if (path.contains('success-payment')) return WalletPaymentNavResult.success;
  if (path.contains('failed-payment')) return WalletPaymentNavResult.failure;
  return WalletPaymentNavResult.pending;
}

/// Shows the "leave payment?" confirmation when the rider tries to back out
/// of the top-up checkout before it's resolved. Returns true only if they
/// explicitly chose to leave.
Future<bool> confirmLeaveWalletPayment(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.45),
    builder: (dialogContext) => const _WalletLeavePaymentDialog(),
  );
  return leave ?? false;
}

class _WalletLeavePaymentDialog extends StatelessWidget {
  const _WalletLeavePaymentDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final maxWidth = MediaQuery.sizeOf(context).width * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.secondaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    AppIcons.wallet,
                    color: AppColors.secondary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.paymentLeaveTitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.h2.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.paymentLeaveBody,
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: l10n.paymentLeaveStay,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(height: AppSpacing.sm),
                PrimaryButton(
                  label: l10n.paymentLeaveConfirm,
                  variant: PrimaryButtonVariant.ghost,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _WalletTopUpOutcome { success, failed, pending }

/// Loads the top-up checkout in a WebView. There is no charge-status
/// endpoint, so a terminal redirect (or the rider tapping "Done") triggers a
/// wallet refresh and compares the new balance to the one captured on entry —
/// see the design spec's "Payment WebView" verification table.
class WalletPaymentWebViewScreen extends ConsumerStatefulWidget {
  const WalletPaymentWebViewScreen({super.key, required this.checkoutUrl});

  final String checkoutUrl;

  @override
  ConsumerState<WalletPaymentWebViewScreen> createState() =>
      _WalletPaymentWebViewScreenState();
}

class _WalletPaymentWebViewScreenState
    extends ConsumerState<WalletPaymentWebViewScreen> {
  WebViewController? _controller;
  bool _loading = true;
  bool _verifyTriggered = false;
  bool _leavePromptOpen = false;
  bool _verifying = false;
  double? _balanceBefore;

  @override
  void initState() {
    super.initState();
    _balanceBefore = ref.read(walletProvider).value?.balance;
    unawaited(_init());
  }

  Future<void> _init() async {
    final uri = Uri.parse(widget.checkoutUrl);

    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onNavigationRequest: (request) => _handleNavigation(request.url),
        onUrlChange: (change) {
          final url = change.url;
          if (url != null) _handleNavigation(url);
        },
      ),
    );
    await controller.loadRequest(uri);

    if (mounted) setState(() => _controller = controller);
  }

  NavigationDecision _handleNavigation(String url) {
    final uri = Uri.tryParse(url);
    final result = uri == null
        ? WalletPaymentNavResult.pending
        : classifyWalletPaymentNav(uri);
    if (result == WalletPaymentNavResult.pending) {
      return NavigationDecision.navigate;
    }
    unawaited(_verify(result));
    return NavigationDecision.prevent;
  }

  Future<void> _verify([WalletPaymentNavResult? redirectResult]) async {
    if (_verifyTriggered) return;
    _verifyTriggered = true;

    if (mounted) setState(() => _verifying = true);

    var outcome = _WalletTopUpOutcome.pending;
    if (redirectResult == WalletPaymentNavResult.failure) {
      outcome = _WalletTopUpOutcome.failed;
    } else {
      try {
        final before = _balanceBefore;
        await ref.read(walletProvider.notifier).refresh();
        final after = ref.read(walletProvider).value?.balance;
        if (before != null && after != null && after > before) {
          outcome = _WalletTopUpOutcome.success;
        }
      } catch (_) {
        // Refresh failure leaves `outcome` as pending — the balance is
        // simply unconfirmed, not a payment failure.
      }
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _verifying = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            switch (outcome) {
              _WalletTopUpOutcome.success => l10n.walletPaymentSuccessToast,
              _WalletTopUpOutcome.failed => l10n.walletPaymentFailedToast,
              _WalletTopUpOutcome.pending => l10n.walletPaymentPendingToast,
            },
          ),
        ),
      );
    if (context.mounted) context.pop();
  }

  Future<void> _handleBackRequest() async {
    if (_leavePromptOpen) return;
    _leavePromptOpen = true;
    final leave = await confirmLeaveWalletPayment(context);
    _leavePromptOpen = false;
    if (leave) {
      unawaited(_verify());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = _controller;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_handleBackRequest());
      },
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: WalletAppBar(
          title: l10n.paymentTitle,
          onBack: () => unawaited(_handleBackRequest()),
          action: TextButton(
            onPressed: _verifying ? null : () => unawaited(_verify()),
            child: Text(
              l10n.paymentDone,
              style: AppTypography.body.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            if (controller != null)
              WebViewWidget(controller: controller)
            else
              const SizedBox.shrink(),
            if (controller == null || _loading || _verifying)
              ColoredBox(
                color: AppColors.bgBase.withValues(alpha: 0.72),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      if (_verifying) ...[
                        const SizedBox(height: 16),
                        Text(
                          l10n.paymentVerifying,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
