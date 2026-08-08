# Flight Search and Filters Implementation Plan (Phase 1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a rider search flights across all three trip types and narrow the results with a unified filter sheet.

**Architecture:** The search form drives a single `FlightSearchParams` whose `legs` list is the one source of truth for every trip type — one leg for one-way and round-trip, N legs for multi-city. Filtering splits in two: server-backed controls rebuild `FlightSearchParams` and re-search, while local controls run as pure functions over the returned offers. Every rule that carries risk (passenger limits, filter preservation across a re-search) lives in `domain/utils` as a plain function with no widget dependency, tested directly.

**Tech Stack:** Flutter, Riverpod (`Notifier`), Freezed, Dio, `flutter_localizations` ARB codegen.

**Scope:** Phase 1 of [`2026-08-08-flight-booking-screens-design.md`](../specs/2026-08-08-flight-booking-screens-design.md). Ends when a rider can browse and filter real fares. The booking wizard, passenger entry, and payment are phases 2–4 and get their own plans.

---

## Two decisions this plan locks in

Both are narrowings of the spec. Raise them before starting if you disagree.

**No local "stops" filter.** The spec listed stops as a local filter alongside the server's `directFlightsOnly`. Two controls doing almost the same job confuses more than it helps, so only the server-side direct-only toggle ships. A local max-stops control can be added later if riders ask.

**"Refundable only" means `FullyRefundable` or `PartiallyRefundable`.** The flow spec suggested `!= "NotRefundable"`, which would let `UnKnown` through. Showing an unknown fare under a refundable filter is a promise we cannot keep.

---

## File Structure

**Create:**

| File | Responsibility |
|------|----------------|
| `lib/features/flight/domain/entities/flight_passenger_counts.dart` | Adult/child/infant counts as a value object |
| `lib/features/flight/domain/utils/flight_passenger_rules.dart` | The 9-cap, `INF ≤ ADT`, and wire conversion — pure |
| `lib/features/flight/domain/entities/flight_offer_filters.dart` | Local filter state and the carrier option view model |
| `lib/features/flight/domain/utils/apply_flight_offer_filters.dart` | Derivation, application, and preservation of local filters — pure |
| `lib/features/flight/presentation/widgets/flight_trip_type_selector.dart` | Segmented one-way / round-trip / multi-city control |
| `lib/features/flight/presentation/widgets/flight_leg_row.dart` | One multi-city leg: origin, destination, date, remove |
| `lib/features/flight/presentation/widgets/flight_filter_sheet.dart` | The unified sheet, both groups |
| `lib/features/flight/presentation/widgets/flight_filter_button.dart` | App-bar entry point with an active-count badge |

**Modify:**

| File | Change |
|------|--------|
| `lib/features/flight/domain/entities/flight_search_params.dart` | Replace flat origin/destination/date with `legs` + `returnDate` |
| `lib/features/flight/data/flight_dto_mapper.dart` | Three request-body shapes |
| `lib/features/flight/data/flight_repository_impl.dart` | Pass the new params through |
| `lib/features/flight/presentation/providers/flight_booking_providers.dart` | Hold filters, expose filtered offers, preserve on re-search |
| `lib/features/flight/presentation/flight_search_form.dart` | Trip types, legs, new passenger sheet |
| `lib/features/flight/presentation/flight_results_screen.dart` | Filter button, lazy list, filtered-empty state |
| `lib/features/flight/presentation/widgets/flight_passenger_count_field.dart` | Three types with disable-reason |
| `lib/features/flight/presentation/widgets/flight_offer_card.dart` | Render every journey, not just the first |
| `lib/features/home/presentation/widgets/home_flight_class_picker.dart` | Five cabin classes |
| `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` | New strings |

**Test:**

| File | Covers |
|------|--------|
| `test/features/flight/domain/flight_passenger_rules_test.dart` | Passenger limits and wire conversion |
| `test/features/flight/domain/apply_flight_offer_filters_test.dart` | Filter derivation, application, preservation |
| `test/features/flight/data/flight_search_body_test.dart` | The three request shapes |
| `test/features/flight/presentation/flight_passenger_count_field_test.dart` | Disable-with-reason behaviour |
| `test/features/flight/presentation/flight_filter_sheet_test.dart` | Live count and apply |

---

## Task 1: Passenger counts and rules

**Files:**
- Create: `lib/features/flight/domain/entities/flight_passenger_counts.dart`
- Create: `lib/features/flight/domain/utils/flight_passenger_rules.dart`
- Test: `test/features/flight/domain/flight_passenger_rules_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_rules.dart';

void main() {
  test('total sums all three types', () {
    const counts = FlightPassengerCounts(adults: 2, children: 3, infants: 1);
    expect(counts.total, 6);
  });

  test('a tenth passenger is blocked, whatever the type', () {
    const counts = FlightPassengerCounts(adults: 5, children: 4);
    expect(canAddFlightPassenger(counts, FlightPassengerType.child), isFalse);
    expect(
      flightPassengerLimit(counts, FlightPassengerType.child),
      FlightPassengerLimit.maxTotal,
    );
  });

  test('an infant needs a spare adult', () {
    const counts = FlightPassengerCounts(adults: 2, infants: 2);
    expect(canAddFlightPassenger(counts, FlightPassengerType.infant), isFalse);
    expect(
      flightPassengerLimit(counts, FlightPassengerType.infant),
      FlightPassengerLimit.infantsPerAdult,
    );
  });

  test('an infant is allowed while adults outnumber infants', () {
    const counts = FlightPassengerCounts(adults: 2, infants: 1);
    expect(canAddFlightPassenger(counts, FlightPassengerType.infant), isTrue);
  });

  test('the last adult cannot be removed', () {
    const counts = FlightPassengerCounts(adults: 1);
    expect(
      canRemoveFlightPassenger(counts, FlightPassengerType.adult),
      isFalse,
    );
  });

  test('an adult an infant depends on cannot be removed', () {
    const counts = FlightPassengerCounts(adults: 2, infants: 2);
    expect(
      canRemoveFlightPassenger(counts, FlightPassengerType.adult),
      isFalse,
    );
  });

  test('wire passengers omit zero counts', () {
    const counts = FlightPassengerCounts(adults: 2, children: 1);
    final wire = toWirePassengers(counts);
    expect(wire.map((p) => p.passengerTypeCode).toList(), ['ADT', 'CHD']);
    expect(wire.first.count, 2);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight/domain/flight_passenger_rules_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart'`

- [ ] **Step 3: Write the entity**

Create `lib/features/flight/domain/entities/flight_passenger_counts.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'flight_passenger_counts.freezed.dart';

enum FlightPassengerType { adult, child, infant }

/// Passenger composition chosen in the search form, before any traveller
/// details are known.
@freezed
abstract class FlightPassengerCounts with _$FlightPassengerCounts {
  const FlightPassengerCounts._();

  const factory FlightPassengerCounts({
    @Default(1) int adults,
    @Default(0) int children,
    @Default(0) int infants,
  }) = _FlightPassengerCounts;

  int get total => adults + children + infants;
}
```

- [ ] **Step 4: Write the rules**

Create `lib/features/flight/domain/utils/flight_passenger_rules.dart`:

```dart
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';

/// Hard cap on one flight booking.
const kMaxFlightPassengers = 9;

/// Why an increment is unavailable. [none] means it is available.
enum FlightPassengerLimit { none, maxTotal, infantsPerAdult }

FlightPassengerLimit flightPassengerLimit(
  FlightPassengerCounts counts,
  FlightPassengerType type,
) {
  if (counts.total >= kMaxFlightPassengers) {
    return FlightPassengerLimit.maxTotal;
  }
  if (type == FlightPassengerType.infant && counts.infants >= counts.adults) {
    return FlightPassengerLimit.infantsPerAdult;
  }
  return FlightPassengerLimit.none;
}

bool canAddFlightPassenger(
  FlightPassengerCounts counts,
  FlightPassengerType type,
) =>
    flightPassengerLimit(counts, type) == FlightPassengerLimit.none;

/// Removing an adult is blocked when it would leave the party without an
/// adult, or leave an infant without one to travel with.
bool canRemoveFlightPassenger(
  FlightPassengerCounts counts,
  FlightPassengerType type,
) {
  return switch (type) {
    FlightPassengerType.adult =>
      counts.adults > 1 && counts.adults - 1 >= counts.infants,
    FlightPassengerType.child => counts.children > 0,
    FlightPassengerType.infant => counts.infants > 0,
  };
}

String flightPassengerWireCode(FlightPassengerType type) => switch (type) {
      FlightPassengerType.adult => 'ADT',
      FlightPassengerType.child => 'CHD',
      FlightPassengerType.infant => 'INF',
    };

/// Search-request form. Types with a zero count are omitted entirely.
List<FlightPassengerCount> toWirePassengers(FlightPassengerCounts counts) {
  return [
    if (counts.adults > 0)
      FlightPassengerCount(passengerTypeCode: 'ADT', count: counts.adults),
    if (counts.children > 0)
      FlightPassengerCount(passengerTypeCode: 'CHD', count: counts.children),
    if (counts.infants > 0)
      FlightPassengerCount(passengerTypeCode: 'INF', count: counts.infants),
  ];
}
```

- [ ] **Step 5: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `Succeeded after ...` and `flight_passenger_counts.freezed.dart` on disk.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/flight/domain/flight_passenger_rules_test.dart`
Expected: PASS — 7 tests.

- [ ] **Step 7: Commit**

```bash
git add lib/features/flight/domain/entities/flight_passenger_counts.dart lib/features/flight/domain/utils/flight_passenger_rules.dart test/features/flight/domain/flight_passenger_rules_test.dart
git commit -m "Add Flight Passenger Composition Rules"
```

---

## Task 2: Search params across three trip types

Replaces the flat `origin` / `destination` / `date` trio with a `legs` list. One-way and round-trip carry exactly one leg; multi-city carries two to five. This is a breaking change — the form and notifier are repaired in later tasks, so the analyzer will report errors until Task 4 lands.

**Files:**
- Modify: `lib/features/flight/domain/entities/flight_search_params.dart`
- Test: `test/features/flight/data/flight_search_body_test.dart` (created in Task 3)

- [ ] **Step 1: Add the leg entity and reshape the params**

Replace the `FlightSearchParams` class at the bottom of `lib/features/flight/domain/entities/flight_search_params.dart` with:

```dart
/// One origin→destination hop on a given date. One-way and round-trip
/// searches carry exactly one; multi-city carries one per city pair.
@freezed
abstract class FlightSearchLeg with _$FlightSearchLeg {
  const factory FlightSearchLeg({
    required String origin,
    required String destination,
    required DateTime date,
  }) = _FlightSearchLeg;
}

/// Params for `POST /flights/search`.
///
/// [legs] is the single source of truth for the route. [returnDate] applies
/// only to [FlightTripType.roundTrip]; multi-city expresses the return as
/// another entry in [legs].
@freezed
abstract class FlightSearchParams with _$FlightSearchParams {
  const FlightSearchParams._();

  const factory FlightSearchParams({
    required List<FlightSearchLeg> legs,
    DateTime? returnDate,
    required List<FlightPassengerCount> passengers,
    @Default(FlightSortingCriteria.cheapestFirst)
    FlightSortingCriteria sortingCriteria,
    @Default(FlightCabinClass.economy) FlightCabinClass cabinClass,
    @Default(false) bool directFlightsOnly,
    @Default(FlightTripType.oneWay) FlightTripType tripType,
    required String currency,
  }) = _FlightSearchParams;

  FlightSearchLeg get firstLeg => legs.first;
}
```

Delete the stale doc comment above the old class that says round-trip and multi-city shapes are unconfirmed — both are documented in the flow spec now.

- [ ] **Step 2: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `Succeeded after ...`

- [ ] **Step 3: Commit**

```bash
git add lib/features/flight/domain/entities/flight_search_params.dart
git commit -m "Reshape Flight Search Params Around Legs"
```

---

## Task 3: Three request body shapes

**Files:**
- Modify: `lib/features/flight/data/flight_dto_mapper.dart` (replace `searchRequestBody`)
- Test: `test/features/flight/data/flight_search_body_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/flight/data/flight_search_body_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/data/flight_dto_mapper.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';

const _legCaiRuh = {
  'origin': 'CAI',
  'destination': 'RUH',
  'date': '2026-08-30',
};
const _legRuhJed = {
  'origin': 'RUH',
  'destination': 'JED',
  'date': '2026-09-02',
};

const _passengers = [
  {'passengerTypeCode': 'ADT', 'count': 1},
];

Map<String, dynamic> _body({
  required FlightTripType tripType,
  required List<Map<String, String>> legs,
  String? returnDate,
}) {
  return FlightDtoMapper.searchRequestBody(
    tripType: tripType,
    legs: legs,
    returnDate: returnDate,
    passengers: _passengers,
    sortingCriteria: 'CheapestFirst',
    cabinClass: 'CABIN_CLASS_ECONOMY',
    directFlightsOnly: false,
    currency: 'EGP',
  );
}

void main() {
  test('one-way sends a flat origin, destination and date', () {
    final body = _body(
      tripType: FlightTripType.oneWay,
      legs: [_legCaiRuh],
    );
    expect(body['origin'], 'CAI');
    expect(body['destination'], 'RUH');
    expect(body['date'], '2026-08-30');
    expect(body['trip_type'], 'one_way');
    expect(body.containsKey('return_date'), isFalse);
    expect(body.containsKey('segments'), isFalse);
  });

  test('round trip adds return_date', () {
    final body = _body(
      tripType: FlightTripType.roundTrip,
      legs: [_legCaiRuh],
      returnDate: '2026-09-05',
    );
    expect(body['origin'], 'CAI');
    expect(body['return_date'], '2026-09-05');
    expect(body['trip_type'], 'round_trip');
  });

  test('multi city sends segments and no flat route keys', () {
    final body = _body(
      tripType: FlightTripType.multiCity,
      legs: [_legCaiRuh, _legRuhJed],
    );
    expect(body['segments'], [_legCaiRuh, _legRuhJed]);
    expect(body['trip_type'], 'multi_city');
    expect(body.containsKey('origin'), isFalse);
    expect(body.containsKey('destination'), isFalse);
    expect(body.containsKey('date'), isFalse);
  });

  test('every shape keeps the misspelled currency key', () {
    for (final tripType in FlightTripType.values) {
      final body = _body(tripType: tripType, legs: [_legCaiRuh]);
      expect(body['curreny'], 'EGP', reason: '${tripType.wireValue}');
      expect(body.containsKey('currency'), isFalse);
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight/data/flight_search_body_test.dart`
Expected: FAIL — `No named parameter with the name 'tripType'`

- [ ] **Step 3: Replace the body builder**

In `lib/features/flight/data/flight_dto_mapper.dart`, add the import at the top:

```dart
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
```

Then replace the whole `searchRequestBody` method with:

```dart
  /// Builds the `POST /flights/search` body.
  ///
  /// Multi-city replaces the flat `origin`/`destination`/`date` trio with a
  /// `segments` array; round-trip keeps the trio and adds `return_date`.
  ///
  /// The backend expects the misspelled `curreny` key here — `currency` is
  /// silently rejected. Note that the *order creation* endpoint wants the
  /// correct spelling; the two endpoints genuinely disagree.
  static Map<String, dynamic> searchRequestBody({
    required FlightTripType tripType,
    required List<Map<String, String>> legs,
    required List<Map<String, dynamic>> passengers,
    required String sortingCriteria,
    required String cabinClass,
    required bool directFlightsOnly,
    required String currency,
    String? returnDate,
  }) {
    final common = <String, dynamic>{
      'passengers': passengers,
      'sortingCriteria': sortingCriteria,
      'cabinClass': cabinClass,
      'directFlightsOnly': directFlightsOnly,
      'trip_type': tripType.wireValue,
      'curreny': currency,
    };

    if (tripType == FlightTripType.multiCity) {
      return {'segments': legs, ...common};
    }

    final leg = legs.first;
    return {
      'origin': leg['origin'],
      'destination': leg['destination'],
      'date': leg['date'],
      if (tripType == FlightTripType.roundTrip && returnDate != null)
        'return_date': returnDate,
      ...common,
    };
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/flight/data/flight_search_body_test.dart`
Expected: PASS — 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/flight/data/flight_dto_mapper.dart test/features/flight/data/flight_search_body_test.dart
git commit -m "Build Flight Search Bodies For All Trip Types"
```

---

## Task 4: Repository and notifier wiring

Repairs the compile errors introduced in Task 2.

**Files:**
- Modify: `lib/features/flight/data/flight_repository_impl.dart:41-66`
- Modify: `lib/features/flight/presentation/providers/flight_booking_providers.dart`

- [ ] **Step 1: Pass the new params through the repository**

In `lib/features/flight/data/flight_repository_impl.dart`, replace the body of `search` with:

```dart
  @override
  Future<List<FlightOffer>> search(FlightSearchParams params) {
    return _guard(() async {
      final body = await _api.search(
        FlightDtoMapper.searchRequestBody(
          tripType: params.tripType,
          legs: params.legs
              .map(
                (leg) => {
                  'origin': leg.origin,
                  'destination': leg.destination,
                  'date': toIsoDate(leg.date),
                },
              )
              .toList(),
          returnDate:
              params.returnDate == null ? null : toIsoDate(params.returnDate!),
          passengers: params.passengers
              .map(
                (p) => {
                  'passengerTypeCode': p.passengerTypeCode,
                  'count': p.count,
                },
              )
              .toList(),
          sortingCriteria: params.sortingCriteria.wireValue,
          cabinClass: params.cabinClass.wireValue,
          directFlightsOnly: params.directFlightsOnly,
          currency: params.currency,
        ),
      );
      return FlightDtoMapper.offersFromEnvelope(body);
    });
  }
```

- [ ] **Step 2: Run the analyzer to find remaining breakages**

Run: `flutter analyze`
Expected: errors only in `flight_search_form.dart` and any test constructing `FlightSearchParams` with the old fields. Note each file — they are repaired in Tasks 7 and 11.

- [ ] **Step 3: Commit**

```bash
git add lib/features/flight/data/flight_repository_impl.dart
git commit -m "Wire Flight Repository To Leg Based Search Params"
```

---

## Task 5: Five cabin classes

**Files:**
- Modify: `lib/features/home/presentation/widgets/home_flight_class_picker.dart:14-29`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`

- [ ] **Step 1: Add the two missing strings**

In `lib/l10n/app_en.arb`, after the `"homeClassFirst"` line, add:

```json
  "homeClassPremiumEconomy": "Premium economy",
  "homeClassAll": "All classes",
```

In `lib/l10n/app_ar.arb`, after its `"homeClassFirst"` line, add:

```json
  "homeClassPremiumEconomy": "الاقتصادية المميزة",
  "homeClassAll": "كل الدرجات",
```

- [ ] **Step 2: Extend the picker**

In `lib/features/home/presentation/widgets/home_flight_class_picker.dart`, replace the label switch and the class list with:

```dart
        'economy' => l10n.homeClassEconomy,
        'premium_economy' => l10n.homeClassPremiumEconomy,
        'business' => l10n.homeClassBusiness,
        'first' => l10n.homeClassFirst,
        'all' => l10n.homeClassAll,
```

```dart
const kFlightClasses = <FlightClass>[
  FlightClass(id: 'economy'),
  FlightClass(id: 'premium_economy'),
  FlightClass(id: 'business'),
  FlightClass(id: 'first'),
  FlightClass(id: 'all'),
];
```

Keep `kDefaultFlightClass` as `economy` — `all` is offered but never preselected.

- [ ] **Step 3: Add the wire mapping**

Append to the same file:

```dart
/// Maps a picker entry to the value `POST /flights/search` expects.
FlightCabinClass flightCabinClassFor(FlightClass value) => switch (value.id) {
      'premium_economy' => FlightCabinClass.premiumEconomy,
      'business' => FlightCabinClass.business,
      'first' => FlightCabinClass.first,
      'all' => FlightCabinClass.unspecified,
      _ => FlightCabinClass.economy,
    };
```

Add the import it needs at the top of the file:

```dart
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
```

- [ ] **Step 4: Regenerate localizations and analyze**

Run: `flutter gen-l10n && flutter analyze lib/features/home/presentation/widgets/home_flight_class_picker.dart`
Expected: no issues in that file.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/widgets/home_flight_class_picker.dart lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "Add Premium Economy And All Cabin Classes"
```

---

## Task 6: Passenger sheet with three types

**Files:**
- Modify: `lib/features/flight/presentation/widgets/flight_passenger_count_field.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`
- Test: `test/features/flight/presentation/flight_passenger_count_field_test.dart`

- [ ] **Step 1: Add the strings**

In `lib/l10n/app_en.arb`:

```json
  "flightPaxTitle": "Passengers",
  "flightPaxAdults": "Adults",
  "flightPaxAdultsAge": "Aged 12 and over",
  "flightPaxChildren": "Children",
  "flightPaxChildrenAge": "Aged 2 to 11",
  "flightPaxInfants": "Infants",
  "flightPaxInfantsAge": "Under 2",
  "flightPaxCount": "{used} of {max}",
  "flightPaxLimitTotal": "9 passengers maximum",
  "flightPaxLimitInfants": "One infant per adult",
  "flightPaxApply": "Apply",
```

Add the placeholder metadata for the count string, in the same file:

```json
  "@flightPaxCount": {
    "placeholders": { "used": {"type": "int"}, "max": {"type": "int"} }
  },
```

In `lib/l10n/app_ar.arb`:

```json
  "flightPaxTitle": "الركاب",
  "flightPaxAdults": "بالغون",
  "flightPaxAdultsAge": "12 سنة فأكتر",
  "flightPaxChildren": "أطفال",
  "flightPaxChildrenAge": "من 2 لـ 11 سنة",
  "flightPaxInfants": "رُضّع",
  "flightPaxInfantsAge": "أقل من سنتين",
  "flightPaxCount": "{used} من {max}",
  "flightPaxLimitTotal": "الحد الأقصى 9 ركاب",
  "flightPaxLimitInfants": "لكل بالغ رضيع واحد",
  "flightPaxApply": "تطبيق",
```

- [ ] **Step 2: Write the failing test**

Create `test/features/flight/presentation/flight_passenger_count_field_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_passenger_count_field.dart';
import 'package:safaria/l10n/app_localizations.dart';

Future<void> _pump(
  WidgetTester tester,
  FlightPassengerCounts counts,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: FlightPassengerCountSheet(
          initial: counts,
          onApply: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('states why infants cannot be added', (tester) async {
    await _pump(tester, const FlightPassengerCounts(adults: 2, infants: 2));
    expect(find.text('One infant per adult'), findsOneWidget);
  });

  testWidgets('states why no more passengers fit', (tester) async {
    await _pump(tester, const FlightPassengerCounts(adults: 5, children: 4));
    expect(find.text('9 passengers maximum'), findsOneWidget);
  });

  testWidgets('shows the running total', (tester) async {
    await _pump(tester, const FlightPassengerCounts(adults: 2, children: 1));
    expect(find.text('3 of 9'), findsOneWidget);
  });

  testWidgets('adding a child raises the total', (tester) async {
    await _pump(tester, const FlightPassengerCounts(adults: 1));
    await tester.tap(find.byKey(const Key('flight-pax-add-child')));
    await tester.pump();
    expect(find.text('2 of 9'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/flight/presentation/flight_passenger_count_field_test.dart`
Expected: FAIL — `FlightPassengerCountSheet` is not defined.

- [ ] **Step 4: Write the sheet**

Replace the contents of `lib/features/flight/presentation/widgets/flight_passenger_count_field.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_rules.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Adult/child/infant picker. Increments disable with a stated reason rather
/// than failing silently — a dead control with no explanation is the failure
/// mode this screen exists to avoid.
class FlightPassengerCountSheet extends StatefulWidget {
  const FlightPassengerCountSheet({
    super.key,
    required this.initial,
    required this.onApply,
  });

  final FlightPassengerCounts initial;
  final ValueChanged<FlightPassengerCounts> onApply;

  @override
  State<FlightPassengerCountSheet> createState() =>
      _FlightPassengerCountSheetState();
}

class _FlightPassengerCountSheetState extends State<FlightPassengerCountSheet> {
  late FlightPassengerCounts _counts = widget.initial;

  void _add(FlightPassengerType type) {
    if (!canAddFlightPassenger(_counts, type)) return;
    setState(() {
      _counts = switch (type) {
        FlightPassengerType.adult =>
          _counts.copyWith(adults: _counts.adults + 1),
        FlightPassengerType.child =>
          _counts.copyWith(children: _counts.children + 1),
        FlightPassengerType.infant =>
          _counts.copyWith(infants: _counts.infants + 1),
      };
    });
  }

  void _remove(FlightPassengerType type) {
    if (!canRemoveFlightPassenger(_counts, type)) return;
    setState(() {
      _counts = switch (type) {
        FlightPassengerType.adult =>
          _counts.copyWith(adults: _counts.adults - 1),
        FlightPassengerType.child =>
          _counts.copyWith(children: _counts.children - 1),
        FlightPassengerType.infant =>
          _counts.copyWith(infants: _counts.infants - 1),
      };
    });
  }

  /// The most relevant blocked rule across all three rows, or null when
  /// nothing is blocked. Total-cap wins because it explains every row at once.
  String? _limitMessage(AppLocalizations l10n) {
    if (_counts.total >= kMaxFlightPassengers) return l10n.flightPaxLimitTotal;
    if (flightPassengerLimit(_counts, FlightPassengerType.infant) ==
        FlightPassengerLimit.infantsPerAdult) {
      return l10n.flightPaxLimitInfants;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final limit = _limitMessage(l10n);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.flightPaxTitle, style: AppTypography.h2),
              Text(
                l10n.flightPaxCount(_counts.total, kMaxFlightPassengers),
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _CountRow(
            keyPrefix: 'adult',
            label: l10n.flightPaxAdults,
            hint: l10n.flightPaxAdultsAge,
            value: _counts.adults,
            canAdd: canAddFlightPassenger(_counts, FlightPassengerType.adult),
            canRemove:
                canRemoveFlightPassenger(_counts, FlightPassengerType.adult),
            onAdd: () => _add(FlightPassengerType.adult),
            onRemove: () => _remove(FlightPassengerType.adult),
          ),
          _CountRow(
            keyPrefix: 'child',
            label: l10n.flightPaxChildren,
            hint: l10n.flightPaxChildrenAge,
            value: _counts.children,
            canAdd: canAddFlightPassenger(_counts, FlightPassengerType.child),
            canRemove:
                canRemoveFlightPassenger(_counts, FlightPassengerType.child),
            onAdd: () => _add(FlightPassengerType.child),
            onRemove: () => _remove(FlightPassengerType.child),
          ),
          _CountRow(
            keyPrefix: 'infant',
            label: l10n.flightPaxInfants,
            hint: l10n.flightPaxInfantsAge,
            value: _counts.infants,
            canAdd: canAddFlightPassenger(_counts, FlightPassengerType.infant),
            canRemove:
                canRemoveFlightPassenger(_counts, FlightPassengerType.infant),
            onAdd: () => _add(FlightPassengerType.infant),
            onRemove: () => _remove(FlightPassengerType.infant),
          ),
          if (limit != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.secondaryTint,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsLight.info,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      limit,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.secondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: l10n.flightPaxApply,
            onPressed: () => widget.onApply(_counts),
          ),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.keyPrefix,
    required this.label,
    required this.hint,
    required this.value,
    required this.canAdd,
    required this.canRemove,
    required this.onAdd,
    required this.onRemove,
  });

  final String keyPrefix;
  final String label;
  final String hint;
  final int value;
  final bool canAdd;
  final bool canRemove;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.body),
                Text(
                  hint,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          _StepButton(
            key: Key('flight-pax-remove-$keyPrefix'),
            icon: PhosphorIconsLight.minus,
            enabled: canRemove,
            onTap: onRemove,
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
          ),
          _StepButton(
            key: Key('flight-pax-add-$keyPrefix'),
            icon: PhosphorIconsLight.plus,
            enabled: canAdd,
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: enabled ? onTap : null,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: enabled ? color : AppColors.hairline),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter gen-l10n && flutter test test/features/flight/presentation/flight_passenger_count_field_test.dart`
Expected: PASS — 4 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/features/flight/presentation/widgets/flight_passenger_count_field.dart lib/l10n/app_en.arb lib/l10n/app_ar.arb test/features/flight/presentation/flight_passenger_count_field_test.dart
git commit -m "Add Child And Infant Counts To Flight Passenger Sheet"
```

---

## Task 7: Trip type selector and multi-city legs

**Files:**
- Create: `lib/features/flight/presentation/widgets/flight_trip_type_selector.dart`
- Create: `lib/features/flight/presentation/widgets/flight_leg_row.dart`
- Modify: `lib/features/flight/presentation/flight_search_form.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`

- [ ] **Step 1: Add the strings**

In `lib/l10n/app_en.arb`:

```json
  "flightTripOneWay": "One way",
  "flightTripRound": "Round trip",
  "flightTripMulti": "Multi-city",
  "flightLegLabel": "Leg {number}",
  "flightAddLeg": "Add another leg",
  "flightReturnDate": "Return date",
  "@flightLegLabel": {
    "placeholders": { "number": {"type": "int"} }
  },
```

In `lib/l10n/app_ar.arb`:

```json
  "flightTripOneWay": "ذهاب",
  "flightTripRound": "ذهاب وعودة",
  "flightTripMulti": "متعدد المدن",
  "flightLegLabel": "المسار {number}",
  "flightAddLeg": "إضافة مسار",
  "flightReturnDate": "تاريخ العودة",
```

- [ ] **Step 2: Write the selector**

Create `lib/features/flight/presentation/widgets/flight_trip_type_selector.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Segmented one-way / round-trip / multi-city control. The search form body
/// morphs beneath it.
class FlightTripTypeSelector extends StatelessWidget {
  const FlightTripTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final FlightTripType value;
  final ValueChanged<FlightTripType> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgBase,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (final type in FlightTripType.values)
            Expanded(
              child: GestureDetector(
                key: Key('flight-trip-${type.wireValue}'),
                onTap: () => onChanged(type),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: type == value
                        ? AppColors.bgElevated
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    switch (type) {
                      FlightTripType.oneWay => l10n.flightTripOneWay,
                      FlightTripType.roundTrip => l10n.flightTripRound,
                      FlightTripType.multiCity => l10n.flightTripMulti,
                    },
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: type == value
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight:
                          type == value ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Rework the search form state**

In `lib/features/flight/presentation/flight_search_form.dart`, replace the state fields with:

```dart
  FlightTripType _tripType = FlightTripType.oneWay;
  final List<_LegDraft> _legs = [_LegDraft()];
  DateTime? _returnDate;
  FlightClass _flightClass = kDefaultFlightClass;
  FlightPassengerCounts _passengers = const FlightPassengerCounts();
  bool _searching = false;

  static const _maxBookingDays = 90;
  static const _maxLegs = 5;
```

Add the draft type at the bottom of the file:

```dart
/// A leg while the rider is still filling it in — airports may be unset.
class _LegDraft {
  _LegDraft({this.origin, this.destination, DateTime? date})
      : date = date ?? dateOnly(DateTime.now());

  FlightAirportSuggestion? origin;
  FlightAirportSuggestion? destination;
  DateTime date;

  bool get isComplete => origin != null && destination != null;
}
```

- [ ] **Step 4: Add leg management**

Add these methods to `_FlightSearchFormState`:

```dart
  /// A new leg starts where the previous one ended — right in most
  /// itineraries, and it saves the rider a whole airport search.
  void _addLeg() {
    if (_legs.length >= _maxLegs) return;
    final previous = _legs.last;
    setState(() {
      _legs.add(
        _LegDraft(
          origin: previous.destination,
          date: previous.date.add(const Duration(days: 1)),
        ),
      );
    });
  }

  void _removeLeg(int index) {
    if (index == 0 || _legs.length <= 1) return;
    setState(() => _legs.removeAt(index));
  }

  /// A leg cannot depart before the one it follows. Changing a date pushes
  /// any later leg that would now be in the past forward to match.
  void _setLegDate(int index, DateTime date) {
    setState(() {
      _legs[index].date = date;
      for (var i = index + 1; i < _legs.length; i++) {
        if (_legs[i].date.isBefore(_legs[i - 1].date)) {
          _legs[i].date = _legs[i - 1].date;
        }
      }
    });
  }

  /// Earliest date leg [index] may depart: today for the first leg, the
  /// previous leg's date for the rest.
  DateTime _minDateForLeg(int index) =>
      index == 0 ? dateOnly(DateTime.now()) : _legs[index - 1].date;

  /// Switching trip type keeps the first leg and discards the rest.
  void _setTripType(FlightTripType type) {
    setState(() {
      _tripType = type;
      if (type != FlightTripType.multiCity && _legs.length > 1) {
        _legs.removeRange(1, _legs.length);
      }
      if (type != FlightTripType.roundTrip) _returnDate = null;
      if (type == FlightTripType.multiCity && _legs.length == 1) _addLeg();
    });
  }
```

- [ ] **Step 5: Build the params on submit**

Replace the params construction in the form's submit handler with:

```dart
    final params = FlightSearchParams(
      tripType: _tripType,
      legs: _legs
          .map(
            (leg) => FlightSearchLeg(
              origin: leg.origin!.iataCode,
              destination: leg.destination!.iataCode,
              date: leg.date,
            ),
          )
          .toList(),
      returnDate: _tripType == FlightTripType.roundTrip ? _returnDate : null,
      passengers: toWirePassengers(_passengers),
      cabinClass: flightCabinClassFor(_flightClass),
      currency: 'EGP',
    );
```

Guard submission on every leg being complete, and on `_returnDate` being set for round-trip:

```dart
  bool get _canSubmit {
    if (!_legs.every((leg) => leg.isComplete)) return false;
    if (_tripType == FlightTripType.roundTrip) {
      final returnDate = _returnDate;
      if (returnDate == null) return false;
      if (returnDate.isBefore(_legs.first.date)) return false;
    }
    return true;
  }
```

Add the imports the form now needs:

```dart
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_rules.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_trip_type_selector.dart';
```

- [ ] **Step 6: Verify it compiles and the app runs**

Run: `flutter gen-l10n && flutter analyze lib/features/flight`
Expected: no issues.

Run: `flutter run` and open the Home flight tab. Switch to multi-city, confirm a second leg appears prefilled from the first leg's destination, and that switching back to one-way drops it.

- [ ] **Step 7: Commit**

```bash
git add lib/features/flight/presentation lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "Add Trip Type Selector And Multi City Legs To Flight Search"
```

---

## Task 8: Local filter logic

The riskiest logic in this phase. All pure — no widgets, no providers.

**Files:**
- Create: `lib/features/flight/domain/entities/flight_offer_filters.dart`
- Create: `lib/features/flight/domain/utils/apply_flight_offer_filters.dart`
- Test: `test/features/flight/domain/apply_flight_offer_filters_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/flight/domain/apply_flight_offer_filters_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer_filters.dart';
import 'package:safaria/features/flight/domain/utils/apply_flight_offer_filters.dart';

FlightOffer _offer({
  required String id,
  required String carrier,
  required double price,
  String refundability = 'FullyRefundable',
  String? carrierName,
}) {
  final departure = DateTime(2026, 8, 30, 10);
  return FlightOffer(
    offerId: id,
    haveBundles: false,
    canBeHeld: true,
    refundability: refundability,
    journeys: [
      FlightJourney(
        id: 'j-$id',
        origin: 'CAI',
        destination: 'RUH',
        numberOfStops: 0,
        segments: [
          FlightSegment(
            id: 's-$id',
            origin: 'CAI',
            destination: 'RUH',
            departureDateTime: departure,
            arrivalDateTime: departure.add(const Duration(hours: 3)),
            flightTimeInMinutes: 180,
            operatingCarrierCode: carrier,
            operatingCarrierName: carrierName,
            operatingFlightNumber: '100',
            marketingCarrierCode: carrier,
            marketingFlightNumber: '100',
          ),
        ],
      ),
    ],
    totalAmount: price,
    taxesAmount: 0,
    baseAmount: price,
    discountAmount: 0,
    beforeDiscountAmount: price,
    serviceChargeAmount: 0,
    currency: 'EGP',
    priceClasses: const [],
  );
}

void main() {
  final nileCheap = _offer(id: '1', carrier: 'NE', price: 3000, carrierName: 'Nile Air');
  final nileDear = _offer(id: '2', carrier: 'NE', price: 9000, carrierName: 'Nile Air');
  final egyptair = _offer(id: '3', carrier: 'MS', price: 5000);
  final unknownRefund =
      _offer(id: '4', carrier: 'MS', price: 5500, refundability: 'UnKnown');
  final offers = [nileCheap, nileDear, egyptair, unknownRefund];

  test('carrier options count offers and prefer the named carrier', () {
    final options = flightCarrierOptions(offers);
    expect(options.first.code, 'MS');
    expect(options.first.offerCount, 2);
    expect(options.last.code, 'NE');
    expect(options.last.name, 'Nile Air');
  });

  test('price bounds span the cheapest and dearest offer', () {
    expect(flightPriceBounds(offers), (3000.0, 9000.0));
  });

  test('empty filters return the list untouched', () {
    expect(
      applyFlightOfferFilters(offers, const FlightOfferFilters()),
      same(offers),
    );
  });

  test('carrier filter keeps only matching offers', () {
    final result = applyFlightOfferFilters(
      offers,
      const FlightOfferFilters(carrierCodes: {'NE'}),
    );
    expect(result.map((o) => o.offerId).toList(), ['1', '2']);
  });

  test('price filter is inclusive at both ends', () {
    final result = applyFlightOfferFilters(
      offers,
      const FlightOfferFilters(minPrice: 3000, maxPrice: 5000),
    );
    expect(result.map((o) => o.offerId).toList(), ['1', '3']);
  });

  test('refundable only excludes unknown refundability', () {
    final result = applyFlightOfferFilters(
      offers,
      const FlightOfferFilters(refundableOnly: true),
    );
    expect(result.map((o) => o.offerId).contains('4'), isFalse);
  });

  test('preserving drops carriers absent from the new results', () {
    const filters = FlightOfferFilters(carrierCodes: {'NE', 'MS'});
    final preserved =
        preserveFlightFilters(filters: filters, offers: [egyptair]);
    expect(preserved.carrierCodes, {'MS'});
  });

  test('preserving clamps a touched price range to the new bounds', () {
    const filters = FlightOfferFilters(minPrice: 1000, maxPrice: 20000);
    final preserved = preserveFlightFilters(filters: filters, offers: offers);
    expect(preserved.minPrice, 3000);
    expect(preserved.maxPrice, 9000);
  });

  test('preserving leaves an untouched price range untouched', () {
    const filters = FlightOfferFilters(refundableOnly: true);
    final preserved = preserveFlightFilters(filters: filters, offers: offers);
    expect(preserved.minPrice, isNull);
    expect(preserved.maxPrice, isNull);
    expect(preserved.refundableOnly, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight/domain/apply_flight_offer_filters_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../flight_offer_filters.dart'`

- [ ] **Step 3: Write the entities**

Create `lib/features/flight/domain/entities/flight_offer_filters.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'flight_offer_filters.freezed.dart';

/// Filters applied on-device to an already-fetched offer list. Controls that
/// require a fresh search (sort, cabin class, direct-only) live on
/// `FlightSearchParams`, not here.
@freezed
abstract class FlightOfferFilters with _$FlightOfferFilters {
  const FlightOfferFilters._();

  const factory FlightOfferFilters({
    @Default(<String>{}) Set<String> carrierCodes,
    double? minPrice,
    double? maxPrice,
    @Default(false) bool refundableOnly,
  }) = _FlightOfferFilters;

  bool get isEmpty =>
      carrierCodes.isEmpty &&
      minPrice == null &&
      maxPrice == null &&
      !refundableOnly;

  /// Number of active constraints, for the filter button's badge.
  int get activeCount =>
      carrierCodes.length +
      (minPrice != null || maxPrice != null ? 1 : 0) +
      (refundableOnly ? 1 : 0);
}

/// A carrier the rider can filter by, derived from the current offers.
@freezed
abstract class FlightCarrierOption with _$FlightCarrierOption {
  const factory FlightCarrierOption({
    required String code,
    String? name,
    String? logoUrl,
    required int offerCount,
  }) = _FlightCarrierOption;
}
```

- [ ] **Step 4: Write the utils**

Create `lib/features/flight/domain/utils/apply_flight_offer_filters.dart`:

```dart
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer_filters.dart';

/// Refundability values that count as refundable. `UnKnown` is deliberately
/// excluded — showing it under a "refundable only" filter promises something
/// the provider has not confirmed.
const _refundableValues = {'FullyRefundable', 'PartiallyRefundable'};

Set<String> _carrierCodesOf(FlightOffer offer) => offer.journeys
    .expand((journey) => journey.segments)
    .map((segment) => segment.operatingCarrierCode)
    .toSet();

/// Distinct operating carriers across [offers], most offers first. Name and
/// logo come from the first segment that carries them — older responses omit
/// both, so either may be null.
List<FlightCarrierOption> flightCarrierOptions(List<FlightOffer> offers) {
  final counts = <String, int>{};
  final names = <String, String>{};
  final logos = <String, String>{};

  for (final offer in offers) {
    for (final code in _carrierCodesOf(offer)) {
      counts[code] = (counts[code] ?? 0) + 1;
    }
    for (final segment in offer.journeys.expand((j) => j.segments)) {
      final name = segment.operatingCarrierName;
      if (name != null) names.putIfAbsent(segment.operatingCarrierCode, () => name);
      final logo = segment.operatingCarrierLogo;
      if (logo != null) logos.putIfAbsent(segment.operatingCarrierCode, () => logo);
    }
  }

  final options = counts.entries
      .map(
        (entry) => FlightCarrierOption(
          code: entry.key,
          name: names[entry.key],
          logoUrl: logos[entry.key],
          offerCount: entry.value,
        ),
      )
      .toList();

  options.sort((a, b) {
    final byCount = b.offerCount.compareTo(a.offerCount);
    return byCount != 0 ? byCount : a.code.compareTo(b.code);
  });
  return options;
}

/// Cheapest and dearest total across [offers]. Returns `(0, 0)` when empty.
(double min, double max) flightPriceBounds(List<FlightOffer> offers) {
  if (offers.isEmpty) return (0, 0);
  var min = offers.first.totalAmount;
  var max = min;
  for (final offer in offers.skip(1)) {
    if (offer.totalAmount < min) min = offer.totalAmount;
    if (offer.totalAmount > max) max = offer.totalAmount;
  }
  return (min, max);
}

List<FlightOffer> applyFlightOfferFilters(
  List<FlightOffer> offers,
  FlightOfferFilters filters,
) {
  if (filters.isEmpty) return offers;
  return offers.where((offer) {
    if (filters.refundableOnly &&
        !_refundableValues.contains(offer.refundability)) {
      return false;
    }
    final min = filters.minPrice;
    if (min != null && offer.totalAmount < min) return false;
    final max = filters.maxPrice;
    if (max != null && offer.totalAmount > max) return false;
    if (filters.carrierCodes.isNotEmpty &&
        _carrierCodesOf(offer).intersection(filters.carrierCodes).isEmpty) {
      return false;
    }
    return true;
  }).toList();
}

/// Re-points [filters] at a fresh [offers] list after a server-side control
/// changed and the search re-ran.
///
/// Carriers the rider chose that no longer appear are dropped silently. A
/// price range they never touched (both bounds null) stays untouched so it
/// re-derives from the new bounds; one they did touch is clamped rather than
/// discarded, so their intent survives.
FlightOfferFilters preserveFlightFilters({
  required FlightOfferFilters filters,
  required List<FlightOffer> offers,
}) {
  final available = offers.expand(_carrierCodesOf).toSet();
  final (low, high) = flightPriceBounds(offers);
  return filters.copyWith(
    carrierCodes: filters.carrierCodes.intersection(available),
    minPrice: filters.minPrice?.clamp(low, high).toDouble(),
    maxPrice: filters.maxPrice?.clamp(low, high).toDouble(),
  );
}
```

- [ ] **Step 5: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `Succeeded after ...`

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/flight/domain/apply_flight_offer_filters_test.dart`
Expected: PASS — 9 tests.

- [ ] **Step 7: Commit**

```bash
git add lib/features/flight/domain/entities/flight_offer_filters.dart lib/features/flight/domain/utils/apply_flight_offer_filters.dart test/features/flight/domain/apply_flight_offer_filters_test.dart
git commit -m "Add Local Flight Offer Filtering And Preservation"
```

---

## Task 9: Notifier holds filters and preserves them

**Files:**
- Modify: `lib/features/flight/presentation/providers/flight_booking_providers.dart`

- [ ] **Step 1: Extend the state**

Add to `FlightBookingState`:

```dart
    @Default(FlightOfferFilters()) FlightOfferFilters filters,
```

Add the imports:

```dart
import 'package:safaria/features/flight/domain/entities/flight_offer_filters.dart';
import 'package:safaria/features/flight/domain/utils/apply_flight_offer_filters.dart';
```

- [ ] **Step 2: Preserve filters when re-searching**

Replace `FlightBookingNotifier.search` with:

```dart
  /// Runs a server-side search. [preserveFilters] is true when the rider
  /// changed a server-backed control from the filter sheet — their local
  /// filters carry over onto the new results. A brand-new search from the
  /// form clears them.
  Future<void> search(
    FlightSearchParams params, {
    bool preserveFilters = false,
  }) async {
    state = state.copyWith(
      status: FlightBookingStatus.searching,
      searchParams: params,
      error: null,
      offers: [],
      filters: preserveFilters ? state.filters : const FlightOfferFilters(),
    );
    try {
      final offers = await _repo.search(params);
      state = state.copyWith(
        status: FlightBookingStatus.idle,
        offers: offers,
        filters: preserveFilters
            ? preserveFlightFilters(filters: state.filters, offers: offers)
            : const FlightOfferFilters(),
      );
    } catch (e) {
      state = state.copyWith(
        status: FlightBookingStatus.error,
        error: e.toString(),
      );
    }
  }

  void setFilters(FlightOfferFilters filters) {
    state = state.copyWith(filters: filters);
  }
```

- [ ] **Step 3: Expose the filtered list**

Append to the same file:

```dart
/// Offers after local filtering. The results list watches this; the filter
/// sheet derives its options from the unfiltered `offers`.
final flightFilteredOffersProvider = Provider<List<FlightOffer>>((ref) {
  final state = ref.watch(flightBookingProvider);
  return applyFlightOfferFilters(state.offers, state.filters);
});
```

- [ ] **Step 4: Regenerate and analyze**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter analyze lib/features/flight`
Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/flight/presentation/providers/flight_booking_providers.dart
git commit -m "Hold Flight Filters In The Booking Notifier"
```

---

## Task 10: The unified filter sheet

**Files:**
- Create: `lib/features/flight/presentation/widgets/flight_filter_sheet.dart`
- Create: `lib/features/flight/presentation/widgets/flight_filter_button.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`
- Test: `test/features/flight/presentation/flight_filter_sheet_test.dart`

- [ ] **Step 1: Add the strings**

In `lib/l10n/app_en.arb`:

```json
  "flightFilterTitle": "Filter and sort",
  "flightFilterServerGroup": "Sort and class",
  "flightFilterServerBadge": "new search",
  "flightFilterLocalGroup": "Refine",
  "flightFilterLocalBadge": "instant",
  "flightFilterDirectOnly": "Direct flights only",
  "flightFilterRefundableOnly": "Refundable only",
  "flightFilterPrice": "Price",
  "flightFilterAirlines": "Airlines",
  "flightFilterShow": "Show {count} flights",
  "flightFilterNoMatches": "No flights match your filters",
  "flightFilterClear": "Clear filters",
  "flightSortCheapest": "Cheapest",
  "flightSortFastest": "Fastest",
  "flightSortEarliest": "Earliest",
  "@flightFilterShow": {
    "placeholders": { "count": {"type": "int"} }
  },
```

In `lib/l10n/app_ar.arb`:

```json
  "flightFilterTitle": "الفلاتر والترتيب",
  "flightFilterServerGroup": "الترتيب والدرجة",
  "flightFilterServerBadge": "بحث جديد",
  "flightFilterLocalGroup": "تصفية",
  "flightFilterLocalBadge": "من غير تحميل",
  "flightFilterDirectOnly": "مباشرة بس",
  "flightFilterRefundableOnly": "قابلة للاسترداد بس",
  "flightFilterPrice": "السعر",
  "flightFilterAirlines": "شركات الطيران",
  "flightFilterShow": "عرض {count} رحلة",
  "flightFilterNoMatches": "مفيش رحلات مطابقة للفلاتر",
  "flightFilterClear": "امسح الفلاتر",
  "flightSortCheapest": "الأرخص",
  "flightSortFastest": "الأسرع",
  "flightSortEarliest": "الأبكر",
```

- [ ] **Step 2: Write the failing test**

Create `test/features/flight/presentation/flight_filter_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer_filters.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_filter_sheet.dart';
import 'package:safaria/l10n/app_localizations.dart';

const _carriers = [
  FlightCarrierOption(code: 'NE', name: 'Nile Air', offerCount: 2),
  FlightCarrierOption(code: 'MS', name: 'EgyptAir', offerCount: 1),
];

void main() {
  testWidgets('counts matches live as filters change', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FlightFilterSheet(
            initial: const FlightOfferFilters(),
            carriers: _carriers,
            priceBounds: const (3000.0, 9000.0),
            matchCount: (filters) => filters.refundableOnly ? 1 : 3,
            onApply: (_, {required bool directOnly, required bool needsSearch}) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Show 3 flights'), findsOneWidget);

    await tester.tap(find.byKey(const Key('flight-filter-refundable')));
    await tester.pump();

    expect(find.text('Show 1 flights'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/flight/presentation/flight_filter_sheet_test.dart`
Expected: FAIL — `FlightFilterSheet` is not defined.

- [ ] **Step 4: Write the sheet**

Create `lib/features/flight/presentation/widgets/flight_filter_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer_filters.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Called when the rider applies. [directOnly] is the server-backed value as
/// the rider left it, and [needsSearch] is true when it changed — telling the
/// caller to re-run the search and preserve these local filters onto the new
/// results.
typedef FlightFilterApply = void Function(
  FlightOfferFilters filters, {
  required bool directOnly,
  required bool needsSearch,
});

/// One sheet holding both filter groups. Each group is badged with what it
/// costs — without that, the rider cannot tell which control throws the list
/// away and which is instant.
class FlightFilterSheet extends StatefulWidget {
  const FlightFilterSheet({
    super.key,
    required this.initial,
    required this.carriers,
    required this.priceBounds,
    required this.matchCount,
    required this.onApply,
    this.initialDirectOnly = false,
  });

  final FlightOfferFilters initial;
  final List<FlightCarrierOption> carriers;
  final (double min, double max) priceBounds;
  final int Function(FlightOfferFilters) matchCount;
  final FlightFilterApply onApply;
  final bool initialDirectOnly;

  @override
  State<FlightFilterSheet> createState() => _FlightFilterSheetState();
}

class _FlightFilterSheetState extends State<FlightFilterSheet> {
  late FlightOfferFilters _filters = widget.initial;
  late bool _directOnly = widget.initialDirectOnly;

  bool get _needsSearch => _directOnly != widget.initialDirectOnly;

  void _toggleCarrier(String code) {
    final next = Set<String>.from(_filters.carrierCodes);
    if (!next.remove(code)) next.add(code);
    setState(() => _filters = _filters.copyWith(carrierCodes: next));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (low, high) = widget.priceBounds;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GroupHeader(
              title: l10n.flightFilterServerGroup,
              badge: l10n.flightFilterServerBadge,
              badgeColor: AppColors.secondary,
              badgeBackground: AppColors.secondaryTint,
            ),
            SwitchListTile(
              key: const Key('flight-filter-direct'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.flightFilterDirectOnly,
                style: AppTypography.body,
              ),
              value: _directOnly,
              onChanged: (value) => setState(() => _directOnly = value),
            ),
            const Divider(height: AppSpacing.lg),
            _GroupHeader(
              title: l10n.flightFilterLocalGroup,
              badge: l10n.flightFilterLocalBadge,
              badgeColor: AppColors.success,
              badgeBackground: AppColors.success.withValues(alpha: 0.12),
            ),
            if (high > low) ...[
              Text(
                l10n.flightFilterPrice,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              RangeSlider(
                min: low,
                max: high,
                values: RangeValues(
                  _filters.minPrice ?? low,
                  _filters.maxPrice ?? high,
                ),
                labels: RangeLabels(
                  (_filters.minPrice ?? low).round().toString(),
                  (_filters.maxPrice ?? high).round().toString(),
                ),
                onChanged: (values) => setState(
                  () => _filters = _filters.copyWith(
                    minPrice: values.start,
                    maxPrice: values.end,
                  ),
                ),
              ),
            ],
            SwitchListTile(
              key: const Key('flight-filter-refundable'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.flightFilterRefundableOnly,
                style: AppTypography.body,
              ),
              value: _filters.refundableOnly,
              onChanged: (value) => setState(
                () => _filters = _filters.copyWith(refundableOnly: value),
              ),
            ),
            if (widget.carriers.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.flightFilterAirlines,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              for (final carrier in widget.carriers)
                CheckboxListTile(
                  key: Key('flight-filter-carrier-${carrier.code}'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _filters.carrierCodes.contains(carrier.code),
                  onChanged: (_) => _toggleCarrier(carrier.code),
                  title: Text(
                    carrier.name ?? carrier.code,
                    style: AppTypography.body,
                  ),
                  secondary: Text(
                    '${carrier.offerCount}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: l10n.flightFilterShow(widget.matchCount(_filters)),
              onPressed: () => widget.onApply(
                _filters,
                directOnly: _directOnly,
                needsSearch: _needsSearch,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.badge,
    required this.badgeColor,
    required this.badgeBackground,
  });

  final String title;
  final String badge;
  final Color badgeColor;
  final Color badgeBackground;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(title, style: AppTypography.body),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: badgeBackground,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              badge,
              style: AppTypography.caption.copyWith(color: badgeColor),
            ),
          ),
        ],
      ),
    );
  }
}
```

`AppColors` has `success` and `secondaryTint` but no `successTint`, which is why the green badge tints `success` inline rather than using a named constant.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter gen-l10n && flutter test test/features/flight/presentation/flight_filter_sheet_test.dart`
Expected: PASS — 1 test.

- [ ] **Step 6: Write the filter button**

Create `lib/features/flight/presentation/widgets/flight_filter_button.dart`, modelled on `lib/features/bus/presentation/widgets/trip_filter_button.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_typography.dart';

/// App-bar entry to the filter sheet, badged with the active constraint count.
class FlightFilterButton extends StatelessWidget {
  const FlightFilterButton({
    super.key,
    required this.activeCount,
    required this.onTap,
  });

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(PhosphorIconsLight.slidersHorizontal),
          if (activeCount > 0)
            PositionedDirectional(
              top: -4,
              end: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$activeCount',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.bgElevated,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Commit**

```bash
git add lib/features/flight/presentation/widgets/flight_filter_sheet.dart lib/features/flight/presentation/widgets/flight_filter_button.dart lib/l10n/app_en.arb lib/l10n/app_ar.arb test/features/flight/presentation/flight_filter_sheet_test.dart
git commit -m "Add Unified Flight Filter Sheet"
```

---

## Task 11: Results screen and multi-journey card

**Files:**
- Modify: `lib/features/flight/presentation/flight_results_screen.dart`
- Modify: `lib/features/flight/presentation/widgets/flight_offer_card.dart`

- [ ] **Step 1: Add the leg label strings**

In `lib/l10n/app_en.arb`:

```json
  "flightLegOutbound": "Outbound",
  "flightLegReturn": "Return",
```

In `lib/l10n/app_ar.arb`:

```json
  "flightLegOutbound": "الذهاب",
  "flightLegReturn": "العودة",
```

- [ ] **Step 2: Extract the journey block from the offer card**

`FlightOfferCard.build` currently reads `offer.journeys.first` at line 58 and renders that one journey. Move that rendering into a private widget so it can repeat.

In `lib/features/flight/presentation/widgets/flight_offer_card.dart`, add at the bottom of the file:

```dart
/// One leg of an offer: its route row, duration and stops. Repeated per
/// journey — an offer is priced as a whole trip, so all of its legs belong on
/// the same card.
class _JourneyBlock extends StatelessWidget {
  const _JourneyBlock({
    required this.journey,
    required this.label,
    this.originLabel,
    this.destinationLabel,
  });

  final FlightJourney journey;

  /// Null for a single-leg offer, where a label would be noise.
  final String? label;
  final String? originLabel;
  final String? destinationLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final totalMinutes =
        journey.segments.fold<int>(0, (sum, s) => sum + s.flightTimeInMinutes);
    final stopsLabel = journey.numberOfStops == 0
        ? l10n.flightDirect
        : journey.numberOfStops == 1
            ? l10n.flightOneStop
            : l10n.flightStopsCount(journey.numberOfStops);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              label!,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        // Move the existing route row here verbatim — the widget subtree that
        // used `firstSegment`, `lastSegment`, `totalMinutes` and `stopsLabel`
        // from the old `build`. Those four locals are now defined above, and
        // `firstSegment` / `lastSegment` become:
        //   journey.segments.first / journey.segments.last
      ],
    );
  }
}
```

Then in `build`, delete the `journey`, `firstSegment`, `lastSegment`, `totalMinutes` and `stopsLabel` locals (lines 58–67) and replace the journey portion of the `Column` with:

```dart
            for (var i = 0; i < offer.journeys.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              _JourneyBlock(
                journey: offer.journeys[i],
                label: _legLabel(l10n, i, offer.journeys.length),
                originLabel: i == 0 ? originLabel : null,
                destinationLabel: i == 0 ? destinationLabel : null,
              ),
            ],
```

Add the label helper as a static on `FlightOfferCard`:

```dart
  /// Single-leg offers get no label. Two legs read as outbound and return;
  /// more than two is a multi-city itinerary, so legs are simply numbered.
  static String? _legLabel(AppLocalizations l10n, int index, int total) {
    if (total < 2) return null;
    if (total == 2) {
      return index == 0 ? l10n.flightLegOutbound : l10n.flightLegReturn;
    }
    return l10n.flightLegLabel(index + 1);
  }
```

The price stub below the tear line stays where it is — it prices the whole offer, not a leg.

- [ ] **Step 3: Convert the results screen to stateful**

`lib/features/flight/presentation/flight_results_screen.dart` currently declares `class FlightResultsScreen extends ConsumerWidget` with a `build(BuildContext, WidgetRef)`. The lazy window needs local state, so change the declaration to:

```dart
class FlightResultsScreen extends ConsumerStatefulWidget {
  const FlightResultsScreen({super.key});

  @override
  ConsumerState<FlightResultsScreen> createState() =>
      _FlightResultsScreenState();
}

class _FlightResultsScreenState extends ConsumerState<FlightResultsScreen> {
  /// Offers rendered per batch. The search endpoint returns 600+ results with
  /// no server paging, so the window is entirely ours.
  static const _pageSize = 20;
  int _visible = _pageSize;
```

Move the existing `build` body into this state class and drop its `WidgetRef ref` parameter — `ref` is available on `ConsumerState`. Any private list-building method the old class had moves with it.

- [ ] **Step 4: Watch both providers and reset the window on new results**

At the top of `build`:

```dart
    final state = ref.watch(flightBookingProvider);
    final offers = ref.watch(flightFilteredOffersProvider);

    // A fresh result set restarts the window; without this, a re-search
    // inherits the previous scroll depth and renders far more than needed.
    ref.listen(
      flightBookingProvider.select((s) => s.offers),
      (_, __) => setState(() => _visible = _pageSize),
    );
```

Add the app-bar action:

```dart
      appBar: BookingAppBar(
        title: title,
        action: FlightFilterButton(
          activeCount: state.filters.activeCount,
          onTap: _openFilters,
        ),
      ),
```

- [ ] **Step 5: Open the sheet and route the result**

Add as a method on `_FlightResultsScreenState`:

```dart
  Future<void> _openFilters() async {
    final state = ref.read(flightBookingProvider);
    final params = state.searchParams;
    if (params == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgElevated,
      builder: (sheetContext) => FlightFilterSheet(
        initial: state.filters,
        carriers: flightCarrierOptions(state.offers),
        priceBounds: flightPriceBounds(state.offers),
        initialDirectOnly: params.directFlightsOnly,
        matchCount: (filters) =>
            applyFlightOfferFilters(state.offers, filters).length,
        onApply: (filters, {required directOnly, required needsSearch}) {
          Navigator.of(sheetContext).pop();
          final notifier = ref.read(flightBookingProvider.notifier);
          notifier.setFilters(filters);
          if (needsSearch) {
            notifier.search(
              params.copyWith(directFlightsOnly: directOnly),
              preserveFilters: true,
            );
          }
        },
      ),
    );
  }
```

- [ ] **Step 6: Render the list lazily and handle the filtered-empty case**

Replace the `ListView.separated` block (currently at lines 62–81) with:

```dart
    if (offers.isEmpty && state.offers.isNotEmpty) {
      return _FilteredEmptyView(
        onClear: () => ref
            .read(flightBookingProvider.notifier)
            .setFilters(const FlightOfferFilters()),
      );
    }

    final windowed = offers.length < _visible ? offers.length : _visible;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 400 &&
            _visible < offers.length) {
          setState(() => _visible += _pageSize);
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        itemCount: windowed,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          final offer = offers[i];
          return FlightOfferCard(
            key: ValueKey(offer.offerId),
            offer: offer,
            originLabel: state.searchFromLabel,
            destinationLabel: state.searchToLabel,
            onTap: () => context.push(FlightRoutes.offerDetails, extra: offer),
          );
        },
      ),
    );
```

Note the existing `state.offers.isEmpty` branch above it stays — that is the "search returned nothing" case, which is different from "filters hid everything".

Add the empty view at the bottom of the file:

```dart
/// Shown when local filters exclude every offer. The action is to clear the
/// filters, not to search again — the results are still there, we are hiding
/// them.
class _FilteredEmptyView extends StatelessWidget {
  const _FilteredEmptyView({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              PhosphorIconsLight.funnelX,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.flightFilterNoMatches,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: l10n.flightFilterClear,
              variant: PrimaryButtonVariant.ghost,
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }
}
```

If `PhosphorIconsLight.funnelX` is unavailable in the pinned package version, use `PhosphorIconsLight.funnel`.

- [ ] **Step 7: Verify the whole suite and the app**

Run: `flutter gen-l10n && flutter analyze && flutter test`
Expected: no analyzer issues; all tests pass.

Run: `flutter run`. Search Cairo to Riyadh, open the filter sheet, deselect a carrier, confirm the count updates before applying and the list shrinks after. Toggle direct-only and confirm the list reloads with the carrier selection still applied.

- [ ] **Step 8: Commit**

```bash
git add lib/features/flight/presentation lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "Filter And Paginate Flight Results"
```

---

## Done when

- [ ] `flutter analyze` is clean
- [ ] `flutter test` passes, including the four new test files
- [ ] All three trip types produce results against the live demo backend
- [ ] Changing direct-only in the sheet re-searches and keeps carrier selections
- [ ] A 600-offer result set scrolls without jank on a low-end device
