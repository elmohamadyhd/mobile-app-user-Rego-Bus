import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import 'package:rego/core/places/place_prediction.dart';
import 'package:rego/features/car/domain/entities/car_place.dart';

class PlacesClient {
  PlacesClient({
    required String apiKey,
    Dio? dio,
    Dio? placesDio,
    Dio? geocodeDio,
  })  : _apiKey = apiKey,
        _placesDio = placesDio ??
            dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://places.googleapis.com',
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
              ),
            ),
        _geocodeDio = geocodeDio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://maps.googleapis.com/maps/api',
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
              ),
            );

  final String _apiKey;
  final Dio _placesDio;
  final Dio _geocodeDio;

  bool get isConfigured => _apiKey.isNotEmpty;

  /// URL-safe session token for Places API (New) billing (max 36 chars).
  static String newSessionToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Map<String, String> get _apiKeyHeaders => {'X-Goog-Api-Key': _apiKey};

  Future<List<PlacePrediction>> autocomplete({
    required String input,
    required String languageCode,
    required String sessionToken,
  }) async {
    if (!isConfigured || input.trim().length < 2) return const [];

    final res = await _placesDio.post<Map<String, dynamic>>(
      '/v1/places:autocomplete',
      data: {
        'input': input,
        'languageCode': languageCode,
        'sessionToken': sessionToken,
      },
      options: Options(
        headers: {
          ..._apiKeyHeaders,
          'Content-Type': 'application/json',
          'X-Goog-FieldMask':
              'suggestions.placePrediction.placeId,suggestions.placePrediction.place,suggestions.placePrediction.text',
        },
      ),
    );

    final data = res.data;
    if (data == null) return const [];

    final suggestions = data['suggestions'];
    if (suggestions is! List) return const [];

    return suggestions
        .whereType<Map<String, dynamic>>()
        .map(_parsePlacePrediction)
        .whereType<PlacePrediction>()
        .take(5)
        .toList();
  }

  PlacePrediction? _parsePlacePrediction(Map<String, dynamic> suggestion) {
    final prediction = suggestion['placePrediction'];
    if (prediction is! Map<String, dynamic>) return null;

    var placeId = prediction['placeId']?.toString() ?? '';
    if (placeId.isEmpty) {
      final placeResource = prediction['place']?.toString() ?? '';
      if (placeResource.startsWith('places/')) {
        placeId = placeResource.substring('places/'.length);
      }
    }

    final text = prediction['text'];
    final description =
        text is Map<String, dynamic> ? text['text']?.toString() ?? '' : '';

    if (placeId.isEmpty || description.isEmpty) return null;
    return PlacePrediction(placeId: placeId, description: description);
  }

  Future<CarPlace> placeDetails({
    required String placeId,
    required String languageCode,
    required String sessionToken,
  }) async {
    final res = await _placesDio.get<Map<String, dynamic>>(
      '/v1/places/$placeId',
      queryParameters: {
        'sessionToken': sessionToken,
        'languageCode': languageCode,
      },
      options: Options(
        headers: {
          ..._apiKeyHeaders,
          'X-Goog-FieldMask': 'location,formattedAddress,displayName',
        },
      ),
    );

    final data = res.data;
    if (data == null) {
      throw StateError('Place details failed');
    }

    final location = data['location'];
    final lat = location is Map ? location['latitude'] : null;
    final lng = location is Map ? location['longitude'] : null;
    if (lat is! num || lng is! num) {
      throw StateError('Place details missing location');
    }

    var label = data['formattedAddress']?.toString() ?? '';
    if (label.isEmpty) {
      final displayName = data['displayName'];
      if (displayName is Map<String, dynamic>) {
        label = displayName['text']?.toString() ?? '';
      }
    }

    return CarPlace(
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      label: label,
    );
  }

  Future<CarPlace> reverseGeocode({
    required double latitude,
    required double longitude,
    required String languageCode,
  }) async {
    final res = await _geocodeDio.get<Map<String, dynamic>>(
      '/geocode/json',
      queryParameters: {
        'latlng': '$latitude,$longitude',
        'key': _apiKey,
        'language': languageCode,
      },
    );

    final data = res.data;
    if (data == null || data['status'] != 'OK') {
      return CarPlace(
        latitude: latitude,
        longitude: longitude,
        label: '',
      );
    }
    final results = data['results'];
    if (results is List && results.isNotEmpty) {
      final first = results.first;
      if (first is Map<String, dynamic>) {
        final label = first['formatted_address']?.toString();
        if (label != null && label.isNotEmpty) {
          return CarPlace(
            latitude: latitude,
            longitude: longitude,
            label: label,
          );
        }
      }
    }
    return CarPlace(
      latitude: latitude,
      longitude: longitude,
      label: '',
    );
  }
}
