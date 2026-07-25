import 'package:safaria/shared/models/map_place.dart';

final class MapPlacePickerArgs {
  const MapPlacePickerArgs({
    required this.title,
    this.initial,
    this.showUseMyLocation = false,
  });

  final String title;
  final MapPlace? initial;
  final bool showUseMyLocation;
}
