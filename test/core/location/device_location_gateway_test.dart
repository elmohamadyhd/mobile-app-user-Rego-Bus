import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safaria/core/location/device_location_gateway.dart';
import 'package:safaria/core/places/place_prediction.dart';
import 'package:safaria/core/places/places_client.dart';
import 'package:safaria/shared/models/map_place.dart';

class _FakePlacesClient extends PlacesClient {
  _FakePlacesClient() : super(apiKey: 'test');

  int reverseCalls = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<List<PlacePrediction>> autocomplete({
    required String input,
    required String languageCode,
    required String sessionToken,
  }) async =>
      const [];

  @override
  Future<MapPlace> reverseGeocode({
    required double latitude,
    required double longitude,
    required String languageCode,
  }) async {
    reverseCalls++;
    return MapPlace(
      latitude: latitude,
      longitude: longitude,
      label: 'Current spot',
    );
  }
}

Position _position() => Position(
      latitude: 30.1,
      longitude: 31.2,
      timestamp: DateTime(2026),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  test('does not request permission when requestIfNeeded is false', () async {
    var requestCalls = 0;
    final places = _FakePlacesClient();
    final gateway = DeviceLocationGateway(
      checkPermission: () async => LocationPermission.denied,
      requestPermission: () async {
        requestCalls++;
        return LocationPermission.whileInUse;
      },
      getCurrentPosition: () async => _position(),
    );

    final place = await gateway.resolveCurrentPlace(
      places: places,
      languageCode: 'en',
      requestIfNeeded: false,
    );

    expect(place, isNull);
    expect(requestCalls, 0);
    expect(places.reverseCalls, 0);
  });

  test('requests permission only when entering with requestIfNeeded true',
      () async {
    var requestCalls = 0;
    final places = _FakePlacesClient();
    final gateway = DeviceLocationGateway(
      checkPermission: () async => LocationPermission.denied,
      requestPermission: () async {
        requestCalls++;
        return LocationPermission.whileInUse;
      },
      getCurrentPosition: () async => _position(),
    );

    final place = await gateway.resolveCurrentPlace(
      places: places,
      languageCode: 'en',
      requestIfNeeded: true,
    );

    expect(requestCalls, 1);
    expect(place?.latitude, 30.1);
    expect(place?.longitude, 31.2);
    expect(place?.label, 'Current spot');
  });

  test('returns current place when permission already granted without request',
      () async {
    var requestCalls = 0;
    final places = _FakePlacesClient();
    final gateway = DeviceLocationGateway(
      checkPermission: () async => LocationPermission.whileInUse,
      requestPermission: () async {
        requestCalls++;
        return LocationPermission.whileInUse;
      },
      getCurrentPosition: () async => _position(),
    );

    final place = await gateway.resolveCurrentPlace(
      places: places,
      languageCode: 'ar',
      requestIfNeeded: false,
    );

    expect(requestCalls, 0);
    expect(place?.label, 'Current spot');
    expect(places.reverseCalls, 1);
  });
}
