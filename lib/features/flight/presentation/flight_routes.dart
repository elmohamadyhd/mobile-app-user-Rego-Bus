import 'package:go_router/go_router.dart';

import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/presentation/flight_offer_details_screen.dart';
import 'package:safaria/features/flight/presentation/flight_results_screen.dart';
import 'package:safaria/features/flight/presentation/flight_review_screen.dart';

abstract final class FlightRoutes {
  static const results = '/flight/results';
  static const offerDetails = '/flight/offer-details';
  static const review = '/flight/review';
  static const bundles = '/flight/bundles';
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
      // Bundles screen lands in Task 8 — keep the path reserved so review can
      // push it. Until then, bounce to results.
      GoRoute(
        path: FlightRoutes.bundles,
        builder: (context, state) => const FlightResultsScreen(),
      ),
    ];
