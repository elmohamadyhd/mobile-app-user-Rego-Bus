import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:safaria/core/providers/locale_controller.dart';
import 'package:safaria/core/storage/secure_storage.dart';
import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/car/presentation/car_routes.dart';
import 'package:safaria/features/car/presentation/providers/car_booking_providers.dart';
import 'package:safaria/features/car/presentation/providers/car_orders_provider.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

enum CarPaymentNavResult { success, failure, pending }

CarPaymentNavResult classifyCarPaymentNav(Uri uri) {
  final path = uri.path.toLowerCase();
  if (path.contains('success-payment')) return CarPaymentNavResult.success;
  if (path.contains('failed-payment')) return CarPaymentNavResult.failure;
  return CarPaymentNavResult.pending;
}

Future<bool> confirmLeaveCarPayment(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.45),
    builder: (dialogContext) => const _LeavePaymentDialog(),
  );
  return leave ?? false;
}

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

enum CarPaymentFlowMode { booking, resume }

class CarPaymentFlowArgs {
  const CarPaymentFlowArgs({
    required this.checkoutUrl,
    required this.orderId,
    this.mode = CarPaymentFlowMode.resume,
  });

  final String checkoutUrl;
  final int orderId;
  final CarPaymentFlowMode mode;
}

class CarPaymentWebViewScreen extends ConsumerStatefulWidget {
  const CarPaymentWebViewScreen({super.key, this.args});

  final CarPaymentFlowArgs? args;

  @override
  ConsumerState<CarPaymentWebViewScreen> createState() =>
      _CarPaymentWebViewScreenState();
}

class _CarPaymentWebViewScreenState
    extends ConsumerState<CarPaymentWebViewScreen> {
  WebViewController? _controller;
  var _loading = true;
  var _verifyTriggered = false;
  var _leavePromptOpen = false;
  var _resumeVerifying = false;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    final args = widget.args;
    final paymentUrl = args != null
        ? args.checkoutUrl
        : ref.read(carBookingProvider).order?.invoiceUrl ?? '';
    if (paymentUrl.isEmpty) {
      unawaited(_verify());
      return;
    }

    final uri = Uri.parse(paymentUrl);
    final lang = ref.read(localeControllerProvider).languageCode;
    final headers = <String, String>{'Accept-Language': lang};
    if (uri.host.toLowerCase().endsWith('wdenytravel.com') ||
        uri.host.toLowerCase().endsWith('safaria.travel')) {
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

  NavigationDecision _handleNavigation(String url) {
    final uri = Uri.tryParse(url);
    final result =
        uri == null ? CarPaymentNavResult.pending : classifyCarPaymentNav(uri);
    if (result == CarPaymentNavResult.pending) {
      return NavigationDecision.navigate;
    }
    unawaited(_verify());
    return NavigationDecision.prevent;
  }

  Future<void> _verify() async {
    if (_verifyTriggered) return;
    _verifyTriggered = true;

    final args = widget.args;
    if (args == null) {
      await ref.read(carBookingProvider.notifier).verifyPayment();
      return;
    }
    await _verifyResume(args);
  }

  Future<void> _verifyResume(CarPaymentFlowArgs args) async {
    if (mounted) setState(() => _resumeVerifying = true);
    var isConfirmed = false;
    try {
      final order =
          await ref.read(carRepositoryProvider).getOrder(args.orderId);
      isConfirmed = order.isConfirmed;
      if (isConfirmed) {
        ref.read(carBookingProvider.notifier).hydrateOrder(order);
      }
    } catch (_) {
      isConfirmed = false;
    }
    ref.invalidate(carOrdersProvider);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _resumeVerifying = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            isConfirmed
                ? l10n.ticketResumePaidToast
                : l10n.ticketResumePendingToast,
          ),
        ),
      );
    if (isConfirmed && context.mounted) {
      context.go(CarRoutes.voucher);
      return;
    }
    if (context.mounted) context.pop();
  }

  Future<void> _handleBackRequest() async {
    if (_leavePromptOpen) return;
    _leavePromptOpen = true;
    final leave = await confirmLeaveCarPayment(context);
    _leavePromptOpen = false;
    if (leave) unawaited(_verify());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isResume = widget.args != null;

    ref.listen<CarBookingState>(carBookingProvider, (prev, next) {
      if (isResume) return;
      if (next.status == CarBookingStatus.confirmed) {
        context.go(CarRoutes.voucher);
      } else if (next.status == CarBookingStatus.paymentPending) {
        context.go(CarRoutes.pending);
      }
    });

    final isVerifying = isResume
        ? _resumeVerifying
        : ref.watch(carBookingProvider).status ==
            CarBookingStatus.verifyingPayment;
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
            if (controller != null) WebViewWidget(controller: controller),
            if (controller == null || _loading || isVerifying)
              ColoredBox(
                color: AppColors.bgBase.withValues(alpha: 0.72),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      if (isVerifying) ...[
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
