import 'package:flutter/foundation.dart';

import 'package:rego/core/config/app_config.dart';

/// Tracks which Google APIs are usable on the current key.
///
/// v1 uses one env key; [mapRenderingAvailable] can flip false at runtime
/// when Maps SDK tiles fail to load (Places/Geocoding may still work).
abstract final class GoogleMapsCapabilities {
  static bool _sessionMapRenderingAvailable = true;

  static bool get placesAvailable => AppConfig.isGoogleMapsConfigured;

  static bool get mapRenderingAvailable =>
      placesAvailable && _sessionMapRenderingAvailable;

  static void markMapUnavailable() {
    _sessionMapRenderingAvailable = false;
  }

  @visibleForTesting
  static void setMapRenderingAvailableForTesting(bool value) {
    _sessionMapRenderingAvailable = value;
  }

  @visibleForTesting
  static void resetSessionForTesting() {
    _sessionMapRenderingAvailable = true;
  }
}
