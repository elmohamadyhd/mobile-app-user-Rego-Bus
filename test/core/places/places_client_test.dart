import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rego/core/places/places_client.dart';

void main() {
  group('PlacesClient', () {
    test('autocomplete maps suggestions from Places API (New)', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter({
        'places:autocomplete': {
          'suggestions': [
            {
              'placePrediction': {
                'place': 'places/abc',
                'placeId': 'abc',
                'text': {'text': 'Cairo Festival City, Cairo'},
              },
            },
          ],
        },
      });

      final client = PlacesClient(placesDio: dio, apiKey: 'test-key');
      final results = await client.autocomplete(
        input: 'Cairo Fest',
        languageCode: 'en',
        sessionToken: 'sess-1',
      );

      expect(results, hasLength(1));
      expect(results.first.placeId, 'abc');
      expect(results.first.description, contains('Cairo'));
    });

    test('placeDetails resolves lat/lng and label from Places API (New)',
        () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter({
        '/v1/places/abc': {
          'formattedAddress': 'Cairo Festival City',
          'location': {'latitude': 30.03, 'longitude': 31.42},
        },
      });

      final client = PlacesClient(placesDio: dio, apiKey: 'test-key');
      final place = await client.placeDetails(
        placeId: 'abc',
        languageCode: 'en',
        sessionToken: 'sess-1',
      );

      expect(place.label, 'Cairo Festival City');
      expect(place.latitude, 30.03);
      expect(place.longitude, 31.42);
    });

    test('reverseGeocode uses Geocoding API', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter({
        'geocode/json': {
          'status': 'OK',
          'results': [
            {'formatted_address': 'Cairo, Egypt'},
          ],
        },
      });

      final client = PlacesClient(geocodeDio: dio, apiKey: 'test-key');
      final place = await client.reverseGeocode(
        latitude: 30.04,
        longitude: 31.24,
        languageCode: 'en',
      );

      expect(place.label, 'Cairo, Egypt');
      expect(place.latitude, 30.04);
      expect(place.longitude, 31.24);
    });

    test('newSessionToken is URL-safe and at most 36 characters', () {
      final token = PlacesClient.newSessionToken();
      expect(token.length, lessThanOrEqualTo(36));
      expect(token, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    });
  });
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._responses);

  final Map<String, dynamic> _responses;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final entry = _responses.entries.firstWhere(
      (e) => path.contains(e.key),
      orElse: () => throw StateError('No fake for $path'),
    );
    return ResponseBody.fromString(
      jsonEncode(entry.value),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
