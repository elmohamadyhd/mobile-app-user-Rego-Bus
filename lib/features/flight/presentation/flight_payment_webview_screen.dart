import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/features/bus/presentation/payment_webview_screen.dart'
    show classifyPaymentNav, confirmLeavePayment, PaymentNavResult;
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/domain/entities/flight_order.dart';
import 'package:safaria/features/flight/domain/utils/flight_order_status.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Hosted checkout for a freshly created [FlightOrder]. Mirrors
/// `payment_webview_screen.dart` in the bus feature — same navigation
/// classifier, same "never trust the redirect" verification, same
/// leave-payment confirmation.
class FlightPaymentWebViewScreen extends ConsumerStatefulWidget {
  const FlightPaymentWebViewScreen({super.key, required this.order});

  final FlightOrder order;

  @override
  ConsumerState<FlightPaymentWebViewScreen> createState() =>
      _FlightPaymentWebViewScreenState();
}

class _FlightPaymentWebViewScreenState
    extends ConsumerState<FlightPaymentWebViewScreen> {
  WebViewController? _controller;
  bool _loading = true;
  bool _verifyTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (request) => _handleNavigation(request.url),
        ),
      )
      ..loadRequest(Uri.parse(widget.order.checkoutUrl!));
  }

  NavigationDecision _handleNavigation(String url) {
    final result = classifyPaymentNav(Uri.parse(url));
    if (result == PaymentNavResult.pending) {
      return NavigationDecision.navigate;
    }
    // The redirect target is a REGO page we never want to render — it says
    // nothing the server has not already recorded. Verify instead.
    _verify();
    return NavigationDecision.prevent;
  }

  /// The redirect is a hint, not proof. Only the order endpoint decides.
  Future<void> _verify() async {
    if (_verifyTriggered) return;
    _verifyTriggered = true;
    final order =
        await ref.read(flightRepositoryProvider).order(widget.order.id);
    if (!mounted) return;
    final paid = order != null && isFlightOrderPaid(order);
    context.go(
      paid ? FlightRoutes.ticket : FlightRoutes.pending,
      extra: order ?? widget.order,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = _controller;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Abandoning mid-checkout leaves a real, resumable order behind, so
        // make it a deliberate choice rather than a stray back-swipe.
        if (await confirmLeavePayment(context) && context.mounted) {
          context.go(FlightRoutes.pending, extra: widget.order);
        }
      },
      child: Scaffold(
        appBar: BookingAppBar(title: l10n.flightPayTitle),
        body: Stack(
          children: [
            if (controller != null) WebViewWidget(controller: controller),
            if (_loading)
              const ColoredBox(
                color: AppColors.bgElevated,
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
