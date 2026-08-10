import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/core/places/places_client.dart';

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

    test('placeDetails prefers displayName as known place name', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter({
        '/v1/places/abc': {
          'displayName': {'text': 'Cairo Festival City'},
          'formattedAddress': 'Ring Road, New Cairo, Egypt',
          'location': {'latitude': 30.03, 'longitude': 31.42},
          'addressComponents': [
            {
              'longText': 'Ring Road',
              'types': ['route'],
            },
            {
              'longText': 'New Cairo',
              'types': ['locality', 'political'],
            },
          ],
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

    test('placeDetails falls back to street and city', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter({
        '/v1/places/xyz': {
          'location': {'latitude': 30.04, 'longitude': 31.24},
          'addressComponents': [
            {
              'longText': 'Nile Corniche',
              'types': ['route'],
            },
            {
              'longText': 'Cairo',
              'types': ['locality', 'political'],
            },
          ],
        },
      });

      final client = PlacesClient(placesDio: dio, apiKey: 'test-key');
      final place = await client.placeDetails(
        placeId: 'xyz',
        languageCode: 'en',
        sessionToken: 'sess-1',
      );

      expect(place.label, 'Nile Corniche, Cairo');
    });

    test('reverseGeocode builds street and city from components', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter({
        'geocode/json': {
          'status': 'OK',
          'results': [
            {
              'formatted_address': 'Nile Corniche, Cairo, Egypt',
              'address_components': [
                {
                  'long_name': 'Nile Corniche',
                  'short_name': 'Nile Corniche',
                  'types': ['route'],
                },
                {
                  'long_name': 'Cairo',
                  'short_name': 'Cairo',
                  'types': ['locality', 'political'],
                },
                {
                  'long_name': 'Egypt',
                  'short_name': 'EG',
                  'types': ['country', 'political'],
                },
              ],
            },
          ],
        },
      });

      final client = PlacesClient(geocodeDio: dio, apiKey: 'test-key');
      final place = await client.reverseGeocode(
        latitude: 30.04,
        longitude: 31.24,
        languageCode: 'en',
      );

      expect(place.label, 'Nile Corniche, Cairo');
      expect(place.latitude, 30.04);
      expect(place.longitude, 31.24);
    });

    test('reverseGeocode empty label when components missing', () async {
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

      expect(place.label, '');
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
