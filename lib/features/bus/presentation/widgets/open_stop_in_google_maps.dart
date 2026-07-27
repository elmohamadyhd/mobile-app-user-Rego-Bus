import 'package:flutter/material.dart';

import 'package:safaria/core/utils/external_url_launcher.dart';
import 'package:safaria/core/utils/map_location.dart';
import 'package:safaria/features/bus/domain/entities/bus_stop.dart';
import 'package:safaria/shared/widgets/open_location_in_google_maps.dart';

/// Bus-facing adapter around [confirmAndOpenLocationInGoogleMaps].
Future<void> confirmAndOpenStopInGoogleMaps(
  BuildContext context, {
  required BusStop stop,
  ExternalUrlLauncher launchUrl = launchExternalUrl,
}) {
  return confirmAndOpenLocationInGoogleMaps(
    context,
    location: MapLocation(
      name: stop.name,
      latitude: stop.latitude,
      longitude: stop.longitude,
      cityName: stop.cityName,
    ),
    launchUrl: launchUrl,
  );
}
