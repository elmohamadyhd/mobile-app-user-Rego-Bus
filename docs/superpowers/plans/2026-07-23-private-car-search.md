# Private Car Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the Home Private tab to inline Google Places autocomplete, call `GET /private/search`, and show a tier-results screen — guests browse freely; login is prompted on Continue (and on search `401`).

**Architecture:** New `features/car/` slice (domain → data → presentation) plus a shared `core/places/` HTTP client for Google Places/Geocoding. `HomeSearchCard` becomes a thin tab shell: bus fields unchanged, Private tab renders `CarSearchForm`. Results live on `/car/results` via federated `car_routes.dart`.

**Tech Stack:** Flutter, Riverpod (`Notifier`, no codegen for car providers), go_router, Dio, `google_maps_flutter`, `geolocator`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-07-23-private-car-search-design.md`

---

## Notes for the implementing engineer

- Run `./tool/pub-get.ps1` on Windows (not bare `flutter pub get`) — see `tool/README.md`.
- After any task touching `.arb` files, run `flutter gen-l10n`.
- `CarApi` / `CarRepositoryImpl` follow the bus precedent: **no dedicated API tests**; coverage is `CarDtoMapper` unit tests + notifier/widget tests with `FakeCarRepository`.
- `PlacesClient` uses a **standalone `Dio`** instance (no bearer interceptor) against Google Maps HTTP APIs.
- This repo is **Android-only** today (no `ios/` folder) — skip iOS plist steps unless the folder is added later.
- Real TDD starts at Task 3 (mapper). Task 1–2 are config/scaffolding.
- Run `flutter analyze` after any task touching more than two files.

## File map

| File | Responsibility |
|------|----------------|
| `lib/core/config/app_config.dart` | `googleMapsApiKey` getter |
| `lib/core/places/places_client.dart` | Autocomplete, place details, reverse geocode |
| `lib/core/places/places_providers.dart` | `placesClientProvider` |
| `lib/features/car/domain/entities/car_place.dart` | lat/lng + label |
| `lib/features/car/domain/entities/car_search_params.dart` | search + stored dates |
| `lib/features/car/domain/entities/car_trip_quote.dart` | API quote + nested company/vehicle |
| `lib/features/car/domain/repositories/car_repository.dart` | `searchQuotes` interface |
| `lib/features/car/data/car_api.dart` | `GET /private/search` |
| `lib/features/car/data/car_dto_mapper.dart` | envelope → entities |
| `lib/features/car/data/car_repository_impl.dart` | Dio guard + mapper |
| `lib/features/car/presentation/providers/car_booking_providers.dart` | state + `searchQuotes` |
| `lib/features/car/presentation/car_routes.dart` | `/car/results` |
| `lib/features/car/presentation/car_search_form.dart` | Private tab form |
| `lib/features/car/presentation/car_tier_results_screen.dart` | quote list + Continue CTA |
| `lib/features/car/presentation/car_map_adjust_sheet.dart` | map pin fine-tune sheet |
| `lib/features/car/presentation/widgets/car_place_autocomplete_field.dart` | inline autocomplete |
| `lib/features/car/presentation/widgets/car_tier_card.dart` | one quote row |
| `lib/features/home/presentation/widgets/home_search_card.dart` | tab shell (bus + private) |
| `test/features/car/fake_car_repository.dart` | test double |
| `test/features/car/data/car_fixtures.dart` | JSON fixtures |
| `test/features/car/data/car_dto_mapper_test.dart` | mapper tests |
| `test/features/car/presentation/car_booking_notifier_test.dart` | notifier tests |
| `test/features/car/presentation/widgets/car_tier_card_test.dart` | widget test |
| `test/features/car/presentation/car_search_form_test.dart` | validation widget test |
| `test/core/places/places_client_test.dart` | mocked HTTP |

---

### Task 1: Dependencies & platform config

**Files:**
- Modify: `pubspec.yaml`
- Modify: `.env.example`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add packages to `pubspec.yaml`**

Under `dependencies:` (after `shimmer`):

```yaml
  google_maps_flutter: ^2.12.1
  geolocator: ^13.0.2
```

- [ ] **Step 2: Install dependencies**

Run: `./tool/pub-get.ps1`
Expected: packages resolve without error.

- [ ] **Step 3: Add API key placeholder to `.env.example`**

Append:

```
# Google Maps / Places (private transfer location pick)
GOOGLE_MAPS_API_KEY=
```

Add the real key to your local `.env` (never commit `.env`).

- [ ] **Step 4: Android Maps meta-data + location permission**

In `android/app/src/main/AndroidManifest.xml`, add before `<application>`:

```xml
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

Inside `<application>`, after the `flutterEmbedding` meta-data:

```xml
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="${GOOGLE_MAPS_API_KEY}"/>
```

In `android/app/build.gradle.kts` (or `build.gradle`), ensure manifest placeholders read from env — if not already wired, add inside `android { defaultConfig {`:

```kotlin
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] =
            System.getenv("GOOGLE_MAPS_API_KEY") ?: ""
```

For local dev, you may also set the placeholder from `local.properties` — match whatever pattern the project already uses for secrets. Minimum: hardcode placeholder read from `.env` via existing Gradle dotenv hook if present; otherwise document that the developer must set `GOOGLE_MAPS_API_KEY` in `local.properties` as `GOOGLE_MAPS_API_KEY=...`.

- [ ] **Step 5: Verify analyze still clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock .env.example android/app/src/main/AndroidManifest.xml
git commit -m "chore(car): add google_maps_flutter, geolocator, and Android Maps config"
```

---

### Task 2: `AppConfig.googleMapsApiKey`

**Files:**
- Modify: `lib/core/config/app_config.dart`

- [ ] **Step 1: Add getter**

```dart
  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  static bool get isGoogleMapsConfigured => googleMapsApiKey.isNotEmpty;
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/core/config/app_config.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/core/config/app_config.dart
git commit -m "chore(config): expose GOOGLE_MAPS_API_KEY via AppConfig"
```

---

### Task 3: Domain entities + repository interface

**Files:**
- Create: `lib/features/car/domain/entities/car_place.dart`
- Create: `lib/features/car/domain/entities/car_search_params.dart`
- Create: `lib/features/car/domain/entities/car_trip_quote.dart`
- Create: `lib/features/car/domain/repositories/car_repository.dart`

- [ ] **Step 1: `car_place.dart`**

```dart
final class CarPlace {
  const CarPlace({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final String label;

  bool sameCoordinates(CarPlace other) {
    const epsilon = 0.00001;
    return (latitude - other.latitude).abs() < epsilon &&
        (longitude - other.longitude).abs() < epsilon;
  }
}
```

- [ ] **Step 2: `car_search_params.dart`**

```dart
import 'package:rego/features/car/domain/entities/car_place.dart';

final class CarSearchParams {
  const CarSearchParams({
    required this.from,
    required this.to,
    required this.rounded,
    required this.departDate,
    this.returnDate,
  });

  final CarPlace from;
  final CarPlace to;
  final bool rounded;
  final DateTime departDate;
  final DateTime? returnDate;
}
```

- [ ] **Step 3: `car_trip_quote.dart`**

```dart
final class CarCompany {
  const CarCompany({
    required this.id,
    required this.name,
    required this.refundability,
    this.refundPolicy,
    this.logoUrl,
  });

  final int id;
  final String name;
  final bool refundability;
  final String? refundPolicy;
  final String? logoUrl;
}

final class CarVehicle {
  const CarVehicle({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.seatsNumber,
    this.model,
    this.year,
    this.bigBagsCount,
    this.smallBagsCount,
    this.gearType,
    this.featuredUrl,
  });

  final int id;
  final String name;
  final String categoryName;
  final int seatsNumber;
  final String? model;
  final int? year;
  final int? bigBagsCount;
  final int? smallBagsCount;
  final String? gearType;
  final String? featuredUrl;
}

final class CarNamedLocation {
  const CarNamedLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;
}

final class CarTripQuote {
  const CarTripQuote({
    required this.id,
    required this.rounded,
    required this.goPrice,
    required this.roundPrice,
    required this.currency,
    required this.company,
    required this.fromLocation,
    required this.toLocation,
    required this.vehicle,
  });

  final int id;
  final bool rounded;
  final double goPrice;
  final double roundPrice;
  final String currency;
  final CarCompany company;
  final CarNamedLocation fromLocation;
  final CarNamedLocation toLocation;
  final CarVehicle vehicle;

  double priceFor({required bool rounded}) =>
      rounded ? roundPrice : goPrice;
}
```

- [ ] **Step 4: `car_repository.dart`**

```dart
import 'package:rego/features/car/domain/entities/car_search_params.dart';
import 'package:rego/features/car/domain/entities/car_trip_quote.dart';

abstract interface class CarRepository {
  Future<List<CarTripQuote>> searchQuotes(CarSearchParams params);
}
```

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/car/domain/`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/car/domain/
git commit -m "feat(car): add domain entities and CarRepository interface"
```

---

### Task 4: `CarDtoMapper` (TDD)

**Files:**
- Create: `test/features/car/data/car_fixtures.dart`
- Create: `test/features/car/data/car_dto_mapper_test.dart`
- Create: `lib/features/car/data/car_dto_mapper.dart`

- [ ] **Step 1: Write fixtures**

`test/features/car/data/car_fixtures.dart`:

```dart
/// Trimmed from docs/wadeny-apis.md → Private → Search (200).
const privateSearchEnvelope = {
  'status': 200,
  'message': 'Trips',
  'errors': <String, dynamic>{},
  'data': [
    {
      'id': 1,
      'rounded': true,
      'go_price': 69.87,
      'round_price': 104.81,
      'currency': 'SAR',
      'status': true,
      'currency_id': 1,
      'base_currency_id': 1,
      'exchange_rate': '1.00000000',
      'company': {
        'id': 1,
        'name': 'Sky Travel',
        'refundability': true,
        'refund_policy': 'Sky Travel',
        'logo_url':
            'https://demo.safaria.travel/storage/15/6a1f0a7b628ff_images-(1).jpeg',
        'logo_mime_type': 'image/jpeg',
      },
      'from_location': {
        'id': 1,
        'name': 'Cairo',
        'latitude': '30.0441028',
        'longitude': '31.2408498',
      },
      'to_location': {
        'id': 2,
        'name': 'Alexandria',
        'latitude': '31.2452475',
        'longitude': '29.9892346',
      },
      'vehicle': {
        'id': 1,
        'name': 'Hundai',
        'category_id': 1,
        'category_name': 'Sedan',
        'seats_number': 5,
        'model': 'Matrix',
        'year': 2010,
        'big_bags_count': 4,
        'small_bags_count': 1,
        'gear_type': 'automatic',
        'featured_url':
            'https://demo.safaria.travel/storage/16/6a1f0aecdea34_large.jpg',
        'featured_mime_type': 'image/jpeg',
      },
    },
  ],
};

const privateSearchEmptyEnvelope = {
  'status': 200,
  'message': 'Trips',
  'errors': <String, dynamic>{},
  'data': <dynamic>[],
};
```

- [ ] **Step 2: Write failing mapper tests**

`test/features/car/data/car_dto_mapper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rego/features/car/data/car_dto_mapper.dart';

import 'car_fixtures.dart';

void main() {
  group('CarDtoMapper', () {
    test('maps search envelope to quote list', () {
      final quotes =
          CarDtoMapper.quotesFromEnvelope(privateSearchEnvelope);
      expect(quotes, hasLength(1));

      final q = quotes.first;
      expect(q.id, 1);
      expect(q.goPrice, 69.87);
      expect(q.roundPrice, 104.81);
      expect(q.currency, 'SAR');
      expect(q.company.name, 'Sky Travel');
      expect(q.company.refundability, isTrue);
      expect(q.vehicle.categoryName, 'Sedan');
      expect(q.vehicle.seatsNumber, 5);
      expect(q.fromLocation.latitude, closeTo(30.0441028, 0.0001));
    });

    test('maps empty data array to empty list', () {
      final quotes =
          CarDtoMapper.quotesFromEnvelope(privateSearchEmptyEnvelope);
      expect(quotes, isEmpty);
    });
  });
}
```

- [ ] **Step 3: Run tests — expect FAIL**

Run: `flutter test test/features/car/data/car_dto_mapper_test.dart`
Expected: FAIL — `CarDtoMapper` not found.

- [ ] **Step 4: Implement mapper**

`lib/features/car/data/car_dto_mapper.dart`:

```dart
import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/car/domain/entities/car_trip_quote.dart';

abstract final class CarDtoMapper {
  static void ensureSuccess(Map<String, dynamic> envelope) {
    final innerStatus = envelope['status'];
    if (innerStatus is num && innerStatus.toInt() != 200) {
      throw ApiException.fromEnvelope(envelope);
    }
  }

  static List<CarTripQuote> quotesFromEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    ensureSuccess(envelope);
    final data = envelope['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(quoteFromJson)
        .toList();
  }

  static CarTripQuote quoteFromJson(Map<String, dynamic> json) {
    final company = json['company'];
    final from = json['from_location'];
    final to = json['to_location'];
    final vehicle = json['vehicle'];

    return CarTripQuote(
      id: _int(json['id']) ?? 0,
      rounded: json['rounded'] == true,
      goPrice: _double(json['go_price']) ?? 0,
      roundPrice: _double(json['round_price']) ?? 0,
      currency: _string(json['currency']) ?? '',
      company: company is Map<String, dynamic>
          ? CarCompany(
              id: _int(company['id']) ?? 0,
              name: _string(company['name']) ?? '',
              refundability: company['refundability'] == true,
              refundPolicy: _string(company['refund_policy']),
              logoUrl: _string(company['logo_url']),
            )
          : const CarCompany(id: 0, name: '', refundability: false),
      fromLocation: _namedLocation(from),
      toLocation: _namedLocation(to),
      vehicle: vehicle is Map<String, dynamic>
          ? CarVehicle(
              id: _int(vehicle['id']) ?? 0,
              name: _string(vehicle['name']) ?? '',
              categoryName: _string(vehicle['category_name']) ?? '',
              seatsNumber: _int(vehicle['seats_number']) ?? 0,
              model: _string(vehicle['model']),
              year: _int(vehicle['year']),
              bigBagsCount: _int(vehicle['big_bags_count']),
              smallBagsCount: _int(vehicle['small_bags_count']),
              gearType: _string(vehicle['gear_type']),
              featuredUrl: _string(vehicle['featured_url']),
            )
          : const CarVehicle(
              id: 0,
              name: '',
              categoryName: '',
              seatsNumber: 0,
            ),
    );
  }

  static CarNamedLocation _namedLocation(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const CarNamedLocation(
        id: 0,
        name: '',
        latitude: 0,
        longitude: 0,
      );
    }
    return CarNamedLocation(
      id: _int(json['id']) ?? 0,
      name: _string(json['name']) ?? '',
      latitude: _double(json['latitude']) ?? 0,
      longitude: _double(json['longitude']) ?? 0,
    );
  }

  static String? _string(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _double(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
```

- [ ] **Step 5: Run tests — expect PASS**

Run: `flutter test test/features/car/data/car_dto_mapper_test.dart`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/car/data/car_dto_mapper.dart test/features/car/data/
git commit -m "feat(car): add CarDtoMapper with search envelope parsing"
```

---

### Task 5: `CarApi` + `CarRepositoryImpl`

**Files:**
- Create: `lib/features/car/data/car_api.dart`
- Create: `lib/features/car/data/car_repository_impl.dart`

- [ ] **Step 1: `car_api.dart`**

```dart
import 'package:dio/dio.dart';

class CarApi {
  CarApi(this._dio);

  final Dio _dio;

  Future<dynamic> searchQuotes({
    required double fromLatitude,
    required double fromLongitude,
    required double toLatitude,
    required double toLongitude,
    required bool rounded,
  }) async {
    final res = await _dio.get(
      '/private/search',
      queryParameters: {
        'from_latitude': fromLatitude,
        'from_longitude': fromLongitude,
        'to_latitude': toLatitude,
        'to_longitude': toLongitude,
        'rounded': rounded,
      },
    );
    return res.data;
  }
}
```

- [ ] **Step 2: `car_repository_impl.dart`**

```dart
import 'package:dio/dio.dart';

import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/car/data/car_api.dart';
import 'package:rego/features/car/data/car_dto_mapper.dart';
import 'package:rego/features/car/domain/entities/car_search_params.dart';
import 'package:rego/features/car/domain/entities/car_trip_quote.dart';
import 'package:rego/features/car/domain/repositories/car_repository.dart';

class CarRepositoryImpl implements CarRepository {
  CarRepositoryImpl(this._api);

  final CarApi _api;

  @override
  Future<List<CarTripQuote>> searchQuotes(CarSearchParams params) {
    return _guard(() async {
      final body = await _api.searchQuotes(
        fromLatitude: params.from.latitude,
        fromLongitude: params.from.longitude,
        toLatitude: params.to.latitude,
        toLongitude: params.to.longitude,
        rounded: params.rounded,
      );
      return CarDtoMapper.quotesFromEnvelope(body);
    });
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/features/car/data/`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/car/data/car_api.dart lib/features/car/data/car_repository_impl.dart
git commit -m "feat(car): add CarApi and CarRepositoryImpl for private search"
```

---

### Task 6: `PlacesClient` (TDD)

**Files:**
- Create: `lib/core/places/places_client.dart`
- Create: `lib/core/places/places_providers.dart`
- Create: `test/core/places/places_client_test.dart`

- [ ] **Step 1: Define prediction/result types and write failing tests**

`test/core/places/places_client_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rego/core/places/places_client.dart';

void main() {
  group('PlacesClient', () {
    test('autocomplete maps predictions', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter({
        'place/autocomplete/json': {
          'status': 'OK',
          'predictions': [
            {
              'place_id': 'abc',
              'description': 'Cairo Festival City, Cairo',
            },
          ],
        },
      });

      final client = PlacesClient(dio: dio, apiKey: 'test-key');
      final results = await client.autocomplete(
        input: 'Cairo Fest',
        languageCode: 'en',
        sessionToken: 'sess-1',
      );

      expect(results, hasLength(1));
      expect(results.first.placeId, 'abc');
      expect(results.first.description, contains('Cairo'));
    });

    test('placeDetails resolves lat/lng and label', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter({
        'place/details/json': {
          'status': 'OK',
          'result': {
            'formatted_address': 'Cairo Festival City',
            'geometry': {
              'location': {'lat': 30.03, 'lng': 31.42},
            },
          },
        },
      });

      final client = PlacesClient(dio: dio, apiKey: 'test-key');
      final place = await client.placeDetails(
        placeId: 'abc',
        languageCode: 'en',
        sessionToken: 'sess-1',
      );

      expect(place.label, 'Cairo Festival City');
      expect(place.latitude, 30.03);
      expect(place.longitude, 31.42);
    });
  });
}

/// Minimal adapter — implement `_FakeAdapter` to return canned JSON per path
/// fragment. Use `MockHttpClientAdapter` pattern from Dio docs or a simple
/// `BaseAdapter` subclass that matches `options.uri.path` contains key.
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
```

Add `import 'dart:convert';` and `import 'dart:typed_data';` at top of test file.

- [ ] **Step 2: Run test — expect FAIL**

Run: `flutter test test/core/places/places_client_test.dart`
Expected: FAIL — `PlacesClient` not found.

- [ ] **Step 3: Implement `places_client.dart`**

```dart
import 'package:dio/dio.dart';

import 'package:rego/features/car/domain/entities/car_place.dart';

final class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    required this.description,
  });

  final String placeId;
  final String description;
}

class PlacesClient {
  PlacesClient({
    required String apiKey,
    Dio? dio,
  })  : _apiKey = apiKey,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://maps.googleapis.com/maps/api',
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
              ),
            );

  final String _apiKey;
  final Dio _dio;

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<List<PlacePrediction>> autocomplete({
    required String input,
    required String languageCode,
    required String sessionToken,
  }) async {
    if (!isConfigured || input.trim().length < 2) return const [];

    final res = await _dio.get<Map<String, dynamic>>(
      '/place/autocomplete/json',
      queryParameters: {
        'input': input,
        'key': _apiKey,
        'language': languageCode,
        'sessiontoken': sessionToken,
      },
    );

    final data = res.data;
    if (data == null || data['status'] != 'OK') return const [];
    final predictions = data['predictions'];
    if (predictions is! List) return const [];

    return predictions
        .whereType<Map<String, dynamic>>()
        .map(
          (p) => PlacePrediction(
            placeId: p['place_id']?.toString() ?? '',
            description: p['description']?.toString() ?? '',
          ),
        )
        .where((p) => p.placeId.isNotEmpty && p.description.isNotEmpty)
        .take(5)
        .toList();
  }

  Future<CarPlace> placeDetails({
    required String placeId,
    required String languageCode,
    required String sessionToken,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/place/details/json',
      queryParameters: {
        'place_id': placeId,
        'key': _apiKey,
        'language': languageCode,
        'sessiontoken': sessionToken,
        'fields': 'formatted_address,geometry',
      },
    );

    final data = res.data;
    if (data == null || data['status'] != 'OK') {
      throw StateError('Place details failed');
    }
    final result = data['result'];
    if (result is! Map<String, dynamic>) {
      throw StateError('Place details missing result');
    }

    final geometry = result['geometry'];
    final location = geometry is Map<String, dynamic>
        ? geometry['location']
        : null;
    final lat = location is Map ? location['lat'] : null;
    final lng = location is Map ? location['lng'] : null;

    return CarPlace(
      latitude: (lat as num).toDouble(),
      longitude: (lng as num).toDouble(),
      label: result['formatted_address']?.toString() ?? '',
    );
  }

  Future<CarPlace> reverseGeocode({
    required double latitude,
    required double longitude,
    required String languageCode,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
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
        label: '$latitude, $longitude',
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
      label: '$latitude, $longitude',
    );
  }
}
```

- [ ] **Step 4: `places_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/core/config/app_config.dart';
import 'package:rego/core/places/places_client.dart';

final placesClientProvider = Provider<PlacesClient>((ref) {
  return PlacesClient(apiKey: AppConfig.googleMapsApiKey);
});
```

- [ ] **Step 5: Run tests — expect PASS**

Run: `flutter test test/core/places/places_client_test.dart`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/core/places/ test/core/places/
git commit -m "feat(places): add PlacesClient for autocomplete and geocoding"
```

---

### Task 7: `CarBookingNotifier` + `FakeCarRepository` (TDD)

**Files:**
- Create: `test/features/car/fake_car_repository.dart`
- Create: `test/features/car/data/car_dto_mapper_test.dart` (reuse quote from fixtures)
- Create: `lib/features/car/presentation/providers/car_booking_providers.dart`
- Create: `test/features/car/presentation/car_booking_notifier_test.dart`

- [ ] **Step 1: `fake_car_repository.dart`**

```dart
import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/car/domain/entities/car_search_params.dart';
import 'package:rego/features/car/domain/entities/car_trip_quote.dart';
import 'package:rego/features/car/domain/repositories/car_repository.dart';

class FakeCarRepository implements CarRepository {
  FakeCarRepository({this.quotesResult});

  List<CarTripQuote>? quotesResult;
  CarSearchParams? lastSearchParams;
  bool searchShouldThrow = false;
  ApiException? searchException;

  static final sampleQuote = CarTripQuote(
    id: 1,
    rounded: false,
    goPrice: 69.87,
    roundPrice: 104.81,
    currency: 'SAR',
    company: const CarCompany(
      id: 1,
      name: 'Sky Travel',
      refundability: true,
    ),
    fromLocation: const CarNamedLocation(
      id: 1,
      name: 'Cairo',
      latitude: 30.04,
      longitude: 31.24,
    ),
    toLocation: const CarNamedLocation(
      id: 2,
      name: 'Alexandria',
      latitude: 31.24,
      longitude: 29.98,
    ),
    vehicle: const CarVehicle(
      id: 1,
      name: 'Hundai',
      categoryName: 'Sedan',
      seatsNumber: 5,
    ),
  );

  @override
  Future<List<CarTripQuote>> searchQuotes(CarSearchParams params) {
    lastSearchParams = params;
    if (searchShouldThrow) {
      throw searchException ??
          const ApiException('Unauthorized', statusCode: 401);
    }
    return Future.value(quotesResult ?? [sampleQuote]);
  }
}
```

- [ ] **Step 2: Write failing notifier tests**

`test/features/car/presentation/car_booking_notifier_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/car/domain/entities/car_place.dart';
import 'package:rego/features/car/domain/entities/car_search_params.dart';
import 'package:rego/features/car/presentation/providers/car_booking_providers.dart';

import '../fake_car_repository.dart';

void main() {
  const cairo = CarPlace(
    latitude: 30.03,
    longitude: 31.26,
    label: 'Cairo',
  );
  const alex = CarPlace(
    latitude: 31.18,
    longitude: 29.89,
    label: 'Alexandria',
  );

  CarSearchParams params({bool rounded = false}) => CarSearchParams(
        from: cairo,
        to: alex,
        rounded: rounded,
        departDate: DateTime(2026, 12, 20),
      );

  ProviderContainer makeContainer(FakeCarRepository repo) {
    return ProviderContainer(
      overrides: [
        carRepositoryProvider.overrideWithValue(repo),
      ],
    );
  }

  test('searchQuotes stores params and populates quotes', () async {
    final repo = FakeCarRepository(quotesResult: [FakeCarRepository.sampleQuote]);
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(carBookingProvider.notifier);
    await notifier.searchQuotes(params());

    final state = container.read(carBookingProvider);
    expect(state.searchParams, isNotNull);
    expect(state.quotes, hasLength(1));
    expect(state.quotesError, isNull);
    expect(state.isLoadingQuotes, isFalse);
  });

  test('searchQuotes records 401 for guest gate handling', () async {
    final repo = FakeCarRepository()
      ..searchShouldThrow = true
      ..searchException = const ApiException('Unauthorized', statusCode: 401);
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(carBookingProvider.notifier);
    await notifier.searchQuotes(params());

    final state = container.read(carBookingProvider);
    expect(state.needsAuthRetry, isTrue);
    expect(state.quotes, isEmpty);
  });

  test('selectQuote stores selected trip id', () {
    final container = makeContainer(FakeCarRepository());
    addTearDown(container.dispose);

    final quote = FakeCarRepository.sampleQuote;
    container.read(carBookingProvider.notifier).selectQuote(quote);

    expect(
      container.read(carBookingProvider).selectedQuote?.id,
      quote.id,
    );
  });
}
```

- [ ] **Step 3: Run tests — expect FAIL**

Run: `flutter test test/features/car/presentation/car_booking_notifier_test.dart`
Expected: FAIL.

- [ ] **Step 4: Implement providers**

`lib/features/car/presentation/providers/car_booking_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rego/core/network/api_exception.dart';
import 'package:rego/core/network/dio_client.dart';
import 'package:rego/features/car/data/car_api.dart';
import 'package:rego/features/car/data/car_repository_impl.dart';
import 'package:rego/features/car/domain/entities/car_search_params.dart';
import 'package:rego/features/car/domain/entities/car_trip_quote.dart';
import 'package:rego/features/car/domain/repositories/car_repository.dart';

final carApiProvider =
    Provider<CarApi>((ref) => CarApi(ref.watch(dioProvider)));

final carRepositoryProvider = Provider<CarRepository>(
  (ref) => CarRepositoryImpl(ref.watch(carApiProvider)),
);

class CarBookingState {
  const CarBookingState({
    this.searchParams,
    this.quotes = const [],
    this.selectedQuote,
    this.isLoadingQuotes = false,
    this.quotesError,
    this.needsAuthRetry = false,
  });

  final CarSearchParams? searchParams;
  final List<CarTripQuote> quotes;
  final CarTripQuote? selectedQuote;
  final bool isLoadingQuotes;
  final String? quotesError;
  final bool needsAuthRetry;

  CarBookingState copyWith({
    CarSearchParams? searchParams,
    List<CarTripQuote>? quotes,
    CarTripQuote? selectedQuote,
    bool? isLoadingQuotes,
    String? quotesError,
    bool? needsAuthRetry,
    bool clearQuotesError = false,
    bool clearSelectedQuote = false,
  }) {
    return CarBookingState(
      searchParams: searchParams ?? this.searchParams,
      quotes: quotes ?? this.quotes,
      selectedQuote:
          clearSelectedQuote ? null : (selectedQuote ?? this.selectedQuote),
      isLoadingQuotes: isLoadingQuotes ?? this.isLoadingQuotes,
      quotesError: clearQuotesError ? null : (quotesError ?? this.quotesError),
      needsAuthRetry: needsAuthRetry ?? this.needsAuthRetry,
    );
  }
}

class CarBookingNotifier extends Notifier<CarBookingState> {
  CarRepository get _repo => ref.read(carRepositoryProvider);

  @override
  CarBookingState build() => const CarBookingState();

  Future<void> searchQuotes(CarSearchParams params) async {
    state = state.copyWith(
      searchParams: params,
      isLoadingQuotes: true,
      quotes: [],
      clearQuotesError: true,
      needsAuthRetry: false,
      clearSelectedQuote: true,
    );
    try {
      final quotes = await _repo.searchQuotes(params);
      state = state.copyWith(
        isLoadingQuotes: false,
        quotes: quotes,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoadingQuotes: false,
        quotesError: e.message,
        needsAuthRetry: e.statusCode == 401,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingQuotes: false,
        quotesError: e.toString(),
      );
    }
  }

  void selectQuote(CarTripQuote quote) {
    state = state.copyWith(selectedQuote: quote);
  }

  void clearAuthRetry() {
    state = state.copyWith(needsAuthRetry: false);
  }
}

final carBookingProvider =
    NotifierProvider<CarBookingNotifier, CarBookingState>(
  CarBookingNotifier.new,
);
```

- [ ] **Step 5: Run tests — expect PASS**

Run: `flutter test test/features/car/presentation/car_booking_notifier_test.dart`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/car/presentation/providers/ test/features/car/
git commit -m "feat(car): add CarBookingNotifier and FakeCarRepository"
```

---

### Task 8: Localization keys

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ar.arb`

- [ ] **Step 1: Add English keys to `app_en.arb`**

```json
  "carPickup": "Pickup",
  "@carPickup": { "description": "Label for private transfer pickup field." },
  "carDropoff": "Drop-off",
  "@carDropoff": { "description": "Label for private transfer drop-off field." },
  "carPlaceSearchHint": "Search for a place",
  "@carPlaceSearchHint": { "description": "Placeholder in private transfer place autocomplete." },
  "carAdjustOnMap": "Adjust on map",
  "@carAdjustOnMap": { "description": "Link to open map pin fine-tune sheet." },
  "carUseMyLocation": "Use my location",
  "@carUseMyLocation": { "description": "Fill pickup from device GPS." },
  "carRequestCar": "Request a car",
  "@carRequestCar": { "description": "Private transfer search button on home." },
  "carChooseVehicle": "Choose vehicle",
  "@carChooseVehicle": { "description": "Private transfer results screen title." },
  "carNoQuotes": "No vehicles available",
  "@carNoQuotes": { "description": "Empty state title on private search results." },
  "carNoQuotesBody": "Try different pickup or drop-off locations.",
  "@carNoQuotesBody": { "description": "Empty state body on private search results." },
  "carSeats": "{count, plural, =1{1 seat} other{{count} seats}}",
  "@carSeats": {
    "description": "Seat count on a private transfer tier card.",
    "placeholders": { "count": { "type": "int" } }
  },
  "carBags": "{big} large · {small} small",
  "@carBags": {
    "description": "Bag counts on a private transfer tier card.",
    "placeholders": {
      "big": { "type": "int" },
      "small": { "type": "int" }
    }
  },
  "carGearAutomatic": "Automatic",
  "carGearManual": "Manual",
  "carRefundable": "Refundable",
  "@carRefundable": { "description": "Badge when operator allows refunds." },
  "carContinue": "Continue",
  "@carContinue": { "description": "Primary CTA on private transfer results." },
  "carBookingComingSoon": "Booking coming soon",
  "@carBookingComingSoon": { "description": "Snackbar when signed-in user taps Continue before booking ships." },
  "carSearchSelectBothPlaces": "Select pickup and drop-off",
  "@carSearchSelectBothPlaces": { "description": "Validation when private search submitted without both places." },
  "carSearchSamePlace": "Pickup and drop-off must be different",
  "@carSearchSamePlace": { "description": "Validation when both places share coordinates." },
  "carPlacesSearchFailed": "Couldn't search places. Try again.",
  "@carPlacesSearchFailed": { "description": "Inline error under autocomplete when Places API fails." },
  "carPlacesNoResults": "No places found",
  "@carPlacesNoResults": { "description": "Autocomplete dropdown empty state." },
  "carConfirmLocation": "Confirm location",
  "@carConfirmLocation": { "description": "CTA on map adjust sheet." },
  "guestGateCarBody": "Sign in or create an account to continue your transfer.",
  "@guestGateCarBody": { "description": "Guest gate body copy on private transfer Continue." }
```

- [ ] **Step 2: Add Arabic translations to `app_ar.arb`**

Mirror every key above with Arabic copy, e.g.:

```json
  "carPickup": "نقطة الانطلاق",
  "carDropoff": "نقطة الوصول",
  "carPlaceSearchHint": "ابحث عن مكان",
  "carAdjustOnMap": "تعديل على الخريطة",
  "carUseMyLocation": "استخدم موقعي",
  "carRequestCar": "اطلب سيارة",
  "carChooseVehicle": "اختر المركبة",
  "carNoQuotes": "لا توجد مركبات متاحة",
  "carNoQuotesBody": "جرّب مواقع انطلاق أو وصول مختلفة.",
  "carSeats": "{count, plural, =1{مقعد واحد} other{{count} مقاعد}}",
  "carBags": "{big} كبيرة · {small} صغيرة",
  "carGearAutomatic": "أوتوماتيك",
  "carGearManual": "يدوي",
  "carRefundable": "قابل للاسترداد",
  "carContinue": "متابعة",
  "carBookingComingSoon": "الحجز قريباً",
  "carSearchSelectBothPlaces": "اختر نقطة الانطلاق والوصول",
  "carSearchSamePlace": "يجب أن تكون نقطة الانطلاق مختلفة عن الوصول",
  "carPlacesSearchFailed": "تعذّر البحث عن الأماكن. حاول مرة أخرى.",
  "carPlacesNoResults": "لم يتم العثور على أماكن",
  "carConfirmLocation": "تأكيد الموقع",
  "guestGateCarBody": "سجّل الدخول أو أنشئ حساباً لمتابعة رحلتك."
```

- [ ] **Step 3: Generate l10n**

Run: `flutter gen-l10n`
Expected: `lib/l10n/app_localizations.dart` updated (gitignored).

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "feat(car): add private transfer localization keys"
```

---

### Task 9: `CarTierCard` widget (TDD)

**Files:**
- Create: `lib/features/car/presentation/widgets/car_tier_card.dart`
- Create: `test/features/car/presentation/widgets/car_tier_card_test.dart`

- [ ] **Step 1: Write failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rego/features/car/presentation/widgets/car_tier_card.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../../fake_car_repository.dart';

void main() {
  testWidgets('shows company, price, and seats', (tester) async {
    final quote = FakeCarRepository.sampleQuote;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: CarTierCard(
            quote: quote,
            rounded: false,
            selected: false,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Sky Travel'), findsOneWidget);
    expect(find.textContaining('69.87'), findsOneWidget);
    expect(find.textContaining('5'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test — expect FAIL**

Run: `flutter test test/features/car/presentation/widgets/car_tier_card_test.dart`

- [ ] **Step 3: Implement `car_tier_card.dart`**

Build a `Material` + `InkWell` card matching bus `TripCard` elevation/radius tokens:
- Leading: `ClipRRect` vehicle image (network with error → car icon) or company logo
- Title row: company name + optional refundable chip
- Subtitle: `categoryName` · `model`
- Meta row: `carSeats(count)`, `carBags(big, small)`, localized gear
- Trailing: formatted price + currency using `intl` `NumberFormat`
- Selected state: `AppColors.primaryTint` border (`Border.all(color: AppColors.primary, width: 1.5)`)

Use `AppIcons`, `AppTypography`, `AppSpacing`, `AppRadius` — no raw `Icons.*`.

- [ ] **Step 4: Run test — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add lib/features/car/presentation/widgets/car_tier_card.dart test/features/car/presentation/widgets/
git commit -m "feat(car): add CarTierCard widget"
```

---

### Task 10: `CarTierResultsScreen`

**Files:**
- Create: `lib/features/car/presentation/car_tier_results_screen.dart`
- Create: `test/features/car/presentation/car_tier_results_screen_test.dart`

- [ ] **Step 1: Write failing widget tests**

Cover:
1. Loading → skeleton placeholders
2. Non-empty list → one `CarTierCard` per quote
3. Empty list → `carNoQuotes` text
4. Tap Continue as guest → guest gate sheet appears (pump and settle; find `guestGateTitle`)

Use `ProviderScope` overrides with `FakeCarRepository` and preset `carBookingProvider` state via notifier `searchQuotes` or direct state seeding.

- [ ] **Step 2: Implement screen**

`CarTierResultsScreen` (`ConsumerWidget`):

- `ref.listen(carBookingProvider, …)` — when `needsAuthRetry` flips true, call `showGuestGate(context, returnTo: CarRoutes.results)` then `clearAuthRetry()`; on return, `searchQuotes` with stored params.
- `Scaffold` with `BookingAppBar` pattern from bus (or a slim local app bar with back + title `carChooseVehicle`).
- Header subtitle from `searchParams` dates via `formatSearchDateCell`.
- Body: if `isLoadingQuotes` → 3 shimmer/skeleton cards; else if `quotesError != null` → error banner + retry; else if `quotes.isEmpty` → empty state; else `ListView` of `CarTierCard`.
- `RefreshIndicator` → re-call `searchQuotes`.
- Bottom `SafeArea` bar: `PrimaryButton` `carContinue`:
  - disabled when `selectedQuote == null`
  - onPressed: if guest (`guestModeProvider.value == true`) → `showGuestGate` with `guestGateCarBody` copy (extend guest gate sheet to accept optional body override, or add car-specific gate wrapper)
  - else → `SnackBar(carBookingComingSoon)`

- [ ] **Step 3: Run tests — expect PASS**

Run: `flutter test test/features/car/presentation/car_tier_results_screen_test.dart`

- [ ] **Step 4: Commit**

```bash
git add lib/features/car/presentation/car_tier_results_screen.dart test/features/car/presentation/car_tier_results_screen_test.dart
git commit -m "feat(car): add tier results screen with guest gate on Continue"
```

---

### Task 11: `CarPlaceAutocompleteField`

**Files:**
- Create: `lib/features/car/presentation/widgets/car_place_autocomplete_field.dart`

- [ ] **Step 1: Implement widget**

`CarPlaceAutocompleteField` (`ConsumerStatefulWidget`):

Props: `label`, `iconBg`, `iconColor`, `value` (`CarPlace?`), `onChanged(CarPlace?)`, optional `showUseMyLocation`.

State: `TextEditingController`, debounce timer (300 ms), `sessionToken` (UUID v4 via `uuid` package **or** `DateTime.now().microsecondsSinceEpoch.toString()` to avoid new dep), predictions list, `isSearching`, `errorText`.

Behavior:
- When `value` set externally, sync controller text to `value.label`.
- On text change → debounce → `ref.read(placesClientProvider).autocomplete(...)`.
- If `!AppConfig.isGoogleMapsConfigured` → show disabled field with hint only (no crash).
- Dropdown: `Material` elevation 4, max height 200, scrollable, max 5 items.
- On prediction tap → `placeDetails` → `onChanged(place)` → clear predictions → new session token.
- Inline error: `carPlacesSearchFailed` / `carPlacesNoResults`.
- Optional footer link `carAdjustOnMap` → callback `onAdjustOnMap` (wired in Task 13).
- Optional `carUseMyLocation` → `Geolocator.checkPermission` / `requestPermission` → `getCurrentPosition` → `reverseGeocode` → `onChanged`.

Match bus `_CityField` visual structure (circle icon, overline label, bordered container).

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/car/presentation/widgets/car_place_autocomplete_field.dart`

- [ ] **Step 3: Commit**

```bash
git add lib/features/car/presentation/widgets/car_place_autocomplete_field.dart
git commit -m "feat(car): add inline Places autocomplete field"
```

---

### Task 12: `CarMapAdjustSheet`

**Files:**
- Create: `lib/features/car/presentation/car_map_adjust_sheet.dart`

- [ ] **Step 1: Implement sheet**

```dart
Future<CarPlace?> showCarMapAdjustSheet(
  BuildContext context, {
  required String title,
  CarPlace? initial,
}) { ... }
```

- `DraggableScrollableSheet` initialChildSize `0.6`
- `GoogleMap` `initialCameraPosition` from `initial` or Cairo default `(30.0444, 31.2357)`
- `onCameraIdle` → debounced `reverseGeocode` for center lat/lng
- Fixed center pin overlay (`Icon` + `AppColors.primary`)
- Header shows resolved label
- `PrimaryButton` `carConfirmLocation` pops `CarPlace`
- If `!AppConfig.isGoogleMapsConfigured`, return `null` immediately (caller hides link)

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/car/presentation/car_map_adjust_sheet.dart`

- [ ] **Step 3: Commit**

```bash
git add lib/features/car/presentation/car_map_adjust_sheet.dart
git commit -m "feat(car): add map adjust bottom sheet for location fine-tune"
```

---

### Task 13: `CarSearchForm` + home integration

**Files:**
- Create: `lib/features/car/presentation/car_search_form.dart`
- Modify: `lib/features/home/presentation/widgets/home_search_card.dart`
- Modify: `lib/shared/widgets/transport_mode_tab_bar.dart`
- Create: `test/features/car/presentation/car_search_form_test.dart`

- [ ] **Step 1: Add `privateTabIndex` to tab bar**

`lib/shared/widgets/transport_mode_tab_bar.dart`:

```dart
  static const int busTabIndex = 0;
  static const int privateTabIndex = 1;
  static const int flightTabIndex = 2;
```

- [ ] **Step 2: Implement `CarSearchForm`**

`ConsumerStatefulWidget` with:
- Reuse `TripType` toggle from home (import from `home_search_card.dart` or extract to `shared/models/trip_type.dart` — prefer **extract** to `lib/shared/models/trip_type.dart` to avoid circular imports).
- Two `CarPlaceAutocompleteField`s in a bordered stack with swap button (mirror bus layout).
- Date row(s) — copy `_DateField` pattern from home or extract shared date field.
- `PrimaryButton` `carRequestCar` with loading state.
- `_onSearch()`:
  - validate both places → snackbar `carSearchSelectBothPlaces`
  - validate not same coords → `carSearchSamePlace`
  - round-trip date validation
  - `ref.read(carBookingProvider.notifier).searchQuotes(CarSearchParams(...))`
  - on success (no error / no needsAuthRetry) → `context.push(CarRoutes.results)`
  - on `needsAuthRetry` → still push results (screen handles gate) OR show gate first — **push results**, let results screen handle 401 listener

- [ ] **Step 3: Refactor `home_search_card.dart`**

- When `selectedTab == TransportModeTabBar.privateTabIndex` → render `CarSearchForm()` instead of bus city stack.
- Remove “coming soon” snackbar for private tab in `onChanged` and `_onSearch`.
- Keep bus tab logic unchanged.

- [ ] **Step 4: Write widget test**

`car_search_form_test.dart`:
- Pump form under `ProviderScope` with fake places client override (return empty predictions) and `FakeCarRepository`.
- Tap search without filling places → expect `carSearchSelectBothPlaces` snackbar.

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/car/presentation/car_search_form_test.dart`

- [ ] **Step 6: Commit**

```bash
git add lib/features/car/presentation/car_search_form.dart lib/features/home/presentation/widgets/home_search_card.dart lib/shared/widgets/transport_mode_tab_bar.dart test/features/car/presentation/car_search_form_test.dart
git commit -m "feat(car): wire CarSearchForm into Home Private tab"
```

---

### Task 14: Routing

**Files:**
- Create: `lib/features/car/presentation/car_routes.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: `car_routes.dart`**

```dart
import 'package:go_router/go_router.dart';

import 'package:rego/features/car/presentation/car_tier_results_screen.dart';

abstract final class CarRoutes {
  static const results = '/car/results';
}

List<RouteBase> carRoutes() => [
      GoRoute(
        path: CarRoutes.results,
        builder: (context, state) => const CarTierResultsScreen(),
      ),
    ];
```

- [ ] **Step 2: Register in `app_router.dart`**

Add import and spread after `...busRoutes()`:

```dart
import 'package:rego/features/car/presentation/car_routes.dart';
...
      ...busRoutes(),
      ...carRoutes(),
      ...walletRoutes(),
```

- [ ] **Step 3: Analyze + test navigation**

Run: `flutter analyze lib/core/router/app_router.dart lib/features/car/presentation/car_routes.dart`

- [ ] **Step 4: Commit**

```bash
git add lib/features/car/presentation/car_routes.dart lib/core/router/app_router.dart
git commit -m "feat(car): register /car/results route"
```

---

### Task 15: Guest gate car copy (small enhancement)

**Files:**
- Modify: `lib/features/auth/presentation/widgets/guest_gate_sheet.dart`

- [ ] **Step 1: Add optional `body` parameter to `showGuestGate`**

```dart
Future<void> showGuestGate(
  BuildContext context, {
  required String returnTo,
  String? body,
}) {
  return showModalBottomSheet<void>(
    ...
    builder: (context) => _GuestGateSheet(returnTo: returnTo, body: body),
  );
}
```

Default `body` to `l10n.guestGateBody` when null.

- [ ] **Step 2: Use in `CarTierResultsScreen`**

```dart
showGuestGate(
  context,
  returnTo: CarRoutes.results,
  body: l10n.guestGateCarBody,
);
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/auth/presentation/widgets/guest_gate_sheet.dart lib/features/car/presentation/car_tier_results_screen.dart
git commit -m "feat(car): guest gate copy for private transfer Continue"
```

---

### Task 16: Final verification

- [ ] **Step 1: Format**

Run: `dart format .`

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Full test suite**

Run: `flutter test`
Expected: all tests pass.

- [ ] **Step 4: Manual smoke test (Android device/emulator)**

1. Set `GOOGLE_MAPS_API_KEY` in `.env`.
2. `flutter run`.
3. Home → Private tab → type in pickup autocomplete → select place.
4. Repeat for drop-off → Request a car.
5. Results list renders (or empty state on bad coords).
6. Select tier → Continue as guest → guest gate appears.

- [ ] **Step 5: Commit any format fixes**

```bash
git add -A
git commit -m "chore(car): format and verify private search feature"
```

---

## Spec coverage self-review

| Spec requirement | Task |
|------------------|------|
| Inline autocomplete on home card | 11, 13 |
| Map pin fine-tune (secondary) | 12 |
| `GET /private/search` | 4, 5, 7 |
| Form + results only | 10, 13 (no order API) |
| Browse-then-login | 7, 10, 15 |
| `rounded` one-way / round-trip | 13 |
| Dates stored not sent to search | 13 (`CarSearchParams`) |
| Empty / error / loading states | 10 |
| `TransportModeTabBar.privateTabIndex` | 13 |
| `car_routes.dart` federated | 14 |
| l10n AR + EN | 8 |
| `GOOGLE_MAPS_API_KEY` config | 1, 2 |
| Android Maps setup | 1 |
| Mapper + notifier + widget tests | 4, 7, 9, 10, 13 |
| PlacesClient mocked test | 6 |
| Hide map link when no API key | 11, 12 |

No placeholder steps remain. Type names are consistent across tasks (`CarPlace`, `CarTripQuote`, `CarSearchParams`, `CarBookingState.needsAuthRetry`).

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-23-private-car-search.md`. Two execution options:

**1. Subagent-Driven (recommended)** — dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — implement tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
