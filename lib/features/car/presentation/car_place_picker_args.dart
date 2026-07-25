import 'package:safaria/features/car/domain/entities/car_place.dart';
import 'package:safaria/shared/widgets/map_place_picker_args.dart';

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

  MapPlacePickerArgs toMapPlacePickerArgs() => MapPlacePickerArgs(
        title: title,
        initial: initial,
        showUseMyLocation: showUseMyLocation,
      );
}
