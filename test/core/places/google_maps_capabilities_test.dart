import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rego/core/places/google_maps_capabilities.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'GOOGLE_MAPS_API_KEY=test-key\n');
  });

  tearDown(GoogleMapsCapabilities.resetSessionForTesting);

  test('mapRenderingAvailable defaults true when key configured', () {
    expect(GoogleMapsCapabilities.mapRenderingAvailable, isTrue);
  });

  test('markMapUnavailable disables map rendering for session', () {
    GoogleMapsCapabilities.markMapUnavailable();
    expect(GoogleMapsCapabilities.mapRenderingAvailable, isFalse);
    expect(GoogleMapsCapabilities.placesAvailable, isTrue);
  });
}
