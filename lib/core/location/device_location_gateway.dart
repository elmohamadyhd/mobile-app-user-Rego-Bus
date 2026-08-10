import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:safaria/core/places/places_client.dart';
import 'package:safaria/shared/models/map_place.dart';

typedef CheckLocationPermission = Future<LocationPermission> Function();
typedef RequestLocationPermission = Future<LocationPermission> Function();
typedef GetCurrentPosition = Future<Position> Function();

/// Thin Geolocator wrapper so callers can resolve "my location" without
/// prompting unless they explicitly opt in via [requestIfNeeded].
final class DeviceLocationGateway {
  const DeviceLocationGateway({
    CheckLocationPermission? checkPermission,
    RequestLocationPermission? requestPermission,
    GetCurrentPosition? getCurrentPosition,
  })  : _checkPermission = checkPermission ?? Geolocator.checkPermission,
        _requestPermission = requestPermission ?? Geolocator.requestPermission,
        _getCurrentPosition =
            getCurrentPosition ?? Geolocator.getCurrentPosition;

  final CheckLocationPermission _checkPermission;
  final RequestLocationPermission _requestPermission;
  final GetCurrentPosition _getCurrentPosition;

  static bool isGranted(LocationPermission permission) =>
      permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;

  /// Returns the reverse-geocoded current place, or null.
  ///
  /// When [requestIfNeeded] is false, never shows the system permission dialog.
  /// When true, requests only if status is [LocationPermission.denied].
  Future<MapPlace?> resolveCurrentPlace({
    required PlacesClient places,
    required String languageCode,
    bool requestIfNeeded = false,
  }) async {
    if (!places.isConfigured) return null;

    var permission = await _checkPermission();
    if (!isGranted(permission) && requestIfNeeded) {
      if (permission == LocationPermission.denied) {
        permission = await _requestPermission();
      }
    }
    if (!isGranted(permission)) return null;

    try {
      final position = await _getCurrentPosition();
      try {
        return await places.reverseGeocode(
          latitude: position.latitude,
          longitude: position.longitude,
          languageCode: languageCode,
        );
      } catch (_) {
        return MapPlace(
          latitude: position.latitude,
          longitude: position.longitude,
          label: '',
        );
      }
    } catch (_) {
      return null;
    }
  }
}

final deviceLocationGatewayProvider = Provider<DeviceLocationGateway>((ref) {
  return const DeviceLocationGateway();
});
