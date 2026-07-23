import 'package:rego/features/car/domain/entities/car_place.dart';

/// Arguments for [CarPlacePickerScreen] via go_router `extra`.
final class CarPlacePickerArgs {
  const CarPlacePickerArgs({
    required this.title,
    this.initial,
    this.showUseMyLocation = false,
  });

  final String title;
  final CarPlace? initial;
  final bool showUseMyLocation;
}
