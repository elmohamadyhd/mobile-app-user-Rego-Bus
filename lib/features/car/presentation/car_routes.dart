import 'package:go_router/go_router.dart';

import 'package:rego/features/car/presentation/car_tier_results_screen.dart';

abstract final class CarRoutes {
  static const results = '/car/results';
}

List<RouteBase> carRoutes() => [
      GoRoute(
        path: CarRoutes.results,
        builder: (context, state) => const CarTierResultsScreen(),
      ),
    ];
