import 'package:go_router/go_router.dart';

import 'package:safaria/features/car/presentation/car_place_picker_args.dart';
import 'package:safaria/features/car/presentation/car_place_picker_screen.dart';
import 'package:safaria/features/car/presentation/car_tier_results_screen.dart';
import 'package:safaria/features/car/presentation/car_trip_details_screen.dart';

abstract final class CarRoutes {
  static const results = '/car/results';
  static const placePicker = '/car/place-picker';
  static const details = '/car/details';
}

List<RouteBase> carRoutes() => [
      GoRoute(
        path: CarRoutes.results,
        builder: (context, state) => const CarTierResultsScreen(),
      ),
      GoRoute(
        path: CarRoutes.details,
        builder: (context, state) => const CarTripDetailsScreen(),
      ),
      GoRoute(
        path: CarRoutes.placePicker,
        builder: (context, state) {
          final args = state.extra;
          if (args is! CarPlacePickerArgs) {
            return const CarPlacePickerScreen(
              args: CarPlacePickerArgs(title: ''),
            );
          }
          return CarPlacePickerScreen(args: args);
        },
      ),
    ];
