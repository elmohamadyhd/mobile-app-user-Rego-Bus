import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/core/config/app_config.dart';
import 'package:rego/core/places/places_client.dart';

final placesClientProvider = Provider<PlacesClient>((ref) {
  return PlacesClient(apiKey: AppConfig.googleMapsApiKey);
});
