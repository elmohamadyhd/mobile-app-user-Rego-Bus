import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:rego/core/providers/locale_controller.dart';
import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:rego/l10n/app_localizations.dart';

/// Where a payment-gateway navigation currently sits, used to decide when the
/// rider has finished at the gateway and control has returned to our backend.
enum PaymentNavPhase { atGateway, returnedToBackend, other }

/// Pure classifier for a payment WebView navigation. [backendHost] is the host
/// that served the `payment_url` (the merchant/backend), so a navigation back
/// to it — after having visited the gateway — signals the gateway handed
/// control back. [gatewayHostPart] is matched as a substring so both
/// `demo.MyFatoorah.com` and `MyFatoorah.com` resolve.
PaymentNavPhase classifyPaymentNav(
  Uri uri, {
  required String gatewayHostPart,
  required String backendHost,
}) {
  final host = uri.host.toLowerCase();
  if (host.isEmpty) return PaymentNavPhase.other;
  if (host.contains(gatewayHostPart.toLowerCase())) {
    return PaymentNavPhase.atGateway;
  }
  if (backendHost.isNotEmpty && host == backendHost.toLowerCase()) {
    return PaymentNavPhase.returnedToBackend;
  }
  return PaymentNavPhase.other;
}

/// In-app payment screen: loads the order's `payment_url` (MyFatoorah hosted
/// checkout) in a WebView. When the gateway hands control back to our backend
/// — or the rider taps "Done" — it asks the notifier to verify the order's
/// real status, then routes to the e-ticket (paid) or the pending screen.
class PaymentWebViewScreen extends ConsumerStatefulWidget {
  const PaymentWebViewScreen({super.key});

  @override
  ConsumerState<PaymentWebViewScreen> createState() =>
      _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends ConsumerState<PaymentWebViewScreen> {
  static const _gatewayHostPart = 'myfatoorah';

  WebViewController? _controller;
  bool _loading = true;
  bool _visitedGateway = false;
  bool _verifyTriggered = false;
  String _backendHost = '';

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
      // only routes here when a payment_url exists).
      unawaited(_verify());
      return;
    }

    final uri = Uri.parse(paymentUrl);
    _backendHost = uri.host;

    final token = await ref.read(secureStorageProvider).readToken();
    final lang = ref.read(localeControllerProvider).languageCode;

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
        onNavigationRequest: (request) {
          _handleNavigation(request.url);
          return NavigationDecision.navigate;
        },
        onUrlChange: (change) {
          final url = change.url;
          if (url != null) _handleNavigation(url);
        },
      ),
    );
    await controller.loadRequest(
      uri,
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        'Accept-Language': lang,
      },
    );

    if (mounted) setState(() => _controller = controller);
  }

  /// Tracks gateway ↔ backend transitions; once the rider has been to the
  /// gateway and navigation returns to our backend host, verify the order.
  void _handleNavigation(String url) {
    final phase = classifyPaymentNav(
      Uri.parse(url),
      gatewayHostPart: _gatewayHostPart,
      backendHost: _backendHost,
    );
    if (phase == PaymentNavPhase.atGateway) {
      _visitedGateway = true;
    } else if (phase == PaymentNavPhase.returnedToBackend && _visitedGateway) {
      unawaited(_verify());
    }
  }

  Future<void> _verify() async {
    if (_verifyTriggered) return;
    _verifyTriggered = true;
    await ref.read(busBookingProvider.notifier).verifyPayment();
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

    final isVerifying =
        ref.watch(busBookingProvider).status == BusBookingStatus.verifyingPayment;
    final controller = _controller;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(
        title: l10n.paymentTitle,
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
                style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
