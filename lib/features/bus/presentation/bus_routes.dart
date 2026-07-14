import 'package:go_router/go_router.dart';

import 'package:rego/features/bus/presentation/trip_results_screen.dart';
import 'package:rego/features/bus/presentation/trip_details_screen.dart';
import 'package:rego/features/bus/presentation/seat_selection_screen.dart';
import 'package:rego/features/bus/presentation/passenger_confirm_screen.dart';
import 'package:rego/features/bus/presentation/payment_webview_screen.dart';
import 'package:rego/features/bus/presentation/payment_pending_screen.dart';
import 'package:rego/features/bus/presentation/eticket_screen.dart';

/// Bus booking route paths. URLs are unchanged from the pre-reshape router.
abstract final class BusRoutes {
  static const results = '/trips';
  static const detail = '/trips/detail';
  static const seats = '/trips/seats';
  static const confirm = '/trips/confirm';
  static const pay = '/booking/pay';
  static const pending = '/booking/pending';
  static const ticket = '/booking/ticket';
}

List<RouteBase> busRoutes() => [
      GoRoute(
        path: BusRoutes.results,
        builder: (context, state) => const TripResultsScreen(),
      ),
      GoRoute(
        path: BusRoutes.detail,
        builder: (context, state) => const BusTripDetailsScreen(),
      ),
      GoRoute(
        path: BusRoutes.seats,
        builder: (context, state) => const SeatSelectionScreen(),
      ),
      GoRoute(
        path: BusRoutes.confirm,
        builder: (context, state) => const PassengerConfirmScreen(),
      ),
      GoRoute(
        path: BusRoutes.pay,
        builder: (context, state) {
          final extra = state.extra;
          return PaymentWebViewScreen(
            args: extra is PaymentFlowArgs ? extra : null,
          );
        },
      ),
      GoRoute(
        path: BusRoutes.pending,
        builder: (context, state) => const PaymentPendingScreen(),
      ),
      GoRoute(
        path: BusRoutes.ticket,
        builder: (context, state) => const BusTicketScreen(),
      ),
    ];
