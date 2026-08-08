import 'package:go_router/go_router.dart';

import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/presentation/flight_bundles_screen.dart';
import 'package:safaria/features/flight/presentation/flight_offer_details_screen.dart';
import 'package:safaria/features/flight/presentation/flight_passenger_form_screen.dart';
import 'package:safaria/features/flight/presentation/flight_passengers_screen.dart';
import 'package:safaria/features/flight/presentation/flight_pay_screen.dart';
import 'package:safaria/features/flight/presentation/flight_results_screen.dart';
import 'package:safaria/features/flight/presentation/flight_review_screen.dart';

abstract final class FlightRoutes {
  static const results = '/flight/results';
  static const offerDetails = '/flight/offer-details';
  static const review = '/flight/review';
  static const bundles = '/flight/bundles';
  static const passengers = '/flight/passengers';
  static const passengerForm = '/flight/passengers/form';

  /// The wizard's step 4 (review and pay); `pay` is the checkout WebView.
  /// Keeping them distinct matters because the WebView must not be
  /// reachable without a created order.
  static const payReview = '/flight/pay-review';
  static const pay = '/flight/pay';
  static const pending = '/flight/pending';
  static const ticket = '/flight/ticket';
}

List<RouteBase> flightRoutes() => [
      GoRoute(
        path: FlightRoutes.results,
        builder: (context, state) => const FlightResultsScreen(),
      ),
      GoRoute(
        path: FlightRoutes.offerDetails,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! FlightOffer) {
            return const FlightResultsScreen();
          }
          return FlightOfferDetailsScreen(offer: extra);
        },
      ),
      GoRoute(
        path: FlightRoutes.review,
        builder: (context, state) => const FlightReviewScreen(),
      ),
      GoRoute(
        path: FlightRoutes.bundles,
        builder: (context, state) => const FlightBundlesScreen(),
      ),
      GoRoute(
        path: FlightRoutes.passengers,
        builder: (context, state) => const FlightPassengersScreen(),
      ),
      GoRoute(
        path: FlightRoutes.passengerForm,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! int) return const FlightPassengersScreen();
          return FlightPassengerFormScreen(index: extra);
        },
      ),
      GoRoute(
        path: FlightRoutes.payReview,
        builder: (context, state) => const FlightPayScreen(),
      ),
    ];
