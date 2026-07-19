import 'package:flutter_test/flutter_test.dart';
import 'package:rego/core/utils/google_maps_url.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';

BusStop _stop({
  required String name,
  required String cityName,
  double? latitude,
  double? longitude,
}) {
  return BusStop(
    locationId: '1',
    name: name,
    cityId: 1,
    cityName: cityName,
    latitude: latitude,
    longitude: longitude,
  );
}

void main() {
  test('uses coordinates when both latitude and longitude are present', () {
    final result = buildGoogleMapsDirectionsUrl(
      stops: [
        _stop(
          name: 'Ramsis',
          cityName: 'Cairo',
          latitude: 30.063437,
          longitude: 31.252121,
        ),
        _stop(
          name: 'Moharam Bek',
          cityName: 'Alexandria',
          latitude: 31.178158,
          longitude: 29.915599,
        ),
      ],
    );

    final uri = result.uri;
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['origin'], '30.063437,31.252121');
    expect(uri.queryParameters['destination'], '31.178158,29.915599');
    expect(uri.queryParameters['travelmode'], 'driving');
    expect(uri.queryParameters.containsKey('waypoints'), isFalse);
    expect(result.truncatedStopCount, 0);
  });

  test('falls back to stop name and city when coordinates are missing', () {
    final result = buildGoogleMapsDirectionsUrl(
      stops: [
        _stop(name: 'Ramsis', cityName: 'Cairo'),
        _stop(name: 'Moharam Bek', cityName: 'Alexandria'),
      ],
    );

    expect(result.uri.queryParameters['origin'], 'Ramsis, Cairo');
    expect(result.uri.queryParameters['destination'], 'Moharam Bek, Alexandria');
  });

  test('includes pipe-separated waypoints for routes with 3+ stops', () {
    final result = buildGoogleMapsDirectionsUrl(
      stops: [
        _stop(name: 'Sekka Club', cityName: 'Cairo'),
        _stop(name: 'Ramsis', cityName: 'Cairo'),
        _stop(name: '6 October', cityName: 'Cairo'),
        _stop(name: 'Moharam Bek', cityName: 'Alexandria'),
      ],
    );

    expect(result.uri.queryParameters['origin'], 'Sekka Club, Cairo');
    expect(result.uri.queryParameters['destination'], 'Moharam Bek, Alexandria');
    expect(
      result.uri.queryParameters['waypoints'],
      'Ramsis, Cairo|6 October, Cairo',
    );
    expect(result.truncatedStopCount, 0);
  });

  test('truncates middle stops beyond the Google Maps waypoint cap', () {
    final stops = <BusStop>[
      _stop(name: 'Stop 0', cityName: 'A'),
      for (var i = 1; i <= 11; i++) _stop(name: 'Stop $i', cityName: 'A'),
      _stop(name: 'Stop 12', cityName: 'B'),
    ];

    final result = buildGoogleMapsDirectionsUrl(stops: stops);

    expect(result.uri.queryParameters['origin'], 'Stop 0, A');
    expect(result.uri.queryParameters['destination'], 'Stop 12, B');
    expect(result.uri.queryParameters['waypoints']!.split('|'), hasLength(9));
    expect(result.truncatedStopCount, 2);
  });
}
