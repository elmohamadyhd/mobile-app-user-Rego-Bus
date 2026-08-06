# Flight Search Screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the Home Flight tab to a real one-way flight search flow — airport picker, `POST /flights/search`, a results list, and an offer details screen — stopping before any booking/payment work.

**Architecture:** Extends the existing `lib/features/flight/{data,domain}` layers (already built and tested against the live API) with a `presentation/` layer that mirrors the bus/car features exactly: a Riverpod `Notifier` for search state, a bottom-sheet picker, a results screen, and a details screen, all wired into `home_search_card.dart` and `app_router.dart`.

**Tech Stack:** Flutter, Riverpod (`Notifier`/`NotifierProvider`), Freezed, go_router, `flutter_test` with hand-written fake repositories (no mocking framework).

**Spec:** `docs/superpowers/specs/2026-08-07-flight-search-screens-design.md`

---

## Before you start

Read these existing files first — every task below assumes you've seen them:

- `lib/features/flight/domain/entities/flight_offer.dart` — `FlightOffer`, `FlightJourney`, `FlightSegment`, `FlightPriceClass` (already built)
- `lib/features/flight/domain/entities/flight_airport_suggestion.dart` — `FlightAirportSuggestion` (already built)
- `lib/features/flight/domain/entities/flight_search_params.dart` — `FlightSearchParams`, `FlightPassengerCount`, `FlightCabinClass`, `FlightSortingCriteria`, `FlightTripType` (already built)
- `lib/features/flight/domain/repositories/flight_repository.dart` — `FlightRepository` interface (already built)
- `lib/features/flight/data/flight_repository_impl.dart` — `FlightRepositoryImpl` (already built)
- `lib/features/home/presentation/widgets/home_search_card.dart` — the tab you're wiring into
- `lib/features/car/presentation/car_search_form.dart` — the closest existing analog to `FlightSearchForm`
- `lib/features/bus/presentation/trip_results_screen.dart` — the closest existing analog to `FlightResultsScreen`

One correction to the spec made during planning: the spec said `FlightOfferDetailsScreen` needs "no route." Every other screen in this app navigates exclusively through go_router (`grep` for `MaterialPageRoute`/`Navigator.push` in `lib/` returns nothing) — so this plan registers it as a normal `GoRoute` with `extra`, matching `CarPlacePickerScreen`'s pattern, instead of introducing the only raw `Navigator.push` in the codebase.

---

### Task 1: Flight booking state + providers

**Files:**
- Create: `lib/features/flight/presentation/providers/flight_booking_providers.dart`
- Delete: `lib/features/flight/presentation/providers/flight_providers.dart`
- Create: `test/features/flight/fake_flight_repository.dart`
- Create: `test/features/flight/presentation/flight_booking_notifier_test.dart`
- Modify: `lib/features/flight/data/flight_repository_impl.dart:47,75-80`

- [ ] **Step 1: Write the fake repository test double**

```dart
// test/features/flight/fake_flight_repository.dart
import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/flight/domain/entities/flight_airport_suggestion.dart';
import 'package:safaria/features/flight/domain/entities/flight_confirmed_order.dart';
import 'package:safaria/features/flight/domain/entities/flight_iata_airport.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_pagination.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
import 'package:safaria/features/flight/domain/repositories/flight_repository.dart';

class FakeFlightRepository implements FlightRepository {
  FakeFlightRepository({
    this.airportSuggestionsResult,
    this.searchResult,
  });

  List<FlightAirportSuggestion>? airportSuggestionsResult;
  List<FlightOffer>? searchResult;
  FlightSearchParams? lastSearchParams;
  String? lastAirportTerm;
  bool searchShouldThrow = false;
  bool airportSearchShouldThrow = false;
  ApiException? searchException;
  ApiException? airportSearchException;

  static const sampleOrigin = FlightAirportSuggestion(
    iataCode: 'CAI',
    name: 'Cairo Intl Airport',
    city: 'Cairo',
    countryCode: 'EG',
    country: 'EGYPT',
    isDomestic: false,
    isAllAirport: false,
    ranking: 124,
  );

  static const sampleDestination = FlightAirportSuggestion(
    iataCode: 'RUH',
    name: 'King Khalid Intl Airport',
    city: 'Riyadh',
    countryCode: 'SA',
    country: 'SAUDI ARABIA',
    isDomestic: false,
    isAllAirport: false,
    ranking: 90,
  );

  static const sampleOffer = FlightOffer(
    offerId: 'offer-1',
    haveBundles: false,
    canBeHeld: true,
    refundability: 'NotRefundable',
    journeys: [
      FlightJourney(
        id: 'journey-1',
        origin: 'CAI',
        destination: 'RUH',
        numberOfStops: 0,
        segments: [
          FlightSegment(
            id: 'segment-1',
            origin: 'CAI',
            destination: 'RUH',
            departureDateTime: null, // set below with a real DateTime
            arrivalDateTime: null,
            flightTimeInMinutes: 165,
            operatingCarrierCode: 'XY',
            operatingFlightNumber: '264',
            marketingCarrierCode: 'XY',
            marketingFlightNumber: '264',
          ),
        ],
      ),
    ],
    totalAmount: 7601,
    taxesAmount: 3141.88,
    baseAmount: 4459.12,
    discountAmount: 0,
    beforeDiscountAmount: 7601,
    serviceChargeAmount: 0,
    currency: 'EGP',
    priceClasses: [],
  );

  @override
  Future<(List<FlightIataAirport>, FlightPagination)> searchIataAirports({
    required String search,
    int page = 1,
  }) {
    return Future.value((const <FlightIataAirport>[], FlightPagination.empty));
  }

  @override
  Future<List<FlightAirportSuggestion>> searchAirportSuggestions({
    required String term,
  }) {
    lastAirportTerm = term;
    if (airportSearchShouldThrow) {
      throw airportSearchException ??
          const ApiException('Something went wrong', statusCode: 500);
    }
    return Future.value(
      airportSuggestionsResult ?? [sampleOrigin, sampleDestination],
    );
  }

  @override
  Future<List<FlightOffer>> search(FlightSearchParams params) {
    lastSearchParams = params;
    if (searchShouldThrow) {
      throw searchException ??
          const ApiException('Something went wrong', statusCode: 500);
    }
    return Future.value(searchResult ?? [sampleOffer]);
  }

  @override
  Future<FlightConfirmedOrder> confirmOrder(String offerId) {
    throw UnimplementedError('Confirm order is out of scope for this slice');
  }
}
```

`sampleOffer`'s segment can't have `null` `departureDateTime`/`arrivalDateTime` — those fields are `required DateTime` on `FlightSegment`, not nullable. Fix it before running anything:

```dart
// Replace the segment's null date fields with real values:
          FlightSegment(
            id: 'segment-1',
            origin: 'CAI',
            destination: 'RUH',
            departureDateTime: DateTime(2026, 9, 15, 10, 50),
            arrivalDateTime: DateTime(2026, 9, 15, 13, 35),
            flightTimeInMinutes: 165,
            operatingCarrierCode: 'XY',
            operatingFlightNumber: '264',
            marketingCarrierCode: 'XY',
            marketingFlightNumber: '264',
          ),
```

- [ ] **Step 2: Write the failing notifier test**

```dart
// test/features/flight/presentation/flight_booking_notifier_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';

import '../fake_flight_repository.dart';

void main() {
  FlightSearchParams params() => FlightSearchParams(
        origin: 'CAI',
        destination: 'RUH',
        date: DateTime(2026, 9, 15),
        passengers: const [
          FlightPassengerCount(passengerTypeCode: 'ADT', count: 1),
        ],
        currency: 'EGP',
      );

  ProviderContainer makeContainer(FakeFlightRepository repo) {
    return ProviderContainer(
      overrides: [flightRepositoryProvider.overrideWithValue(repo)],
    );
  }

  test('search stores params and populates offers', () async {
    final repo = FakeFlightRepository(
      searchResult: [FakeFlightRepository.sampleOffer],
    );
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(flightBookingProvider.notifier);
    await notifier.search(params());

    final state = container.read(flightBookingProvider);
    expect(state.searchParams, isNotNull);
    expect(state.offers, hasLength(1));
    expect(state.status, FlightBookingStatus.idle);
    expect(state.error, isNull);
  });

  test('search clears previous offers and sets error status on failure',
      () async {
    final repo = FakeFlightRepository()..searchShouldThrow = true;
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(flightBookingProvider.notifier);
    await notifier.search(params());

    final state = container.read(flightBookingProvider);
    expect(state.status, FlightBookingStatus.error);
    expect(state.offers, isEmpty);
    expect(state.error, isNotNull);
  });

  test('search with empty results leaves offers empty without error',
      () async {
    final repo = FakeFlightRepository(searchResult: const []);
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(flightBookingProvider.notifier);
    await notifier.search(params());

    final state = container.read(flightBookingProvider);
    expect(state.status, FlightBookingStatus.idle);
    expect(state.offers, isEmpty);
  });

  test('setSearchLabels stores from/to labels', () {
    final container = makeContainer(FakeFlightRepository());
    addTearDown(container.dispose);

    container
        .read(flightBookingProvider.notifier)
        .setSearchLabels(from: 'CAI', to: 'RUH');

    final state = container.read(flightBookingProvider);
    expect(state.searchFromLabel, 'CAI');
    expect(state.searchToLabel, 'RUH');
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/features/flight/presentation/flight_booking_notifier_test.dart`
Expected: FAIL — `flight_booking_providers.dart` doesn't exist yet (import error).

- [ ] **Step 4: Delete the old bare providers file**

```bash
rm lib/features/flight/presentation/providers/flight_providers.dart
```

- [ ] **Step 5: Write `flight_booking_providers.dart`**

```dart
// lib/features/flight/presentation/providers/flight_booking_providers.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/network/dio_client.dart';
import 'package:safaria/features/flight/data/flight_api.dart';
import 'package:safaria/features/flight/data/flight_repository_impl.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
import 'package:safaria/features/flight/domain/repositories/flight_repository.dart';

part 'flight_booking_providers.freezed.dart';

enum FlightBookingStatus { idle, searching, error }

final flightApiProvider =
    Provider<FlightApi>((ref) => FlightApi(ref.watch(dioProvider)));

final flightRepositoryProvider = Provider<FlightRepository>(
  (ref) => FlightRepositoryImpl(ref.watch(flightApiProvider)),
);

@freezed
abstract class FlightBookingState with _$FlightBookingState {
  const factory FlightBookingState({
    FlightSearchParams? searchParams,
    @Default([]) List<FlightOffer> offers,
    @Default(FlightBookingStatus.idle) FlightBookingStatus status,
    String? error,
    String? searchFromLabel,
    String? searchToLabel,
  }) = _FlightBookingState;
}

class FlightBookingNotifier extends Notifier<FlightBookingState> {
  FlightRepository get _repo => ref.read(flightRepositoryProvider);

  @override
  FlightBookingState build() => const FlightBookingState();

  void setSearchLabels({required String from, required String to}) {
    state = state.copyWith(searchFromLabel: from, searchToLabel: to);
  }

  Future<void> search(FlightSearchParams params) async {
    state = state.copyWith(
      status: FlightBookingStatus.searching,
      searchParams: params,
      error: null,
      offers: [],
    );
    try {
      final offers = await _repo.search(params);
      state = state.copyWith(status: FlightBookingStatus.idle, offers: offers);
    } catch (e) {
      state = state.copyWith(status: FlightBookingStatus.error, error: e.toString());
    }
  }
}

final flightBookingProvider =
    NotifierProvider<FlightBookingNotifier, FlightBookingState>(
  FlightBookingNotifier.new,
);
```

- [ ] **Step 6: Replace the hand-rolled date formatter with the shared helper**

`flight_repository_impl.dart` has its own private `_yMd` — `core/utils/date_formatting.dart` already has `toIsoDate` doing the same thing. Replace it:

```dart
// lib/features/flight/data/flight_repository_impl.dart
// Add this import at the top:
import 'package:safaria/core/utils/date_formatting.dart';

// In search(), change:
          date: _yMd(params.date),
// to:
          date: toIsoDate(params.date),

// Delete the now-unused private method entirely:
  static String _yMd(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
```

- [ ] **Step 7: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: succeeds, generates `flight_booking_providers.freezed.dart`.

- [ ] **Step 8: Run the test to verify it passes**

Run: `flutter test test/features/flight/presentation/flight_booking_notifier_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 9: Commit**

```bash
git add lib/features/flight/presentation/providers/flight_booking_providers.dart \
        lib/features/flight/presentation/providers/flight_booking_providers.freezed.dart \
        lib/features/flight/data/flight_repository_impl.dart \
        test/features/flight/fake_flight_repository.dart \
        test/features/flight/presentation/flight_booking_notifier_test.dart
git rm lib/features/flight/presentation/providers/flight_providers.dart
git commit -m "Add flight booking state and notifier"
```

---

### Task 2: DTO mapper coverage

The mapper (`flight_dto_mapper.dart`) already exists and was hand-verified against the live API in a prior session, but has no automated tests. This task locks that behavior in.

**Files:**
- Create: `test/features/flight/data/flight_fixtures.dart`
- Create: `test/features/flight/data/flight_dto_mapper_test.dart`

- [ ] **Step 1: Write fixtures trimmed from the live API responses**

```dart
// test/features/flight/data/flight_fixtures.dart
/// Trimmed from a live GET /flights/iata?search=CAI response (200).
const iataAirportsEnvelope = {
  'status': 200,
  'message': 'Airports list',
  'errors': <String, dynamic>{},
  'data': [
    {
      'id': 30325,
      'name': 'Cairo Intl Airport',
      'city': 'Cairo',
      'country': 'EGYPT',
      'iata_code': 'CAI',
      'icao_code': 'HECA',
      'country_code': 'EG',
      'latitude': 30.04998,
      'longitude': 31.2486,
    },
    {
      'id': 30326,
      'name': 'Capital International Airport',
      'city': 'Cairo',
      'country': 'EGYPT',
      'iata_code': 'CCE',
      'icao_code': null,
      'country_code': 'EG',
      'latitude': null,
      'longitude': null,
    },
  ],
  'pagination': {
    'total': 21,
    'lastPage': 1,
    'perPage': 50,
    'currentPage': 1,
    'nextPageUrl': 'https://demo.safaria.travel/api/v1/flights/iata?page=2',
    'previousPageUrl': null,
  },
};

/// Trimmed from a live GET /flights/airports/search?term=دبي response (200).
const airportSuggestionsEnvelope = {
  'status': 200,
  'message': 'Airports fetched successfully',
  'errors': <String, dynamic>{},
  'data': [
    {
      'iata_code': 'DXB',
      'name': 'All Airport',
      'city': 'Dubai',
      'country_code': 'AE',
      'country': 'UNITED ARAB EMIRATES',
      'latitude': 25.26948,
      'longitude': 55.30883,
      'is_domestic': false,
      'is_all_airport': true,
      'ranking': 179,
    },
    {
      'iata_code': 'DXB',
      'name': 'Dubai Intl Airport',
      'city': 'Dubai',
      'country_code': 'AE',
      'country': 'UNITED ARAB EMIRATES',
      'latitude': 25.26948,
      'longitude': 55.30883,
      'is_domestic': false,
      'is_all_airport': false,
      'ranking': 124,
    },
  ],
};

const airportSuggestionsRequiredTermEnvelope = {
  'status': 400,
  'message': 'The term field is required.',
  'errors': {'term': 'The term field is required.'},
  'data': <String, dynamic>{},
};

/// Trimmed from a live POST /flights/search response (200, one-way, one offer).
const flightSearchEnvelope = {
  'status': 200,
  'message': 'Flight search results',
  'errors': <String, dynamic>{},
  'data': [
    {
      'offerId': 'offer-abc',
      'haveBundles': true,
      'canBeHeld': false,
      'refundability': 'NotRefundable',
      'journeys': [
        {
          'id': 'journey-abc',
          'origin': 'CAI',
          'destination': 'RUH',
          'numberOfStops': 0,
          'segment': [
            {
              'id': 'segment-abc',
              'origin': 'CAI',
              'destination': 'RUH',
              'departureDateTime': '2026-09-15T10:50:00+03:00',
              'arrivalDateTime': '2026-09-15T13:35:00+03:00',
              'departureTerminal': '3',
              'arrivalTerminal': '1',
              'flightTimeInMinutes': 165,
              'operatingCarrierCode': 'XY',
              'operatingCarrierName': 'Flight Operations Services',
              'operatingCarrierLogo': 'https://pics.avs.io/200/200/XY.png',
              'operatingFlightNumber': '264',
              'marketingCarrierCode': 'XY',
              'marketingFlightNumber': '264',
              'equipment': '320',
            },
          ],
        },
      ],
      'totalAmount': 7601,
      'taxesAmount': 3141.88,
      'baseAmount': 4459.12,
      'discountAmount': 0,
      'beforeDiscountAmount': 7601,
      'serviceChargeAmount': 0,
      'currency': 'EGP',
      'departureDate': '2026-09-15T10:50:00+03:00',
      'arrivalDate': '2026-09-15T13:35:00+03:00',
      'priceClasses': [
        {
          'classId': 'class-1',
          'priceClassName': 'Economy Basic',
          'fareType': 'PrivateFare',
          'rulesAndPenalties': [
            'Classification: CarryOn, Inclusion: Included, GroupCode: BG',
            'Change BeforeDeparture: EGP 3355',
          ],
        },
      ],
    },
  ],
};

const flightSearchEmptyEnvelope = {
  'status': 200,
  'message': 'Flight search results',
  'errors': <String, dynamic>{},
  'data': <Map<String, dynamic>>[],
};
```

- [ ] **Step 2: Write the mapper tests**

```dart
// test/features/flight/data/flight_dto_mapper_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/flight/data/flight_dto_mapper.dart';

import 'flight_fixtures.dart';

void main() {
  group('FlightDtoMapper', () {
    test('maps IATA envelope to airports and pagination', () {
      final (airports, pagination) =
          FlightDtoMapper.iataAirportsFromEnvelope(iataAirportsEnvelope);

      expect(airports, hasLength(2));
      expect(airports.first.iataCode, 'CAI');
      expect(airports.first.icaoCode, 'HECA');
      expect(airports.last.icaoCode, isNull);
      expect(airports.last.latitude, isNull);
      expect(pagination.total, 21);
      expect(pagination.hasNextPage, isTrue);
    });

    test('maps airport suggestions envelope', () {
      final suggestions = FlightDtoMapper.airportSuggestionsFromEnvelope(
        airportSuggestionsEnvelope,
      );

      expect(suggestions, hasLength(2));
      expect(suggestions.first.isAllAirport, isTrue);
      expect(suggestions.first.ranking, 179);
      expect(suggestions.last.isAllAirport, isFalse);
    });

    test('throws ApiException on airport suggestions validation error', () {
      expect(
        () => FlightDtoMapper.airportSuggestionsFromEnvelope(
          airportSuggestionsRequiredTermEnvelope,
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('maps search envelope to offers with journeys and segments', () {
      final offers = FlightDtoMapper.offersFromEnvelope(flightSearchEnvelope);

      expect(offers, hasLength(1));
      final offer = offers.first;
      expect(offer.offerId, 'offer-abc');
      expect(offer.haveBundles, isTrue);
      expect(offer.journeys, hasLength(1));

      final journey = offer.journeys.first;
      expect(journey.id, 'journey-abc');
      expect(journey.segments, hasLength(1));

      final segment = journey.segments.first;
      expect(segment.operatingCarrierName, 'Flight Operations Services');
      expect(
        segment.departureDateTime,
        DateTime.parse('2026-09-15T10:50:00+03:00'),
      );
      expect(offer.totalAmount, 7601);
      expect(offer.priceClasses.single.rulesAndPenalties, hasLength(2));
    });

    test('maps empty search data to empty offer list', () {
      final offers =
          FlightDtoMapper.offersFromEnvelope(flightSearchEmptyEnvelope);
      expect(offers, isEmpty);
    });

    test('search request body uses the curreny typo, not currency', () {
      final body = FlightDtoMapper.searchRequestBody(
        origin: 'CAI',
        destination: 'RUH',
        date: '2026-09-15',
        passengers: const [
          {'passengerTypeCode': 'ADT', 'count': 1},
        ],
        sortingCriteria: 'CheapestFirst',
        cabinClass: 'CABIN_CLASS_ECONOMY',
        directFlightsOnly: false,
        tripType: 'one_way',
        currency: 'EGP',
      );

      expect(body['curreny'], 'EGP');
      expect(body.containsKey('currency'), isFalse);
    });
  });
}
```

- [ ] **Step 3: Run the tests**

Run: `flutter test test/features/flight/data/flight_dto_mapper_test.dart`
Expected: PASS (7 tests) — this is characterization coverage for existing, already-verified code, not red/green TDD.

- [ ] **Step 4: Commit**

```bash
git add test/features/flight/data/flight_fixtures.dart \
        test/features/flight/data/flight_dto_mapper_test.dart
git commit -m "Add test coverage for FlightDtoMapper"
```

---

### Task 3: Airport field + passenger count field widgets

Two small presentational widgets, no dedicated tests (pure display, exercised by the search-form test in Task 6).

**Files:**
- Create: `lib/features/flight/presentation/widgets/flight_airport_field.dart`
- Create: `lib/features/flight/presentation/widgets/flight_passenger_count_field.dart`

- [ ] **Step 1: Write `flight_airport_field.dart`**

```dart
// lib/features/flight/presentation/widgets/flight_airport_field.dart
import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_airport_suggestion.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Collapsed origin/destination row on [FlightSearchForm]; tapping opens
/// [showFlightAirportPicker]. Mirrors the home screen's private `_CityField`.
class FlightAirportField extends StatelessWidget {
  const FlightAirportField({
    super.key,
    required this.label,
    required this.airport,
    required this.placeholder,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  final String label;
  final FlightAirportSuggestion? airport;
  final String placeholder;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = airport;
    final valueText = a == null ? placeholder : '${a.iataCode} · ${a.city}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.overline.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      valueText,
                      style: AppTypography.title.copyWith(
                        color: a == null
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                PhosphorIconsLight.caretDown,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Write `flight_passenger_count_field.dart`**

```dart
// lib/features/flight/presentation/widgets/flight_passenger_count_field.dart
import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Inline adult-count stepper (1–9) on [FlightSearchForm].
class FlightPassengerCountField extends StatelessWidget {
  const FlightPassengerCountField({
    super.key,
    required this.count,
    required this.onChanged,
  });

  final int count;
  final ValueChanged<int> onChanged;

  static const _min = 1;
  static const _max = 9;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final valueLabel =
        count == 1 ? l10n.homeOnePax : l10n.flightPassengersCount(count);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 8, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.bgBase,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              PhosphorIconsLight.usersThree,
              color: AppColors.textMuted,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.flightPassengers,
                  style: AppTypography.overline.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  valueLabel,
                  style: AppTypography.title.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(PhosphorIconsLight.minus, size: 18),
            color: AppColors.textMuted,
            onPressed:
                count > _min ? () => onChanged(count - 1) : null,
          ),
          Text(
            '$count',
            style: AppTypography.title.copyWith(fontWeight: FontWeight.w800),
          ),
          IconButton(
            icon: const Icon(PhosphorIconsLight.plus, size: 18),
            color: AppColors.primary,
            onPressed:
                count < _max ? () => onChanged(count + 1) : null,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }
}
```

This references `l10n.flightPassengers` and `l10n.flightPassengersCount(count)`, which don't exist yet — they're added in Task 9. `flutter analyze` will show an error on this file until then; that's expected and resolves once Task 9 lands.

- [ ] **Step 3: Commit**

```bash
git add lib/features/flight/presentation/widgets/flight_airport_field.dart \
        lib/features/flight/presentation/widgets/flight_passenger_count_field.dart
git commit -m "Add flight airport field and passenger count field widgets"
```

---

### Task 4: Airport picker bottom sheet

**Files:**
- Create: `lib/features/flight/presentation/widgets/flight_airport_picker_sheet.dart`
- Create: `test/features/flight/presentation/flight_airport_picker_sheet_test.dart`

- [ ] **Step 1: Write `flight_airport_picker_sheet.dart`**

```dart
// lib/features/flight/presentation/widgets/flight_airport_picker_sheet.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_airport_suggestion.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Bottom-sheet picker backed by a debounced `GET /flights/airports/search`.
/// Structurally like `showBusCityPicker`, but the list comes from a live
/// network call instead of a client-filtered cached list.
Future<FlightAirportSuggestion?> showFlightAirportPicker(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<FlightAirportSuggestion>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _FlightAirportPickerSheet(title: title),
    ),
  );
}

class _FlightAirportPickerSheet extends ConsumerStatefulWidget {
  const _FlightAirportPickerSheet({required this.title});

  final String title;

  @override
  ConsumerState<_FlightAirportPickerSheet> createState() =>
      _FlightAirportPickerSheetState();
}

class _FlightAirportPickerSheetState
    extends ConsumerState<_FlightAirportPickerSheet> {
  static const _minChars = 2;
  static const _debounceDuration = Duration(milliseconds: 300);

  final _query = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<FlightAirportSuggestion>? _results;
  bool _loading = false;
  Object? _error;
  String? _lastTerm;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final term = value.trim();
    if (term.length < _minChars) {
      setState(() {
        _results = null;
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(_debounceDuration, () => _search(term));
  }

  Future<void> _search(String term) async {
    _lastTerm = term;
    try {
      final results = await ref
          .read(flightRepositoryProvider)
          .searchAirportSuggestions(term: term);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _retry() {
    final term = _lastTerm;
    if (term != null) _search(term);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style:
                          AppTypography.title.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(PhosphorIconsLight.x),
                    color: AppColors.textMuted,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    const Icon(
                      PhosphorIconsLight.magnifyingGlass,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: TextField(
                        controller: _query,
                        focusNode: _focusNode,
                        onChanged: _onQueryChanged,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          hintText: l10n.flightAirportSearchHint,
                          hintStyle: AppTypography.body.copyWith(
                            color: AppColors.textMuted,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: AppColors.hairline, height: 1),
            Flexible(child: _body(l10n)),
          ],
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l10n) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.tripResultsError,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: _retry, child: Text(l10n.tripResultsRetry)),
          ],
        ),
      );
    }
    final results = _results;
    if (results == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          l10n.flightAirportTypeToSearch,
          style: AppTypography.body.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          l10n.flightAirportSearchEmpty,
          style: AppTypography.body.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: results.length,
      itemBuilder: (context, index) {
        final airport = results[index];
        final subtitle = airport.isAllAirport
            ? l10n.flightAllAirportsIn(airport.city)
            : '${airport.city}, ${airport.country}';
        return ListTile(
          title: Text(airport.name, style: AppTypography.title),
          subtitle: Text(
            subtitle,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          trailing: Text(
            airport.iataCode,
            style: AppTypography.title.copyWith(fontWeight: FontWeight.w800),
          ),
          onTap: () => Navigator.of(context).pop(airport),
        );
      },
    );
  }
}
```

This references `l10n.flightAirportSearchHint`, `l10n.flightAirportTypeToSearch`, `l10n.flightAirportSearchEmpty`, and `l10n.flightAllAirportsIn` — added in Task 9.

- [ ] **Step 2: Write the picker test**

```dart
// test/features/flight/presentation/flight_airport_picker_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/flight/domain/entities/flight_airport_suggestion.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_airport_picker_sheet.dart';
import 'package:safaria/l10n/app_localizations.dart';

import '../fake_flight_repository.dart';

void main() {
  Future<void> pumpPickerHost(
    WidgetTester tester,
    FakeFlightRepository repo, {
    void Function(FlightAirportSuggestion?)? onPicked,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [flightRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  final picked =
                      await showFlightAirportPicker(context, title: 'From');
                  onPicked?.call(picked);
                },
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
  }

  testWidgets('does not search below the 2-character minimum', (tester) async {
    final repo = FakeFlightRepository();
    await pumpPickerHost(tester, repo);

    await tester.enterText(find.byType(TextField), 'C');
    await tester.pump(const Duration(milliseconds: 350));

    expect(repo.lastAirportTerm, isNull);
  });

  testWidgets('searches after debounce once minimum length is reached',
      (tester) async {
    final repo = FakeFlightRepository();
    await pumpPickerHost(tester, repo);

    await tester.enterText(find.byType(TextField), 'Dub');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(repo.lastAirportTerm, 'Dub');
    expect(find.text('Cairo Intl Airport'), findsOneWidget);
    expect(find.text('CAI'), findsOneWidget);
  });

  testWidgets('shows empty state when no airports match', (tester) async {
    final repo = FakeFlightRepository(airportSuggestionsResult: const []);
    await pumpPickerHost(tester, repo);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('No airports found'), findsOneWidget);
  });

  testWidgets('shows retry on error and retries the same term', (tester) async {
    final repo = FakeFlightRepository()
      ..airportSearchShouldThrow = true
      ..airportSearchException = const ApiException('Failed', statusCode: 500);
    await pumpPickerHost(tester, repo);

    await tester.enterText(find.byType(TextField), 'Dub');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);

    repo.airportSearchShouldThrow = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Cairo Intl Airport'), findsOneWidget);
  });

  testWidgets('returns tapped airport', (tester) async {
    FlightAirportSuggestion? picked;
    final repo = FakeFlightRepository();
    await pumpPickerHost(tester, repo, onPicked: (v) => picked = v);

    await tester.enterText(find.byType(TextField), 'Dub');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cairo Intl Airport'));
    await tester.pumpAndSettle();

    expect(picked?.iataCode, 'CAI');
  });
}
```

This test asserts on the literal English strings "No airports found" / "Retry" produced by `l10n.flightAirportSearchEmpty` / `l10n.tripResultsRetry` — those come from Task 9 and the existing `tripResultsRetry` key respectively.

- [ ] **Step 3: Run the tests**

Run: `flutter test test/features/flight/presentation/flight_airport_picker_sheet_test.dart`
Expected: FAIL at this point — `l10n.flightAirportSearchHint` etc. don't exist yet, so this won't even compile. That's expected; leave it red and continue — Task 9 makes it pass. Re-run after Task 9.

- [ ] **Step 4: Commit**

```bash
git add lib/features/flight/presentation/widgets/flight_airport_picker_sheet.dart \
        test/features/flight/presentation/flight_airport_picker_sheet_test.dart
git commit -m "Add flight airport picker bottom sheet"
```

---

### Task 5: Offer card + segment row widgets

**Files:**
- Create: `lib/features/flight/presentation/widgets/flight_offer_card.dart`
- Create: `lib/features/flight/presentation/widgets/flight_segment_row.dart`
- Create: `test/features/flight/presentation/flight_offer_card_test.dart`

- [ ] **Step 1: Write `flight_offer_card.dart`**

```dart
// lib/features/flight/presentation/widgets/flight_offer_card.dart
import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Summary card for one [FlightOffer] on the results list. Only the first
/// journey is shown — one-way search always returns exactly one.
class FlightOfferCard extends StatelessWidget {
  const FlightOfferCard({super.key, required this.offer, required this.onTap});

  final FlightOffer offer;
  final VoidCallback onTap;

  // Hand-rolled like `TripCard._formatTime` — always 24-hour, independent of
  // locale/intl data initialization.
  static String _time(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _duration(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final journey = offer.journeys.first;
    final firstSegment = journey.segments.first;
    final lastSegment = journey.segments.last;
    final totalMinutes =
        journey.segments.fold<int>(0, (sum, s) => sum + s.flightTimeInMinutes);
    final stopsLabel = journey.numberOfStops == 0
        ? l10n.flightDirect
        : journey.numberOfStops == 1
            ? l10n.flightOneStop
            : l10n.flightStopsCount(journey.numberOfStops);

    return Material(
      color: AppColors.bgElevated,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      elevation: 2,
      shadowColor: AppColors.primary.withValues(alpha: 0.12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (firstSegment.operatingCarrierLogo != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.network(
                        firstSegment.operatingCarrierLogo!,
                        width: 28,
                        height: 28,
                        errorBuilder: (_, __, ___) => const Icon(
                          PhosphorIconsLight.airplane,
                          color: AppColors.textMuted,
                        ),
                      ),
                    )
                  else
                    const Icon(PhosphorIconsLight.airplane, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    firstSegment.operatingCarrierName ??
                        firstSegment.operatingCarrierCode,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _time(firstSegment.departureDateTime),
                        style: AppTypography.title
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        journey.origin,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          _duration(totalMinutes),
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 2),
                        const Icon(PhosphorIconsLight.arrowRight,
                            size: 16, color: AppColors.textMuted),
                        const SizedBox(height: 2),
                        Text(
                          stopsLabel,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _time(lastSegment.arrivalDateTime),
                        style: AppTypography.title
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        journey.destination,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: AppColors.hairline, height: AppSpacing.lg),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  '${offer.totalAmount.toStringAsFixed(0)} ${offer.currency}',
                  style: AppTypography.title.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Write `flight_segment_row.dart`**

```dart
// lib/features/flight/presentation/widgets/flight_segment_row.dart
import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// One [FlightSegment] on [FlightOfferDetailsScreen] — full breakdown, not
/// the summarized view [FlightOfferCard] shows.
class FlightSegmentRow extends StatelessWidget {
  const FlightSegmentRow({super.key, required this.segment});

  final FlightSegment segment;

  // Hand-rolled like `TripCard._formatTime` — always 24-hour, independent of
  // locale/intl data initialization.
  static String _time(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsLight.airplane,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${segment.marketingCarrierCode} ${segment.marketingFlightNumber}',
                style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
              ),
              if (segment.equipment != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  segment.equipment!,
                  style:
                      AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_time(segment.departureDateTime)} · ${segment.origin}'
                '${segment.departureTerminal != null ? " T${segment.departureTerminal}" : ""}',
                style: AppTypography.body,
              ),
              const Icon(PhosphorIconsLight.arrowRight,
                  size: 16, color: AppColors.textMuted),
              Text(
                '${_time(segment.arrivalDateTime)} · ${segment.destination}'
                '${segment.arrivalTerminal != null ? " T${segment.arrivalTerminal}" : ""}',
                style: AppTypography.body,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Write the offer card test**

```dart
// test/features/flight/presentation/flight_offer_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_offer_card.dart';
import 'package:safaria/l10n/app_localizations.dart';

const _offer = FlightOffer(
  offerId: 'offer-1',
  haveBundles: false,
  canBeHeld: true,
  refundability: 'NotRefundable',
  journeys: [
    FlightJourney(
      id: 'journey-1',
      origin: 'CAI',
      destination: 'RUH',
      numberOfStops: 0,
      segments: [
        FlightSegment(
          id: 'segment-1',
          origin: 'CAI',
          destination: 'RUH',
          departureDateTime: DateTime(2026, 9, 15, 10, 50),
          arrivalDateTime: DateTime(2026, 9, 15, 13, 35),
          flightTimeInMinutes: 165,
          operatingCarrierCode: 'XY',
          operatingCarrierName: 'Flight Operations Services',
          operatingFlightNumber: '264',
          marketingCarrierCode: 'XY',
          marketingFlightNumber: '264',
        ),
      ],
    ),
  ],
  totalAmount: 7601,
  taxesAmount: 3141.88,
  baseAmount: 4459.12,
  discountAmount: 0,
  beforeDiscountAmount: 7601,
  serviceChargeAmount: 0,
  currency: 'EGP',
  priceClasses: [],
);

Future<void> _pump(WidgetTester tester, {bool rtl = false}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale(rtl ? 'ar' : 'en'),
      home: Scaffold(
        body: FlightOfferCard(offer: _offer, onTap: () {}),
      ),
    ),
  );
}

void main() {
  testWidgets('renders times, direct label, and price', (tester) async {
    await _pump(tester);

    expect(find.text('10:50'), findsOneWidget);
    expect(find.text('13:35'), findsOneWidget);
    expect(find.text('CAI'), findsOneWidget);
    expect(find.text('RUH'), findsOneWidget);
    expect(find.text('Direct'), findsOneWidget);
    expect(find.text('2h 45m'), findsOneWidget);
    expect(find.text('7601 EGP'), findsOneWidget);
  });

  testWidgets('calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: FlightOfferCard(offer: _offer, onTap: () => tapped = true),
        ),
      ),
    );

    await tester.tap(find.byType(FlightOfferCard));
    expect(tapped, isTrue);
  });

  testWidgets('renders under Arabic/RTL locale without crashing', (tester) async {
    await _pump(tester, rtl: true);
    expect(tester.takeException(), isNull);
    expect(find.text('CAI'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/flight/presentation/flight_offer_card_test.dart`
Expected: FAIL — `l10n.flightDirect` doesn't exist yet (Task 9). Leave red, continue.

- [ ] **Step 5: Commit**

```bash
git add lib/features/flight/presentation/widgets/flight_offer_card.dart \
        lib/features/flight/presentation/widgets/flight_segment_row.dart \
        test/features/flight/presentation/flight_offer_card_test.dart
git commit -m "Add flight offer card and segment row widgets"
```

---

### Task 6: Flight search form (Home tab widget)

**Files:**
- Create: `lib/features/flight/presentation/flight_search_form.dart`
- Create: `test/features/flight/presentation/flight_search_form_test.dart`

- [ ] **Step 1: Write `flight_search_form.dart`**

```dart
// lib/features/flight/presentation/flight_search_form.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/date_formatting.dart';
import 'package:safaria/features/flight/domain/entities/flight_airport_suggestion.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_airport_field.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_airport_picker_sheet.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_passenger_count_field.dart';
import 'package:safaria/features/home/presentation/widgets/home_flight_class_picker.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class FlightSearchForm extends ConsumerStatefulWidget {
  const FlightSearchForm({
    super.key,
    @visibleForTesting this.initialOrigin,
    @visibleForTesting this.initialDestination,
    @visibleForTesting this.initialTravelDate,
  });

  @visibleForTesting
  final FlightAirportSuggestion? initialOrigin;
  @visibleForTesting
  final FlightAirportSuggestion? initialDestination;
  @visibleForTesting
  final DateTime? initialTravelDate;

  @override
  ConsumerState<FlightSearchForm> createState() => _FlightSearchFormState();
}

class _FlightSearchFormState extends ConsumerState<FlightSearchForm> {
  FlightAirportSuggestion? _origin;
  FlightAirportSuggestion? _destination;
  late DateTime _travelDate;
  FlightClass _flightClass = kDefaultFlightClass;
  int _adults = 1;
  bool _searching = false;

  static const _maxBookingDays = 90;

  @override
  void initState() {
    super.initState();
    _origin = widget.initialOrigin;
    _destination = widget.initialDestination;
    _travelDate = dateOnly(widget.initialTravelDate ?? DateTime.now());
  }

  DateTime get _today => dateOnly(DateTime.now());

  DateTime get _effectiveTravelDate =>
      _travelDate.isBefore(_today) ? _today : _travelDate;

  void _swapFields() {
    setState(() {
      final tmp = _origin;
      _origin = _destination;
      _destination = tmp;
    });
  }

  Future<void> _pickOrigin() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showFlightAirportPicker(context, title: l10n.homeFrom);
    if (picked != null) setState(() => _origin = picked);
  }

  Future<void> _pickDestination() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showFlightAirportPicker(context, title: l10n.homeTo);
    if (picked != null) setState(() => _destination = picked);
  }

  Future<void> _pickDate() async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveTravelDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: _maxBookingDays)),
    );
    if (picked != null) setState(() => _travelDate = dateOnly(picked));
  }

  Future<void> _pickFlightClass() async {
    final l10n = AppLocalizations.of(context);
    final picked =
        await showFlightClassPicker(context, title: l10n.homeFlightClass);
    if (picked != null) setState(() => _flightClass = picked);
  }

  FlightCabinClass get _cabinClass => switch (_flightClass.id) {
        'business' => FlightCabinClass.business,
        'first' => FlightCabinClass.first,
        _ => FlightCabinClass.economy,
      };

  Future<void> _onSearch() async {
    final l10n = AppLocalizations.of(context);
    final origin = _origin;
    final destination = _destination;
    if (origin == null || destination == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.flightSearchSelectAirports),
            duration: const Duration(seconds: 2),
          ),
        );
      return;
    }
    if (origin.iataCode == destination.iataCode) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.flightSearchSamePlace),
            duration: const Duration(seconds: 2),
          ),
        );
      return;
    }

    final notifier = ref.read(flightBookingProvider.notifier);
    notifier.setSearchLabels(from: origin.iataCode, to: destination.iataCode);

    final params = FlightSearchParams(
      origin: origin.iataCode,
      destination: destination.iataCode,
      date: _effectiveTravelDate,
      passengers: [
        FlightPassengerCount(passengerTypeCode: 'ADT', count: _adults),
      ],
      cabinClass: _cabinClass,
      currency: 'EGP',
    );

    setState(() => _searching = true);
    try {
      await notifier.search(params);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
    if (mounted) unawaited(context.push(FlightRoutes.results));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.hairline),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                children: [
                  FlightAirportField(
                    label: l10n.homeFrom,
                    airport: _origin,
                    placeholder: l10n.homeCitySelectPlaceholder,
                    icon: PhosphorIconsLight.airplaneTakeoff,
                    iconBg: AppColors.primaryTint,
                    iconColor: AppColors.primary,
                    onTap: _pickOrigin,
                  ),
                  const Divider(
                    color: AppColors.hairline,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  FlightAirportField(
                    label: l10n.homeTo,
                    airport: _destination,
                    placeholder: l10n.homeCitySelectPlaceholder,
                    icon: PhosphorIconsLight.airplaneLanding,
                    iconBg: AppColors.secondaryTint,
                    iconColor: const Color(0xFFD98A2B),
                    onTap: _pickDestination,
                  ),
                ],
              ),
            ),
            PositionedDirectional(
              end: 14,
              top: 0,
              bottom: 0,
              child: Center(child: _SwapButton(onTap: _swapFields)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: _DateField(
            label: l10n.homeDepart,
            date: _effectiveTravelDate,
            onTap: _pickDate,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: _ClassField(
            label: l10n.homeFlightClass,
            flightClass: _flightClass,
            onTap: _pickFlightClass,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: FlightPassengerCountField(
            count: _adults,
            onChanged: (v) => setState(() => _adults = v),
          ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: l10n.flightSearch,
          loading: _searching,
          onPressed: (_origin != null && _destination != null) ? _onSearch : null,
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.date, required this.onTap});

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localeName = Localizations.localeOf(context).toString();
    final value = formatSearchDateCell(date, localeName);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.bgBase,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsLight.calendarBlank,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.overline.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      value,
                      style: AppTypography.title.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                PhosphorIconsLight.caretDown,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassField extends StatelessWidget {
  const _ClassField({
    required this.label,
    required this.flightClass,
    required this.onTap,
  });

  final String label;
  final FlightClass flightClass;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.bgBase,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsLight.airplane,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.overline.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      flightClass.label(l10n),
                      style: AppTypography.title.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                PhosphorIconsLight.caretDown,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.6),
            blurRadius: 16,
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              PhosphorIconsLight.arrowsDownUp,
              color: AppColors.onPrimary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
```

This imports `flight_routes.dart`, which doesn't exist until Task 8 — expected, resolves then.

- [ ] **Step 2: Write the form test**

```dart
// test/features/flight/presentation/flight_search_form_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/features/flight/domain/entities/flight_airport_suggestion.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/flight_search_form.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';

import '../fake_flight_repository.dart';

void main() {
  testWidgets('search CTA is disabled when airports are empty', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          flightRepositoryProvider.overrideWithValue(FakeFlightRepository()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(child: FlightSearchForm()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final opacityFinder = find.ancestor(
      of: find.text('Search flights'),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(opacityFinder).opacity, 0.6);
  });

  testWidgets('shows a snackbar when origin and destination are the same',
      (tester) async {
    const airport = FakeFlightRepository.sampleOrigin;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          flightRepositoryProvider.overrideWithValue(FakeFlightRepository()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: FlightSearchForm(
                initialOrigin: airport,
                initialDestination: airport,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search flights'));
    await tester.pump();

    expect(
      find.text('Origin and destination must be different'),
      findsOneWidget,
    );
  });

  testWidgets('search proceeds and pushes results when airports differ',
      (tester) async {
    final repo = FakeFlightRepository();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: SingleChildScrollView(
              child: FlightSearchForm(
                initialOrigin: FakeFlightRepository.sampleOrigin,
                initialDestination: FakeFlightRepository.sampleDestination,
              ),
            ),
          ),
        ),
        GoRoute(
          path: FlightRoutes.results,
          builder: (context, state) => const Scaffold(body: Text('Flight results')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [flightRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search flights'));
    await tester.pumpAndSettle();

    expect(repo.lastSearchParams, isNotNull);
    expect(repo.lastSearchParams!.origin, 'CAI');
    expect(repo.lastSearchParams!.destination, 'RUH');
    expect(find.text('Flight results'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run the test**

Run: `flutter test test/features/flight/presentation/flight_search_form_test.dart`
Expected: FAIL — `flight_routes.dart` doesn't exist yet, and `l10n.flightSearch` etc. are missing. Leave red, continue to Task 8/9.

- [ ] **Step 4: Commit**

```bash
git add lib/features/flight/presentation/flight_search_form.dart \
        test/features/flight/presentation/flight_search_form_test.dart
git commit -m "Add flight search form"
```

---

### Task 7: Results and offer details screens

**Files:**
- Create: `lib/features/flight/presentation/flight_results_screen.dart`
- Create: `lib/features/flight/presentation/flight_offer_details_screen.dart`

- [ ] **Step 1: Write `flight_results_screen.dart`**

```dart
// lib/features/flight/presentation/flight_results_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_offer_card.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class FlightResultsScreen extends ConsumerWidget {
  const FlightResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(flightBookingProvider);
    final title = '${state.searchFromLabel ?? ''} → ${state.searchToLabel ?? ''}';

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(title: title),
      body: _buildBody(context, ref, l10n, state),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    FlightBookingState state,
  ) {
    if (state.status == FlightBookingStatus.searching) {
      return const _LoadingSkeleton();
    }
    if (state.status == FlightBookingStatus.error) {
      return _ErrorView(
        message: l10n.tripResultsError,
        retryLabel: l10n.tripResultsRetry,
        onRetry: () {
          final params = state.searchParams;
          if (params != null) {
            ref.read(flightBookingProvider.notifier).search(params);
          }
        },
      );
    }
    if (state.offers.isEmpty) {
      return Center(
        child: Text(
          l10n.flightResultsNoOffers,
          style: AppTypography.body.copyWith(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: state.offers.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) {
        final offer = state.offers[i];
        return FlightOfferCard(
          key: ValueKey(offer.offerId),
          offer: offer,
          onTap: () =>
              context.push(FlightRoutes.offerDetails, extra: offer),
        );
      },
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.hairline,
      highlightColor: AppColors.bgElevated,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, __) => Container(
          height: 140,
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(PhosphorIconsLight.warningCircle,
              color: AppColors.error, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Write `flight_offer_details_screen.dart`**

```dart
// lib/features/flight/presentation/flight_offer_details_screen.dart
import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_segment_row.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

class FlightOfferDetailsScreen extends StatelessWidget {
  const FlightOfferDetailsScreen({super.key, required this.offer});

  final FlightOffer offer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final journey = offer.journeys.first;
    final rules = offer.priceClasses
        .expand((c) => c.rulesAndPenalties ?? const <String>[])
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(title: '${journey.origin} → ${journey.destination}'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                children: [
                  for (final segment in journey.segments)
                    FlightSegmentRow(segment: segment),
                ],
              ),
            ),
            if (rules.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.flightFareRules,
                style: AppTypography.title.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final rule in rules)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    '•  $rule',
                    style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.flightPriceTotal,
              style: AppTypography.title.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            _priceRow(l10n.flightPriceBase, offer.baseAmount, offer.currency),
            _priceRow(l10n.flightPriceTaxes, offer.taxesAmount, offer.currency),
            if (offer.discountAmount > 0)
              _priceRow(
                l10n.flightPriceDiscount,
                -offer.discountAmount,
                offer.currency,
              ),
            const Divider(color: AppColors.hairline),
            _priceRow(
              l10n.flightPriceTotal,
              offer.totalAmount,
              offer.currency,
              bold: true,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: PrimaryButton(
            label: l10n.flightSelectThisFlight,
            onPressed: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(l10n.flightBookingComingSoon),
                    duration: const Duration(seconds: 2),
                  ),
                );
            },
          ),
        ),
      ),
    );
  }

  Widget _priceRow(String label, double amount, String currency, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.body.copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} $currency',
            style: AppTypography.body.copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/flight/presentation/flight_results_screen.dart \
        lib/features/flight/presentation/flight_offer_details_screen.dart
git commit -m "Add flight results and offer details screens"
```

---

### Task 8: Routes

**Files:**
- Create: `lib/features/flight/presentation/flight_routes.dart`
- Modify: `lib/core/router/app_router.dart:20,144`

- [ ] **Step 1: Write `flight_routes.dart`**

```dart
// lib/features/flight/presentation/flight_routes.dart
import 'package:go_router/go_router.dart';

import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/presentation/flight_offer_details_screen.dart';
import 'package:safaria/features/flight/presentation/flight_results_screen.dart';

abstract final class FlightRoutes {
  static const results = '/flight/results';
  static const offerDetails = '/flight/offer-details';
}

List<RouteBase> flightRoutes() => [
      GoRoute(
        path: FlightRoutes.results,
        builder: (context, state) => const FlightResultsScreen(),
      ),
      GoRoute(
        path: FlightRoutes.offerDetails,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! FlightOffer) {
            return const FlightResultsScreen();
          }
          return FlightOfferDetailsScreen(offer: extra);
        },
      ),
    ];
```

- [ ] **Step 2: Register the routes in `app_router.dart`**

```dart
// lib/core/router/app_router.dart
// Add this import next to the car import:
import 'package:safaria/features/flight/presentation/flight_routes.dart';

// Add this line next to `...carRoutes(),`:
      ...flightRoutes(),
```

- [ ] **Step 3: Run analyze to confirm the route wiring compiles**

Run: `flutter analyze lib/features/flight lib/core/router/app_router.dart`
Expected: no issues (the `l10n.flightSearch` etc. errors from earlier tasks remain until Task 9 — check that this task's own files are clean).

- [ ] **Step 4: Commit**

```bash
git add lib/features/flight/presentation/flight_routes.dart \
        lib/core/router/app_router.dart
git commit -m "Register flight routes"
```

---

### Task 9: Localization

**Files:**
- Modify: `lib/l10n/app_en.arb:150` (after `homeOnePax`)
- Modify: `lib/l10n/app_ar.arb:90` (after `homeOnePax`)

- [ ] **Step 1: Add English keys**

Insert these new key/value pairs into `app_en.arb` immediately after the `"homeOnePax": "1 passenger",` line (keep `homeOnePax` itself unchanged):

```json
  "flightAirportSearchHint": "Search airport or city",
  "@flightAirportSearchHint": {
    "description": "Placeholder in the flight airport picker search field."
  },
  "flightAirportTypeToSearch": "Type at least 2 characters to search",
  "@flightAirportTypeToSearch": {
    "description": "Idle state in the flight airport picker before the minimum query length is reached."
  },
  "flightAirportSearchEmpty": "No airports found",
  "@flightAirportSearchEmpty": {
    "description": "Shown when the flight airport picker search has no matches."
  },
  "flightAllAirportsIn": "All airports in {city}",
  "@flightAllAirportsIn": {
    "description": "Subtitle for the \"all airports\" pseudo-entry the airports endpoint returns per city.",
    "placeholders": {
      "city": {
        "type": "String"
      }
    }
  },
  "flightPassengers": "Passengers",
  "@flightPassengers": {
    "description": "Label on the flight search form's passenger count field."
  },
  "flightPassengersCount": "{count} passengers",
  "@flightPassengersCount": {
    "description": "Passenger count value when more than one passenger is selected.",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "flightSearch": "Search flights",
  "@flightSearch": {
    "description": "Primary CTA on the flight search form."
  },
  "flightSearchSelectAirports": "Please select origin and destination airports",
  "@flightSearchSelectAirports": {
    "description": "Snackbar when flight search is tapped without both airports selected."
  },
  "flightSearchSamePlace": "Origin and destination must be different",
  "@flightSearchSamePlace": {
    "description": "Snackbar when the selected origin and destination airports are the same."
  },
  "flightResultsNoOffers": "No flights found",
  "@flightResultsNoOffers": {
    "description": "Empty state on the flight results screen."
  },
  "flightDirect": "Direct",
  "@flightDirect": {
    "description": "Stops label on a flight offer card with zero stops."
  },
  "flightOneStop": "1 stop",
  "@flightOneStop": {
    "description": "Stops label on a flight offer card with exactly one stop."
  },
  "flightStopsCount": "{count} stops",
  "@flightStopsCount": {
    "description": "Stops label on a flight offer card with two or more stops.",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "flightSelectThisFlight": "Select this flight",
  "@flightSelectThisFlight": {
    "description": "CTA on the flight offer details screen."
  },
  "flightBookingComingSoon": "Booking coming soon",
  "@flightBookingComingSoon": {
    "description": "Snackbar shown when \"Select this flight\" is tapped."
  },
  "flightFareRules": "Fare rules",
  "@flightFareRules": {
    "description": "Section heading for fare rule bullets on the offer details screen."
  },
  "flightPriceBase": "Base fare",
  "@flightPriceBase": {
    "description": "Price breakdown row label on the offer details screen."
  },
  "flightPriceTaxes": "Taxes & fees",
  "@flightPriceTaxes": {
    "description": "Price breakdown row label on the offer details screen."
  },
  "flightPriceDiscount": "Discount",
  "@flightPriceDiscount": {
    "description": "Price breakdown row label on the offer details screen."
  },
  "flightPriceTotal": "Total",
  "@flightPriceTotal": {
    "description": "Price breakdown row label and section heading on the offer details screen."
  },
```

- [ ] **Step 2: Add Arabic keys**

Insert these immediately after `"homeOnePax": "راكب واحد",` in `app_ar.arb` (flat, no `@meta` blocks — matches the rest of that file):

```json
  "flightAirportSearchHint": "ابحث عن مطار أو مدينة",
  "flightAirportTypeToSearch": "اكتب حرفين على الأقل للبحث",
  "flightAirportSearchEmpty": "لم يتم العثور على مطارات",
  "flightAllAirportsIn": "كل المطارات في {city}",
  "flightPassengers": "الركاب",
  "flightPassengersCount": "{count} ركاب",
  "flightSearch": "ابحث عن رحلات",
  "flightSearchSelectAirports": "يرجى اختيار مطار المغادرة والوصول",
  "flightSearchSamePlace": "يجب أن يختلف مطار المغادرة عن الوصول",
  "flightResultsNoOffers": "لم يتم العثور على رحلات",
  "flightDirect": "مباشرة",
  "flightOneStop": "توقف واحد",
  "flightStopsCount": "{count} توقفات",
  "flightSelectThisFlight": "اختر هذه الرحلة",
  "flightBookingComingSoon": "الحجز قريباً",
  "flightFareRules": "قواعد التعرفة",
  "flightPriceBase": "السعر الأساسي",
  "flightPriceTaxes": "الضرائب والرسوم",
  "flightPriceDiscount": "الخصم",
  "flightPriceTotal": "الإجمالي",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: succeeds, updates `lib/l10n/app_localizations*.dart`.

- [ ] **Step 4: Re-run every test left red in earlier tasks**

Run: `flutter test test/features/flight/`
Expected: PASS across all flight test files now that the `l10n` symbols and `flight_routes.dart` exist.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_ar.arb lib/l10n/app_localizations*.dart
git commit -m "Add flight search localization strings"
```

---

### Task 10: Wire the Home flight tab

**Files:**
- Modify: `lib/features/home/presentation/widgets/home_search_card.dart`
- Modify: `test/features/home/presentation/home_search_card_test.dart`

- [ ] **Step 1: Replace the flight "coming soon" branch with `FlightSearchForm`**

In `home_search_card.dart`:

```dart
// Add this import alongside the CarSearchForm import:
import 'package:safaria/features/flight/presentation/flight_search_form.dart';
```

Change the tab-changed snackbar so it no longer fires for the flight tab:

```dart
// Before:
            onChanged: (i) {
              widget.onTabChanged(i);
              if (i != TransportModeTabBar.busTabIndex &&
                  i != TransportModeTabBar.privateTabIndex) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(l10n.homeComingSoon),
                      duration: const Duration(seconds: 2),
                    ),
                  );
              }
            },
// After:
            onChanged: (i) {
              widget.onTabChanged(i);
            },
```

Change the body switch so the flight tab renders `FlightSearchForm` instead of the bus-shaped form:

```dart
// Before:
          if (isPrivateTab) const CarSearchForm() else _buildBusForm(l10n),
// After:
          if (isPrivateTab)
            const CarSearchForm()
          else if (widget.selectedTab == TransportModeTabBar.flightTabIndex)
            const FlightSearchForm()
          else
            _buildBusForm(l10n),
```

Now that the flight tab no longer renders `_buildBusForm`, its `showFlightClass` branch and the `_flightClass`/`_pickFlightClass` state in `HomeSearchCard` are dead — `FlightSearchForm` owns its own cabin-class picker internally. Remove them from `_HomeSearchCardState`:

```dart
// Delete this field:
  FlightClass _flightClass = kDefaultFlightClass;

// Delete this method:
  Future<void> _pickFlightClass() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showFlightClassPicker(
      context,
      title: l10n.homeFlightClass,
    );
    if (picked != null) setState(() => _flightClass = picked);
  }

// In _buildBusForm, delete:
    final showFlightClass = widget.selectedTab == HomeSearchCard.flightTabIndex;
// ...and the block that used it:
        if (showFlightClass) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.hairline),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: _ClassField(
              label: l10n.homeFlightClass,
              flightClass: _flightClass,
              onTap: _pickFlightClass,
            ),
          ),
        ],
```

Delete the now-unused `_ClassField` class from this file too (it lived here solely to serve the old flight branch of `_buildBusForm`; `FlightSearchForm` has its own copy) — and drop the now-unused `home_flight_class_picker.dart` import if nothing else in this file references `FlightClass`/`showFlightClassPicker`/`kDefaultFlightClass` after the deletions above.

- [ ] **Step 2: Run analyze to catch anything left dangling**

Run: `flutter analyze lib/features/home/presentation/widgets/home_search_card.dart`
Expected: no issues. If it flags an unused import or unused `AppRadius`/`AppColors` reference from the deleted block, remove it.

- [ ] **Step 3: Update `home_search_card_test.dart`**

```dart
// test/features/home/presentation/home_search_card_test.dart
// Add these imports:
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import '../../flight/fake_flight_repository.dart';

// Add this override inside _wrap()'s overrides list:
      flightRepositoryProvider.overrideWithValue(FakeFlightRepository()),
```

Then add a new test alongside the existing `'private tab shows request-car CTA label'` one:

```dart
  testWidgets('flight tab shows search-flights CTA label', (tester) async {
    await tester.pumpWidget(
      _wrap(
        HomeSearchCard(
          selectedTab: TransportModeTabBar.flightTabIndex,
          onTabChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search flights'), findsOneWidget);
    expect(find.text('Search trips'), findsNothing);
    expect(find.text('Request a car'), findsNothing);
  });

  testWidgets('flight tab no longer shows the coming-soon snackbar',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        HomeSearchCard(
          selectedTab: TransportModeTabBar.busTabIndex,
          onTabChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Flight'));
    await tester.pump();

    expect(find.text('Coming soon'), findsNothing);
  });
```

- [ ] **Step 4: Run the full home test file**

Run: `flutter test test/features/home/presentation/home_search_card_test.dart`
Expected: PASS (all tests, including the two new ones).

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/widgets/home_search_card.dart \
        test/features/home/presentation/home_search_card_test.dart
git commit -m "Wire the Home flight tab to FlightSearchForm"
```

---

### Task 11: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run codegen once more to be sure nothing drifted**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: succeeds with no unexpected diffs.

- [ ] **Step 2: Run static analysis on the whole project**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: all tests pass, including every flight test file from Tasks 1–10.

- [ ] **Step 4: Manually verify in the running app**

This is a real device/emulator flow — `flutter analyze`/`flutter test` don't exercise the UI. Per `CLAUDE.md`, run `flutter run` on the dev machine (Claude Code on the web installs Flutter via `.claude/hooks/session-start.sh` but still needs an attached device/emulator for this step; if none is available, hand this step to the user rather than skipping it silently):

1. Launch the app, land on Home, tap the **Flight** tab.
2. Confirm no "Coming soon" snackbar fires and the form shows From/To/Depart/Class/Passengers/Search.
3. Tap **From**, type "cai" (or similar), wait for results, pick an airport with the sheet's debounce visibly kicking in (not filtering instantly).
4. Repeat for **To** with a different airport, e.g. "dubai".
5. Tap **Search flights** — confirm it navigates to the results screen titled `XXX → YYY`.
6. Confirm the offer list renders logos/times/duration/stops/price, or the empty/error state renders sensibly if the live API returns nothing.
7. Tap an offer card — confirm the details screen shows the full segment breakdown, fare rules (if present), and price breakdown.
8. Tap **Select this flight** — confirm the "Booking coming soon" snackbar fires and nothing navigates further.
9. Switch the device to Arabic and repeat steps 2–8, confirming RTL layout doesn't break (fields mirror correctly, no clipped text).

- [ ] **Step 5: Report results**

Summarize what was verified against the checklist above (including whether device verification in Step 4 was actually performed or handed off) — do not report the task complete without having run Steps 1–3 and gotten clean output.

---

## Explicitly out of scope

Do not build in this plan, per the spec: Bundles, Add Passenger, Hold Trip, Pending Trip, Confirm Order UI, any payment flow, round-trip/multi-city search, or the `GET /flights/iata` endpoint's UI usage. `FlightApi`'s stub methods for the unresolved endpoints stay as unparsed `Future<dynamic>` — do not add response entities for them here.
