/// A named point usable with Google Maps URL helpers — feature-agnostic so
/// `core/` does not depend on bus/car entities.
final class MapLocation {
  const MapLocation({
    required this.name,
    this.latitude,
    this.longitude,
    this.cityName = '',
  });

  final String name;
  final double? latitude;
  final double? longitude;
  final String cityName;
}
