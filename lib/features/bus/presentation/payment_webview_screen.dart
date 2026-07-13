import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:rego/core/providers/locale_controller.dart';
import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

/// Terminal outcome signalled by a payment WebView navigation. The gateway's
/// hosted checkout (MyFatoorah) redirects back to the REGO site at
/// `/{locale}/success-payment` or `/{locale}/failed-payment` once the rider
/// finishes, so we key off that path segment — it's independent of locale and
/// of which gateway/subdomain served the checkout.
enum PaymentNavResult { success, failure, pending }

/// Pure classifier for a payment WebView navigation [uri]. Anything that isn't
/// one of the two known redirect targets is still in progress ([pending]).
PaymentNavResult classifyPaymentNav(Uri uri) {
  final path = uri.path.toLowerCase();
  if (path.contains('success-payment')) return PaymentNavResult.success;
  if (path.contains('failed-payment')) return PaymentNavResult.failure;
  return PaymentNavResult.pending;
}

/// Shows the "leave payment?" confirmation the rider sees when they try to
/// back out of the checkout WebView before it's resolved. Returns true only
/// if they explicitly chose to leave; false (including a dismissed dialog)
/// means stay on the checkout page.
Future<bool> confirmLeavePayment(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.45),
    builder: (dialogContext) => const _LeavePaymentDialog(),
  );
  return leave ?? false;
}

/// Skyline-styled confirmation shown when the rider tries to back out of the
/// hosted checkout before it resolves.
class _LeavePaymentDialog extends StatelessWidget {
  const _LeavePaymentDialog();

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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryTint,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    l10n.paymentPendingBadge,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
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
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      AppIcons.checkCircle,
                      size: 16,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        l10n.paymentLeaveReassure,
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
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

/// In-app payment screen: loads the order's gateway checkout URL
/// (`payment_data.invoice_url`, the MyFatoorah hosted invoice page) in a
/// WebView. When the gateway redirects back to REGO's success/failure page —
/// or the rider taps "Done" — it asks the notifier to verify the order's real
/// status, then routes to the e-ticket (paid) or the pending screen.
class PaymentWebViewScreen extends ConsumerStatefulWidget {
  const PaymentWebViewScreen({super.key});

  @override
  ConsumerState<PaymentWebViewScreen> createState() =>
      _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends ConsumerState<PaymentWebViewScreen> {
  WebViewController? _controller;
  bool _loading = true;
  bool _verifyTriggered = false;
  bool _leavePromptOpen = false;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    final ticket = ref.read(busBookingProvider).ticket;
    final paymentUrl = ticket?.paymentUrl ?? '';
    if (paymentUrl.isEmpty) {
      // Nothing to pay for — verify immediately (defensive; the confirm screen
      // only routes here when a checkout URL exists).
      unawaited(_verify());
      return;
    }

    final uri = Uri.parse(paymentUrl);
    final lang = ref.read(localeControllerProvider).languageCode;

    // The checkout page is normally the third-party gateway (MyFatoorah), which
    // must never receive our bearer token. Only attach it when the URL is our
    // own backend — i.e. the defensive `/pay` fallback on `*.wdenytravel.com`.
    final headers = <String, String>{'Accept-Language': lang};
    if (uri.host.toLowerCase().endsWith('wdenytravel.com')) {
      final token = await ref.read(secureStorageProvider).readToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

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
    await controller.loadRequest(uri, headers: headers);

    if (mounted) setState(() => _controller = controller);
  }

  /// Watches for the gateway's success/failure redirect. Either terminal
  /// outcome triggers an authoritative status check — we never trust the
  /// client-side redirect alone to grant a paid ticket — and the redirect page
  /// itself is not loaded (we've left the checkout at that point).
  NavigationDecision _handleNavigation(String url) {
    final uri = Uri.tryParse(url);
    final result =
        uri == null ? PaymentNavResult.pending : classifyPaymentNav(uri);
    if (result == PaymentNavResult.pending) {
      return NavigationDecision.navigate;
    }
    unawaited(_verify());
    return NavigationDecision.prevent;
  }

  Future<void> _verify() async {
    if (_verifyTriggered) return;
    _verifyTriggered = true;
    await ref.read(busBookingProvider.notifier).verifyPayment();
  }

  Future<void> _handleBackRequest() async {
    if (_leavePromptOpen) return;
    _leavePromptOpen = true;
    final leave = await confirmLeavePayment(context);
    _leavePromptOpen = false;
    if (leave) {
      unawaited(_verify());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    ref.listen<BusBookingState>(busBookingProvider, (prev, next) {
      if (next.status == BusBookingStatus.confirmed) {
        context.pushReplacement(BusRoutes.ticket);
      } else if (next.status == BusBookingStatus.paymentPending) {
        context.pushReplacement(BusRoutes.pending);
      }
    });

    final isVerifying = ref.watch(busBookingProvider).status ==
        BusBookingStatus.verifyingPayment;
    final controller = _controller;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_handleBackRequest());
      },
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: BookingAppBar(
          title: l10n.paymentTitle,
          onBack: () => unawaited(_handleBackRequest()),
          action: TextButton(
            onPressed: isVerifying ? null : () => unawaited(_verify()),
            style: TextButton.styleFrom(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.sm,
              ),
            ),
            child: Text(
              l10n.paymentDone,
              maxLines: 1,
              softWrap: false,
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
            if (controller == null || _loading || isVerifying)
              _LoadingOverlay(
                label: isVerifying ? l10n.paymentVerifying : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgBase.withValues(alpha: 0.72),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (label != null) ...[
              const SizedBox(height: 16),
              Text(
                label!,
                style:
                    AppTypography.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
