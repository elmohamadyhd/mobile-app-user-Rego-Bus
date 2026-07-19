import 'package:rego/features/bus/domain/entities/bus_stop.dart';

/// Max intermediate waypoints per Google Maps URLs spec.
const int kGoogleMapsMaxWaypoints = 9;

/// Result of building a Google Maps directions URL, including truncation info.
final class GoogleMapsRouteResult {
  const GoogleMapsRouteResult({
    required this.uri,
    this.truncatedStopCount = 0,
  });

  final Uri uri;

  /// How many middle stops were omitted because of the waypoint cap.
  final int truncatedStopCount;
}

/// Builds a Google Maps directions URL through every [stops] entry in order.
GoogleMapsRouteResult buildGoogleMapsDirectionsUrl({
  required List<BusStop> stops,
}) {
  if (stops.isEmpty) {
    return GoogleMapsRouteResult(
      uri: Uri.parse('https://www.google.com/maps/dir/?api=1'),
    );
  }

  if (stops.length == 1) {
    final encoded = _encodeStop(stops.first);
    return GoogleMapsRouteResult(
      uri: Uri(
        scheme: 'https',
        host: 'www.google.com',
        path: '/maps/dir/',
        queryParameters: {
          'api': '1',
          'origin': encoded,
          'destination': encoded,
          'travelmode': 'driving',
        },
      ),
    );
  }

  final origin = stops.first;
  final destination = stops.last;
  final middle = stops.sublist(1, stops.length - 1);

  var truncatedStopCount = 0;
  var waypoints = middle;
  if (middle.length > kGoogleMapsMaxWaypoints) {
    truncatedStopCount = middle.length - kGoogleMapsMaxWaypoints;
    waypoints = middle.sublist(0, kGoogleMapsMaxWaypoints);
  }

  final params = <String, String>{
    'api': '1',
    'origin': _encodeStop(origin),
    'destination': _encodeStop(destination),
    'travelmode': 'driving',
  };
  if (waypoints.isNotEmpty) {
    params['waypoints'] = waypoints.map(_encodeStop).join('|');
  }

  return GoogleMapsRouteResult(
    uri: Uri(
      scheme: 'https',
      host: 'www.google.com',
      path: '/maps/dir/',
      queryParameters: params,
    ),
    truncatedStopCount: truncatedStopCount,
  );
}

/// Builds a Google Maps search URL that pins a single [stop] on the map.
Uri buildGoogleMapsSearchUrl(BusStop stop) {
  return Uri(
    scheme: 'https',
    host: 'www.google.com',
    path: '/maps/search/',
    queryParameters: {
      'api': '1',
      'query': _encodeStop(stop),
    },
  );
}

String _encodeStop(BusStop stop) {
  final lat = stop.latitude;
  final lng = stop.longitude;
  if (lat != null && lng != null) {
    return '$lat,$lng';
  }
  return '${stop.name}, ${stop.cityName}';
}
