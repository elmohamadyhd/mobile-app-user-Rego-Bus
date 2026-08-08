# Flight Passenger Entry Implementation Plan (Phase 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a rider enter every traveller on the booking, with as little typing as the contract allows.

**Architecture:** A list of passenger rows, each opening its own full screen — nine stacked forms would be unusable, and the list doubles as a progress view that names what is still missing. Contact details are captured once and written onto every traveller. Everything that decides *whether a passenger is valid* is a pure function over a draft, so the rules are tested without a widget in sight. Saved travellers are identity data and live in secure storage with a way for the rider to delete them.

**Tech Stack:** Flutter, Riverpod (`Notifier`), Freezed + json_serializable, `flutter_secure_storage`, Dio, go_router, ARB codegen.

**Scope:** Phase 3 of [`2026-08-08-flight-booking-screens-design.md`](../specs/2026-08-08-flight-booking-screens-design.md). Ends when a rider can fill in every traveller and the API accepts them. Order creation and payment are Phase 4.

**Depends on:** Phase 2, merged — commits `6f45d44` through `6af979e`.

---

## Task 1 gates this plan

Open question 3 in the flow spec is still open: the two passenger country fields take **`iso3`** (`"EGY"`) or **`iso2`** (`"EG"`). The spec's answer is inferred from a sample that reads `"EGP"` — one letter from Egypt's `iso3` `"EGY"` — not from anything the backend stated.

Every booking passes through this field. If the provider validates it and we send the wrong width, **no booking ever completes**, and the failure surfaces as an opaque validation error at the last step before payment.

Task 1 settles it with one real call, exactly as Phase 2's spike settled the offer id relay. Tasks 2–12 all assume the answer, so run it first.

---

## File Structure

**Create:**

| File | Responsibility |
|------|----------------|
| `lib/features/flight/domain/entities/flight_country.dart` | A country with both ISO widths and a dial code |
| `lib/features/flight/domain/entities/flight_passenger_draft.dart` | One traveller as entered, plus contact details |
| `lib/features/flight/domain/utils/flight_passenger_validation.dart` | Completeness, age classification, type mismatch — pure |
| `lib/features/flight/domain/utils/flight_passenger_errors.dart` | Maps API error keys back to their passenger — pure |
| `lib/features/flight/data/flight_saved_travellers_store.dart` | Secure-storage round trip for saved travellers |
| `lib/features/flight/presentation/flight_passengers_screen.dart` | Step 3: contact details and the passenger list |
| `lib/features/flight/presentation/flight_passenger_form_screen.dart` | One traveller, full screen |
| `lib/features/flight/presentation/widgets/flight_country_field.dart` | Country picker backed by `GET /countries` |
| `lib/features/flight/presentation/widgets/flight_passenger_row.dart` | One list row with its completion state |
| `lib/features/profile/presentation/saved_travellers_screen.dart` | View and delete saved travellers |

**Modify:**

| File | Change |
|------|--------|
| `lib/core/storage/secure_storage.dart` | A key for saved travellers |
| `lib/features/flight/data/flight_dto_mapper.dart` | Countries in, passengers out |
| `lib/features/flight/data/flight_repository_impl.dart` | `countries` and `addPassengers` |
| `lib/features/flight/domain/repositories/flight_repository.dart` | Both new methods |
| `lib/features/flight/presentation/providers/flight_booking_providers.dart` | Drafts, contact, offer id C |
| `lib/features/flight/presentation/flight_routes.dart` | Two new routes |
| `lib/features/flight/presentation/flight_review_screen.dart` | Continue reaches passengers |
| `lib/features/flight/presentation/flight_bundles_screen.dart` | Continue reaches passengers |
| `lib/features/profile/presentation/profile_screen.dart`, `profile_routes.dart` | Saved-travellers entry |
| `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` | New strings |

---

## Task 1: Settle iso3 vs iso2 against the live backend

A spike. It produces a one-line answer that Tasks 4 and 8 depend on.

- [ ] **Step 1: Get to a confirmed offer**

Repeat Task 1 of the Phase 2 plan through confirm, so you hold offer id **B**. A one-way, one-adult search is enough.

- [ ] **Step 2: Send one passenger with `iso3`**

```bash
curl -s -X POST "https://demo.safaria.travel/api/v1/flights/$(python -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" 'PASTE_OFFER_ID_B')/passengers" \
  -H "Accept: application/json" -H "Content-Type: application/json" \
  -H "Accept-Language: en" -H "Authorization: Bearer PASTE_TOKEN" \
  -d '{"passengers":[{"title":"MR","firstName":"Ahmed","middleName":"","lastName":"Mostafa","birthDate":"1990-01-02","documentNumber":"29906091231234","nationalityCountryCode":"EGY","residenceCountryCode":"EGY","gender":"M","email":"test@example.com","phone":"01090510796","passengerTypeCode":"ADT"}]}'
```

- [ ] **Step 3: Read the outcome**

- **`200` with `data.offerId`** — `iso3` is correct. Record that the returned id is **offer id C** and differs from B. Go to step 5.
- **A validation error naming `nationalityCountryCode` or `residenceCountryCode`** — go to step 4.
- **`200` regardless of what you send** (repeat with garbage like `"ZZZ"` to check) — the provider does not validate this field. Record that, pick `iso3`, and note it is unverified rather than confirmed.

- [ ] **Step 4: Retry with `iso2`**

Re-run step 2 with `"EG"` in both fields, against a **fresh** offer id B — the previous one may have been consumed. If this succeeds where `iso3` failed, `iso2` is the answer.

- [ ] **Step 5: Record the answer**

In `docs/superpowers/specs/2026-08-08-flight-booking-flow-design.md`, move item 3 out of "Still open" into the resolved table, stating which width worked and whether the field is validated at all.

Also record whether the response's `offerId` differed from B. Phase 4 sends **that** id when creating the order, so the relay gains a third hop.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/specs/2026-08-08-flight-booking-flow-design.md
git commit -m "Settle Passenger Country Code Width"
```

Throughout the rest of this plan, **`kPassengerCountryCodeWidth`** means whichever width Task 1 proved. Task 2 defines it as a single constant so a wrong answer is a one-line change.

---

## Task 2: Countries

**Files:**
- Create: `lib/features/flight/domain/entities/flight_country.dart`
- Modify: `lib/features/flight/data/flight_dto_mapper.dart`, `flight_repository_impl.dart`, `flight_repository.dart`, `flight_api.dart`
- Test: `test/features/flight/data/flight_country_mapper_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/data/flight_dto_mapper.dart';
import 'package:safaria/features/flight/domain/entities/flight_country.dart';

const _envelope = {
  'status': 200,
  'message': 'Countries',
  'errors': <String, dynamic>{},
  'data': [
    {'name': 'Egypt', 'iso2': 'EG', 'iso3': 'EGY', 'phonecode': '20'},
    {'name': 'Saudi Arabia', 'iso2': 'SA', 'iso3': 'SAU', 'phonecode': '966'},
  ],
};

void main() {
  test('maps every country with both ISO widths', () {
    final countries = FlightDtoMapper.countriesFromEnvelope(_envelope);
    expect(countries, hasLength(2));
    expect(countries.first.name, 'Egypt');
    expect(countries.first.iso2, 'EG');
    expect(countries.first.iso3, 'EGY');
    expect(countries.first.phoneCode, '20');
  });

  test('passengerCode returns the width the provider accepts', () {
    const egypt =
        FlightCountry(name: 'Egypt', iso2: 'EG', iso3: 'EGY', phoneCode: '20');
    expect(egypt.passengerCode, kPassengerCountryCodeWidth);
  });

  test('a malformed row is skipped rather than crashing the list', () {
    final countries = FlightDtoMapper.countriesFromEnvelope({
      'data': [
        {'name': 'Egypt', 'iso2': 'EG', 'iso3': 'EGY', 'phonecode': '20'},
        {'iso2': null},
      ],
    });
    expect(countries, hasLength(1));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight/data/flight_country_mapper_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Write the entity**

Create `lib/features/flight/domain/entities/flight_country.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'flight_country.freezed.dart';

/// Which ISO width the passenger endpoint accepts for
/// `nationalityCountryCode` and `residenceCountryCode`.
///
/// Settled by the live spike in Phase 3 Task 1. If that answer ever turns out
/// wrong, this constant and [FlightCountry.passengerCode] are the only places
/// that need to change.
const kPassengerCountryCodeWidth = FlightCountryCodeWidth.iso3;

enum FlightCountryCodeWidth { iso2, iso3 }

/// A country from `GET /countries`. Carries both ISO widths because the app
/// needs each in a different place: the passenger fields take one width, and
/// `address.countryCode` takes `iso2`.
@freezed
abstract class FlightCountry with _$FlightCountry {
  const FlightCountry._();

  const factory FlightCountry({
    required String name,
    required String iso2,
    required String iso3,
    required String phoneCode,
  }) = _FlightCountry;

  /// The value to send in the passenger body.
  String get passengerCode => switch (kPassengerCountryCodeWidth) {
        FlightCountryCodeWidth.iso2 => iso2,
        FlightCountryCodeWidth.iso3 => iso3,
      };
}
```

If Task 1 proved `iso2`, change the constant here — nothing else moves.

- [ ] **Step 4: Write the mapper and the call**

Add to `lib/features/flight/data/flight_dto_mapper.dart`:

```dart
  static List<FlightCountry> countriesFromEnvelope(dynamic body) {
    final data = body is Map ? body['data'] : null;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(_countryFromJson)
        .whereType<FlightCountry>()
        .toList(growable: false);
  }

  /// Rows missing a name or either ISO code are unusable in a picker, so they
  /// are dropped rather than rendered as blanks.
  static FlightCountry? _countryFromJson(Map json) {
    final name = _string(json['name']);
    final iso2 = _string(json['iso2']);
    final iso3 = _string(json['iso3']);
    if (name == null || iso2 == null || iso3 == null) return null;
    return FlightCountry(
      name: name,
      iso2: iso2,
      iso3: iso3,
      phoneCode: _string(json['phonecode']) ?? '',
    );
  }
```

Add to `lib/features/flight/data/flight_api.dart`:

```dart
  /// `GET /countries` — the source for nationality, residence, and dial codes.
  Future<dynamic> countries() async {
    final res = await _dio.get('/countries');
    return res.data;
  }
```

Add to the repository interface and implementation:

```dart
  Future<List<FlightCountry>> countries();
```

```dart
  @override
  Future<List<FlightCountry>> countries() {
    return _guard(() async {
      final body = await _api.countries();
      return FlightDtoMapper.countriesFromEnvelope(body);
    });
  }
```

- [ ] **Step 5: Add a cached provider**

In `lib/features/flight/presentation/providers/flight_booking_providers.dart`:

```dart
/// The country list is static for a session — fetch once and reuse across
/// every passenger form.
final flightCountriesProvider = FutureProvider<List<FlightCountry>>((ref) {
  return ref.watch(flightRepositoryProvider).countries();
});
```

- [ ] **Step 6: Run codegen and the test**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/features/flight/data/flight_country_mapper_test.dart`
Expected: PASS — 3 tests.

- [ ] **Step 7: Commit**

```bash
git add lib/features/flight lib/core test/features/flight/data/flight_country_mapper_test.dart
git commit -m "Fetch Countries For Passenger Fields"
```

---

## Task 3: Passenger drafts and validation

**Files:**
- Create: `lib/features/flight/domain/entities/flight_passenger_draft.dart`
- Create: `lib/features/flight/domain/utils/flight_passenger_validation.dart`
- Test: `test/features/flight/domain/flight_passenger_validation_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_validation.dart';

final _departure = DateTime(2026, 8, 30);

FlightPassengerDraft _adult({
  String? documentNumber = '29001021234567',
  DateTime? birthDate,
}) {
  return FlightPassengerDraft(
    type: FlightPassengerType.adult,
    title: 'MR',
    firstName: 'Ahmed',
    lastName: 'Mostafa',
    gender: 'M',
    birthDate: birthDate ?? DateTime(1990, 1, 2),
    documentNumber: documentNumber,
    nationalityCode: 'EGY',
    residenceCode: 'EGY',
  );
}

void main() {
  group('age classification', () {
    test('exactly 12 at departure is an adult', () {
      expect(
        classifyFlightPassenger(
          birthDate: DateTime(2014, 8, 30),
          departureDate: _departure,
        ),
        FlightPassengerType.adult,
      );
    });

    test('turning 12 the day after departure is still a child', () {
      expect(
        classifyFlightPassenger(
          birthDate: DateTime(2014, 8, 31),
          departureDate: _departure,
        ),
        FlightPassengerType.child,
      );
    });

    test('exactly 2 at departure is a child', () {
      expect(
        classifyFlightPassenger(
          birthDate: DateTime(2024, 8, 30),
          departureDate: _departure,
        ),
        FlightPassengerType.child,
      );
    });

    test('under 2 at departure is an infant', () {
      expect(
        classifyFlightPassenger(
          birthDate: DateTime(2024, 8, 31),
          departureDate: _departure,
        ),
        FlightPassengerType.infant,
      );
    });
  });

  group('completeness', () {
    test('a fully filled adult is missing nothing', () {
      expect(missingFlightPassengerFields(_adult()), isEmpty);
      expect(isFlightPassengerComplete(_adult()), isTrue);
    });

    test('a blank document number is reported missing', () {
      expect(
        missingFlightPassengerFields(_adult(documentNumber: null)),
        contains(FlightPassengerField.documentNumber),
      );
    });

    test('whitespace does not count as filled', () {
      expect(
        missingFlightPassengerFields(_adult(documentNumber: '   ')),
        contains(FlightPassengerField.documentNumber),
      );
    });

    test('a middle name is optional', () {
      final draft = _adult().copyWith(middleName: null);
      expect(missingFlightPassengerFields(draft), isEmpty);
    });
  });

  group('type mismatch', () {
    test('a birth date matching the booked type reports no mismatch', () {
      expect(
        flightPassengerTypeMismatch(_adult(), departureDate: _departure),
        isNull,
      );
    });

    test('an adult slot holding a child birth date reports the real type', () {
      final draft = _adult(birthDate: DateTime(2018, 5, 1));
      expect(
        flightPassengerTypeMismatch(draft, departureDate: _departure),
        FlightPassengerType.child,
      );
    });

    test('a draft with no birth date yet reports no mismatch', () {
      final draft = _adult().copyWith(birthDate: null);
      expect(
        flightPassengerTypeMismatch(draft, departureDate: _departure),
        isNull,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight/domain/flight_passenger_validation_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Write the draft entity**

Create `lib/features/flight/domain/entities/flight_passenger_draft.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';

part 'flight_passenger_draft.freezed.dart';
part 'flight_passenger_draft.g.dart';

/// Contact details for the whole booking. The API takes an email and phone
/// per traveller, but in practice these are the booker's — collected once and
/// written onto every passenger at submit.
@freezed
abstract class FlightContactDetails with _$FlightContactDetails {
  const factory FlightContactDetails({
    @Default('') String email,
    @Default('') String phone,
  }) = _FlightContactDetails;
}

/// One traveller as the rider has filled them in so far. Every field is
/// nullable because a draft is valid at any stage of completion — the list
/// screen renders progress from exactly this.
///
/// [savedId] is set only for travellers persisted to secure storage.
@freezed
abstract class FlightPassengerDraft with _$FlightPassengerDraft {
  const factory FlightPassengerDraft({
    required FlightPassengerType type,
    String? savedId,
    String? title,
    String? firstName,
    String? middleName,
    String? lastName,
    DateTime? birthDate,
    String? documentNumber,
    String? nationalityCode,
    String? residenceCode,
    String? gender,
  }) = _FlightPassengerDraft;

  factory FlightPassengerDraft.fromJson(Map<String, dynamic> json) =>
      _$FlightPassengerDraftFromJson(json);
}
```

- [ ] **Step 4: Write the validation rules**

Create `lib/features/flight/domain/utils/flight_passenger_validation.dart`:

```dart
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';

/// Fields the passenger endpoint requires. A middle name is deliberately
/// absent — plenty of travel documents have none.
enum FlightPassengerField {
  title,
  firstName,
  lastName,
  gender,
  birthDate,
  documentNumber,
  nationality,
  residence,
}

bool _blank(String? value) => value == null || value.trim().isEmpty;

/// What this traveller still needs, in the order the form presents it — so
/// the list can name the first gap rather than showing a bare warning dot.
List<FlightPassengerField> missingFlightPassengerFields(
  FlightPassengerDraft draft,
) {
  return [
    if (_blank(draft.title)) FlightPassengerField.title,
    if (_blank(draft.firstName)) FlightPassengerField.firstName,
    if (_blank(draft.lastName)) FlightPassengerField.lastName,
    if (_blank(draft.gender)) FlightPassengerField.gender,
    if (draft.birthDate == null) FlightPassengerField.birthDate,
    if (_blank(draft.documentNumber)) FlightPassengerField.documentNumber,
    if (_blank(draft.nationalityCode)) FlightPassengerField.nationality,
    if (_blank(draft.residenceCode)) FlightPassengerField.residence,
  ];
}

bool isFlightPassengerComplete(FlightPassengerDraft draft) =>
    missingFlightPassengerFields(draft).isEmpty;

/// Classifies a traveller by age **at departure**, not today — a child who
/// turns 12 before the flight must travel on an adult fare.
FlightPassengerType classifyFlightPassenger({
  required DateTime birthDate,
  required DateTime departureDate,
}) {
  final years = _completedYears(birthDate, departureDate);
  if (years >= 12) return FlightPassengerType.adult;
  if (years >= 2) return FlightPassengerType.child;
  return FlightPassengerType.infant;
}

/// The traveller's real fare category when it disagrees with the slot they
/// were booked into, or null when they agree or no birth date is set yet.
///
/// The counts were fixed at search and the fare was priced on them, so this
/// is a warning to fix the date or redo the search — never a silent
/// reclassification.
FlightPassengerType? flightPassengerTypeMismatch(
  FlightPassengerDraft draft, {
  required DateTime departureDate,
}) {
  final birthDate = draft.birthDate;
  if (birthDate == null) return null;
  final actual = classifyFlightPassenger(
    birthDate: birthDate,
    departureDate: departureDate,
  );
  return actual == draft.type ? null : actual;
}

int _completedYears(DateTime from, DateTime to) {
  var years = to.year - from.year;
  final hadBirthday =
      to.month > from.month || (to.month == from.month && to.day >= from.day);
  if (!hadBirthday) years -= 1;
  return years;
}
```

- [ ] **Step 5: Run codegen and the test**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/features/flight/domain/flight_passenger_validation_test.dart`
Expected: PASS — 11 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/features/flight/domain test/features/flight/domain/flight_passenger_validation_test.dart
git commit -m "Validate Flight Passenger Drafts Against Departure Date"
```

---

## Task 4: Route API validation errors back to their passenger

**Files:**
- Create: `lib/features/flight/domain/utils/flight_passenger_errors.dart`
- Test: `test/features/flight/domain/flight_passenger_errors_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_errors.dart';

void main() {
  test('groups indexed keys under their passenger', () {
    final result = flightPassengerErrorsByIndex({
      'passengers.0.documentNumber': ['The document number is invalid.'],
      'passengers.2.firstName': ['The first name is required.'],
    });
    expect(result.keys.toList()..sort(), [0, 2]);
    expect(result[0]!['documentNumber'], 'The document number is invalid.');
    expect(result[2]!['firstName'], 'The first name is required.');
  });

  test('keeps only the first message per field', () {
    final result = flightPassengerErrorsByIndex({
      'passengers.1.birthDate': ['Too old.', 'Also wrong.'],
    });
    expect(result[1]!['birthDate'], 'Too old.');
  });

  test('collects several fields on one passenger', () {
    final result = flightPassengerErrorsByIndex({
      'passengers.1.firstName': ['Required.'],
      'passengers.1.lastName': ['Required.'],
    });
    expect(result[1], hasLength(2));
  });

  test('ignores keys that are not passenger-indexed', () {
    final result = flightPassengerErrorsByIndex({
      'offer_id': ['Expired.'],
      'passengers': ['At least one is required.'],
    });
    expect(result, isEmpty);
  });

  test('null errors yield an empty map', () {
    expect(flightPassengerErrorsByIndex(null), isEmpty);
  });

  test('unparseable index is ignored rather than throwing', () {
    final result = flightPassengerErrorsByIndex({
      'passengers.x.firstName': ['Required.'],
    });
    expect(result, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight/domain/flight_passenger_errors_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Write the implementation**

Create `lib/features/flight/domain/utils/flight_passenger_errors.dart`:

```dart
/// Splits `ApiException.errors` into per-passenger field errors.
///
/// The endpoint keys validation failures by position —
/// `passengers.1.documentNumber`. On a screen holding up to nine travellers,
/// a single banner saying "check your details" tells the rider nothing about
/// who to fix, so the index is parsed and the message pinned to that row.
///
/// Keys that are not passenger-indexed belong to the booking as a whole and
/// are left to the caller's general error handling.
Map<int, Map<String, String>> flightPassengerErrorsByIndex(
  Map<String, List<String>>? errors,
) {
  if (errors == null) return const {};
  final byIndex = <int, Map<String, String>>{};

  for (final entry in errors.entries) {
    final parts = entry.key.split('.');
    if (parts.length < 3 || parts.first != 'passengers') continue;
    final index = int.tryParse(parts[1]);
    if (index == null) continue;
    if (entry.value.isEmpty) continue;
    final field = parts.sublist(2).join('.');
    (byIndex[index] ??= <String, String>{})[field] = entry.value.first;
  }

  return byIndex;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/flight/domain/flight_passenger_errors_test.dart`
Expected: PASS — 6 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/flight/domain/utils/flight_passenger_errors.dart test/features/flight/domain/flight_passenger_errors_test.dart
git commit -m "Route Flight Passenger Errors To Their Row"
```

---

## Task 5: Saved travellers in secure storage

**Files:**
- Modify: `lib/core/storage/secure_storage.dart`
- Create: `lib/features/flight/data/flight_saved_travellers_store.dart`
- Test: `test/features/flight/data/flight_saved_travellers_store_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:safaria/core/storage/secure_storage.dart';
import 'package:safaria/features/flight/data/flight_saved_travellers_store.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';

const _draft = FlightPassengerDraft(
  type: FlightPassengerType.adult,
  title: 'MRS',
  firstName: 'Mona',
  lastName: 'Ahmed',
  gender: 'F',
  documentNumber: '29203141234567',
  nationalityCode: 'EGY',
  residenceCode: 'EGY',
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('an empty store reads as an empty list', () async {
    final store = FlightSavedTravellersStore(SecureStorage());
    expect(await store.read(), isEmpty);
  });

  test('a saved traveller round-trips with an id assigned', () async {
    final store = FlightSavedTravellersStore(SecureStorage());
    final saved = await store.save(_draft);
    expect(saved.savedId, isNotNull);

    final all = await store.read();
    expect(all, hasLength(1));
    expect(all.first.firstName, 'Mona');
    expect(all.first.documentNumber, '29203141234567');
  });

  test('saving an already-saved traveller updates rather than duplicates',
      () async {
    final store = FlightSavedTravellersStore(SecureStorage());
    final saved = await store.save(_draft);
    await store.save(saved.copyWith(lastName: 'Hassan'));

    final all = await store.read();
    expect(all, hasLength(1));
    expect(all.first.lastName, 'Hassan');
  });

  test('delete removes only the named traveller', () async {
    final store = FlightSavedTravellersStore(SecureStorage());
    final first = await store.save(_draft);
    await store.save(_draft.copyWith(firstName: 'Youssef'));

    await store.delete(first.savedId!);
    final all = await store.read();
    expect(all, hasLength(1));
    expect(all.first.firstName, 'Youssef');
  });

  test('corrupt stored json reads as empty rather than throwing', () async {
    final storage = SecureStorage();
    await storage.writeFlightTravellers('not json');
    final store = FlightSavedTravellersStore(storage);
    expect(await store.read(), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight/data/flight_saved_travellers_store_test.dart`
Expected: FAIL — `writeFlightTravellers` is not defined.

- [ ] **Step 3: Add the storage key**

In `lib/core/storage/secure_storage.dart`, alongside the existing keys:

```dart
  static const _kFlightTravellers = 'flight_saved_travellers';
```

and the accessors, next to the other read/write pairs:

```dart
  /// Saved flight travellers, as a JSON array. Held here rather than in plain
  /// preferences because the payload includes names, birth dates, and
  /// national ID numbers.
  Future<String?> readFlightTravellers() =>
      _storage.read(key: _kFlightTravellers);

  Future<void> writeFlightTravellers(String json) =>
      _storage.write(key: _kFlightTravellers, value: json);

  Future<void> clearFlightTravellers() =>
      _storage.delete(key: _kFlightTravellers);
```

Extend the class doc comment to mention the new key.

- [ ] **Step 4: Write the store**

Create `lib/features/flight/data/flight_saved_travellers_store.dart`:

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/storage/secure_storage.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';

final flightSavedTravellersStoreProvider =
    Provider<FlightSavedTravellersStore>((ref) {
  return FlightSavedTravellersStore(ref.watch(secureStorageProvider));
});

/// Travellers the rider chose to keep, so a family booking is not retyped
/// every trip.
///
/// This is identity data — full name, birth date, national ID — so it lives
/// in secure storage, and the profile screen must offer a way to delete it.
class FlightSavedTravellersStore {
  const FlightSavedTravellersStore(this._storage);

  final SecureStorage _storage;

  Future<List<FlightPassengerDraft>> read() async {
    final raw = await _storage.readFlightTravellers();
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(FlightPassengerDraft.fromJson)
          .toList();
    } on FormatException {
      // A corrupt blob is not worth crashing the passenger form over —
      // the rider simply sees no suggestions.
      return const [];
    }
  }

  /// Saves [draft], assigning an id when it has none. A draft that already
  /// carries a [FlightPassengerDraft.savedId] replaces its stored version.
  Future<FlightPassengerDraft> save(FlightPassengerDraft draft) async {
    final all = List<FlightPassengerDraft>.from(await read());
    final withId = draft.savedId != null
        ? draft
        : draft.copyWith(
            savedId: DateTime.now().microsecondsSinceEpoch.toString(),
          );

    final index = all.indexWhere((t) => t.savedId == withId.savedId);
    if (index == -1) {
      all.add(withId);
    } else {
      all[index] = withId;
    }

    await _write(all);
    return withId;
  }

  Future<void> delete(String savedId) async {
    final all = await read();
    await _write(all.where((t) => t.savedId != savedId).toList());
  }

  Future<void> clear() => _storage.clearFlightTravellers();

  Future<void> _write(List<FlightPassengerDraft> travellers) {
    return _storage.writeFlightTravellers(
      jsonEncode(travellers.map((t) => t.toJson()).toList()),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/flight/data/flight_saved_travellers_store_test.dart`
Expected: PASS — 5 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/core/storage/secure_storage.dart lib/features/flight/data/flight_saved_travellers_store.dart test/features/flight/data/flight_saved_travellers_store_test.dart
git commit -m "Persist Saved Flight Travellers Securely"
```

---

## Task 6: Submit passengers and extend the offer id relay

**Files:**
- Modify: `lib/features/flight/data/flight_dto_mapper.dart`, `flight_repository.dart`, `flight_repository_impl.dart`
- Modify: `lib/features/flight/presentation/providers/flight_booking_providers.dart`
- Test: `test/features/flight/data/flight_passenger_body_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/data/flight_dto_mapper.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';

final _mona = FlightPassengerDraft(
  type: FlightPassengerType.adult,
  title: 'MRS',
  firstName: 'Mona',
  middleName: 'Ali',
  lastName: 'Ahmed',
  gender: 'F',
  birthDate: DateTime(1992, 3, 14),
  documentNumber: '29203141234567',
  nationalityCode: 'EGY',
  residenceCode: 'EGY',
);

void main() {
  test('builds one entry per passenger with the shared contact details', () {
    final body = FlightDtoMapper.passengersRequestBody(
      passengers: [_mona],
      contact: const FlightContactDetails(
        email: 'a@b.com',
        phone: '01090510796',
      ),
    );
    final list = body['passengers'] as List;
    expect(list, hasLength(1));

    final first = list.first as Map<String, dynamic>;
    expect(first['title'], 'MRS');
    expect(first['firstName'], 'Mona');
    expect(first['birthDate'], '1992-03-14');
    expect(first['passengerTypeCode'], 'ADT');
    expect(first['nationalityCountryCode'], 'EGY');
    expect(first['email'], 'a@b.com');
    expect(first['phone'], '01090510796');
  });

  test('a null middle name is sent as an empty string, not omitted', () {
    final body = FlightDtoMapper.passengersRequestBody(
      passengers: [_mona.copyWith(middleName: null)],
      contact: const FlightContactDetails(email: 'a@b.com', phone: '010'),
    );
    final first = (body['passengers'] as List).first as Map<String, dynamic>;
    expect(first['middleName'], '');
  });

  test('maps each passenger type to its wire code', () {
    final body = FlightDtoMapper.passengersRequestBody(
      passengers: [
        _mona,
        _mona.copyWith(type: FlightPassengerType.child),
        _mona.copyWith(type: FlightPassengerType.infant),
      ],
      contact: const FlightContactDetails(email: 'a@b.com', phone: '010'),
    );
    expect(
      (body['passengers'] as List)
          .map((p) => (p as Map)['passengerTypeCode'])
          .toList(),
      ['ADT', 'CHD', 'INF'],
    );
  });

  test('reads the new offer id out of the response envelope', () {
    final offerId = FlightDtoMapper.offerIdFromEnvelope({
      'status': 200,
      'message': 'Passengers added',
      'data': {'offerId': 'OFFER_C'},
    });
    expect(offerId, 'OFFER_C');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight/data/flight_passenger_body_test.dart`
Expected: FAIL — `passengersRequestBody` is not defined.

- [ ] **Step 3: Write the mapper**

Add to `lib/features/flight/data/flight_dto_mapper.dart`:

```dart
  /// Builds the `POST /flights/{offer_id}/passengers` body.
  ///
  /// [contact] is written onto every traveller: the endpoint takes an email
  /// and phone per passenger, but they are the booker's in practice.
  ///
  /// `address` is omitted — it is assumed optional (see the screens spec). If
  /// the endpoint starts rejecting bodies without it, add it here rather than
  /// in the form.
  static Map<String, dynamic> passengersRequestBody({
    required List<FlightPassengerDraft> passengers,
    required FlightContactDetails contact,
  }) {
    return {
      'passengers': [
        for (final p in passengers)
          {
            'title': p.title ?? '',
            'firstName': p.firstName ?? '',
            'middleName': p.middleName ?? '',
            'lastName': p.lastName ?? '',
            'birthDate': p.birthDate == null ? '' : toIsoDate(p.birthDate!),
            'documentNumber': p.documentNumber ?? '',
            'nationalityCountryCode': p.nationalityCode ?? '',
            'residenceCountryCode': p.residenceCode ?? '',
            'gender': p.gender ?? '',
            'email': contact.email,
            'phone': contact.phone,
            'passengerTypeCode': flightPassengerWireCode(p.type),
          },
      ],
    };
  }

  /// Reads `data.offerId` — the id minted by confirm and again by adding
  /// passengers. Every later call must use the most recent one.
  static String? offerIdFromEnvelope(dynamic body) {
    final data = body is Map ? body['data'] : null;
    return data is Map ? _string(data['offerId']) : null;
  }
```

Add the imports it needs:

```dart
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_rules.dart';
```

- [ ] **Step 4: Add the repository method**

Interface:

```dart
  /// Attaches travellers to a confirmed offer.
  ///
  /// [offerId] must be the id from [confirmOrder]. Returns a **new** offer id
  /// that order creation must use.
  Future<String> addPassengers({
    required String offerId,
    required List<FlightPassengerDraft> passengers,
    required FlightContactDetails contact,
  });
```

Implementation:

```dart
  @override
  Future<String> addPassengers({
    required String offerId,
    required List<FlightPassengerDraft> passengers,
    required FlightContactDetails contact,
  }) {
    return _guard(() async {
      final body = await _api.addPassengers(
        offerId: offerId,
        body: FlightDtoMapper.passengersRequestBody(
          passengers: passengers,
          contact: contact,
        ),
      );
      final newOfferId = FlightDtoMapper.offerIdFromEnvelope(body);
      if (newOfferId == null || newOfferId.isEmpty) {
        throw const ApiException(
          'The booking did not return an offer reference. Please try again.',
        );
      }
      return newOfferId;
    });
  }
```

- [ ] **Step 5: Extend the relay in state**

In `flight_booking_providers.dart`, add to `FlightBookingState`:

```dart
    @Default([]) List<FlightPassengerDraft> passengerDrafts,
    @Default(FlightContactDetails()) FlightContactDetails contact,
    String? passengersOfferId,
    @Default(<int, Map<String, String>>{})
    Map<int, Map<String, String>> passengerErrors,
```

Update the relay getter — adding passengers mints the third id:

```dart
  /// The offer id the next call must send. Each step that mints a new id
  /// takes precedence over the one before it: search → confirm → passengers.
  String? get activeOfferId =>
      passengersOfferId ?? confirmedOrder?.offerId ?? selectedOffer?.offerId;
```

Add the actions:

```dart
  void seedPassengerDrafts() {
    if (state.passengerDrafts.isNotEmpty) return;
    final counts = flightPassengerCountsOf(state.searchParams);
    state = state.copyWith(
      passengerDrafts: [
        for (var i = 0; i < counts.adults; i++)
          const FlightPassengerDraft(type: FlightPassengerType.adult),
        for (var i = 0; i < counts.children; i++)
          const FlightPassengerDraft(type: FlightPassengerType.child),
        for (var i = 0; i < counts.infants; i++)
          const FlightPassengerDraft(type: FlightPassengerType.infant),
      ],
    );
  }

  void updatePassengerDraft(int index, FlightPassengerDraft draft) {
    final drafts = List<FlightPassengerDraft>.from(state.passengerDrafts);
    if (index < 0 || index >= drafts.length) return;
    drafts[index] = draft;
    final errors =
        Map<int, Map<String, String>>.from(state.passengerErrors)..remove(index);
    state = state.copyWith(passengerDrafts: drafts, passengerErrors: errors);
  }

  void setContactDetails(FlightContactDetails contact) {
    state = state.copyWith(contact: contact);
  }

  /// Submits every traveller. On validation failure the errors are pinned to
  /// the passengers they belong to so the list can point at the right row.
  Future<bool> submitPassengers() async {
    final offerId = state.confirmedOrder?.offerId;
    if (offerId == null) return false;
    state = state.copyWith(
      status: FlightBookingStatus.submittingPassengers,
      error: null,
      passengerErrors: {},
    );
    try {
      final newOfferId = await _repo.addPassengers(
        offerId: offerId,
        passengers: state.passengerDrafts,
        contact: state.contact,
      );
      state = state.copyWith(
        status: FlightBookingStatus.idle,
        passengersOfferId: newOfferId,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        status: FlightBookingStatus.error,
        error: e.message,
        passengerErrors: flightPassengerErrorsByIndex(e.errors),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: FlightBookingStatus.error,
        error: e.toString(),
      );
      return false;
    }
  }
```

Add `submittingPassengers` to `FlightBookingStatus`.

- [ ] **Step 6: Run codegen and the test**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/features/flight/data/flight_passenger_body_test.dart`
Expected: PASS — 4 tests.

- [ ] **Step 7: Commit**

```bash
git add lib/features/flight test/features/flight/data/flight_passenger_body_test.dart
git commit -m "Submit Flight Passengers And Extend Offer Id Relay"
```

---

## Task 7: Country field widget

**Files:**
- Create: `lib/features/flight/presentation/widgets/flight_country_field.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`

- [ ] **Step 1: Add the strings**

In `lib/l10n/app_en.arb`:

```json
  "flightCountrySearch": "Search countries",
  "flightCountryEmpty": "No countries match",
```

In `lib/l10n/app_ar.arb`:

```json
  "flightCountrySearch": "دوّر على دولة",
  "flightCountryEmpty": "مفيش دولة مطابقة",
```

- [ ] **Step 2: Write the field**

Create `lib/features/flight/presentation/widgets/flight_country_field.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_country.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Country picker backed by `GET /countries`.
///
/// The auth screens ship a hardcoded dial-code list with no ISO codes, which
/// cannot serve the passenger form — the provider needs a country code, not a
/// flag and a phone prefix.
class FlightCountryField extends ConsumerWidget {
  const FlightCountryField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  /// The stored value, in whichever ISO width the passenger endpoint takes.
  final String? value;
  final String label;
  final ValueChanged<FlightCountry> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countries = ref.watch(flightCountriesProvider);

    return countries.when(
      loading: () => _Shell(label: label, child: const Text('…')),
      error: (_, __) => _Shell(label: label, child: const Text('—')),
      data: (list) {
        FlightCountry? selected;
        for (final country in list) {
          if (country.passengerCode == value) selected = country;
        }
        return _Shell(
          label: label,
          errorText: errorText,
          onTap: () async {
            final picked = await showModalBottomSheet<FlightCountry>(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.bgElevated,
              builder: (_) => _CountrySheet(countries: list),
            );
            if (picked != null) onChanged(picked);
          },
          child: Text(
            selected?.name ?? '',
            style: AppTypography.body,
          ),
        );
      },
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.label,
    required this.child,
    this.onTap,
    this.errorText,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(
                color: errorText == null ? AppColors.hairline : AppColors.error,
              ),
            ),
            child: child,
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              errorText!,
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.countries});

  final List<FlightCountry> countries;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final needle = _query.trim().toLowerCase();
    final matches = needle.isEmpty
        ? widget.countries
        : widget.countries
            .where((c) =>
                c.name.toLowerCase().contains(needle) ||
                c.iso2.toLowerCase().startsWith(needle) ||
                c.iso3.toLowerCase().startsWith(needle))
            .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.flightCountrySearch),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: AppSpacing.md),
          if (matches.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                l10n.flightCountryEmpty,
                style:
                    AppTypography.body.copyWith(color: AppColors.textMuted),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: matches.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(matches[i].name, style: AppTypography.body),
                  onTap: () => Navigator.of(context).pop(matches[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

`AppColors.error` (`0xFFE5484D`) is the project's danger token.

- [ ] **Step 3: Analyze and commit**

Run: `flutter gen-l10n && flutter analyze lib/features/flight/presentation/widgets/flight_country_field.dart`
Expected: no issues.

```bash
git add lib/features/flight/presentation/widgets/flight_country_field.dart lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "Add Country Field Backed By Countries Endpoint"
```

---

## Task 8: Passenger list screen

**Files:**
- Create: `lib/features/flight/presentation/widgets/flight_passenger_row.dart`
- Create: `lib/features/flight/presentation/flight_passengers_screen.dart`
- Modify: `lib/features/flight/presentation/flight_routes.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`
- Test: `test/features/flight/presentation/flight_passenger_row_test.dart`

- [ ] **Step 1: Add the strings**

In `lib/l10n/app_en.arb`:

```json
  "flightPassengersTitle": "Passenger details",
  "flightContactSection": "Contact details",
  "flightContactOnce": "Entered once",
  "flightContactEmail": "Email",
  "flightContactPhone": "Phone",
  "flightPassengerAdultN": "Adult {number}",
  "flightPassengerChildN": "Child {number}",
  "flightPassengerInfantN": "Infant {number}",
  "flightPassengerMissing": "Missing {field}",
  "flightFieldTitle": "title",
  "flightFieldFirstName": "first name",
  "flightFieldLastName": "last name",
  "flightFieldGender": "gender",
  "flightFieldBirthDate": "date of birth",
  "flightFieldDocumentNumber": "national ID",
  "flightFieldNationality": "nationality",
  "flightFieldResidence": "country of residence",
  "@flightPassengerAdultN": { "placeholders": { "number": {"type": "int"} } },
  "@flightPassengerChildN": { "placeholders": { "number": {"type": "int"} } },
  "@flightPassengerInfantN": { "placeholders": { "number": {"type": "int"} } },
  "@flightPassengerMissing": { "placeholders": { "field": {"type": "String"} } },
```

In `lib/l10n/app_ar.arb`:

```json
  "flightPassengersTitle": "بيانات الركاب",
  "flightContactSection": "بيانات التواصل",
  "flightContactOnce": "مرة واحدة",
  "flightContactEmail": "الإيميل",
  "flightContactPhone": "الموبايل",
  "flightPassengerAdultN": "بالغ {number}",
  "flightPassengerChildN": "طفل {number}",
  "flightPassengerInfantN": "رضيع {number}",
  "flightPassengerMissing": "ناقص {field}",
  "flightFieldTitle": "اللقب",
  "flightFieldFirstName": "الاسم الأول",
  "flightFieldLastName": "اسم العيلة",
  "flightFieldGender": "النوع",
  "flightFieldBirthDate": "تاريخ الميلاد",
  "flightFieldDocumentNumber": "الرقم القومي",
  "flightFieldNationality": "الجنسية",
  "flightFieldResidence": "بلد الإقامة",
```

- [ ] **Step 2: Write the failing test**

Create `test/features/flight/presentation/flight_passenger_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_passenger_row.dart';
import 'package:safaria/l10n/app_localizations.dart';

Future<void> _pump(WidgetTester tester, FlightPassengerDraft draft) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: FlightPassengerRow(
          draft: draft,
          ordinal: 2,
          onTap: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('names the first missing field rather than a bare warning',
      (tester) async {
    const draft = FlightPassengerDraft(
      type: FlightPassengerType.adult,
      title: 'MR',
      firstName: 'Ahmed',
      lastName: 'Mostafa',
      gender: 'M',
      nationalityCode: 'EGY',
      residenceCode: 'EGY',
    );
    await _pump(tester, draft);
    expect(find.text('Missing date of birth'), findsOneWidget);
  });

  testWidgets('shows the traveller name once complete', (tester) async {
    final draft = FlightPassengerDraft(
      type: FlightPassengerType.adult,
      title: 'MR',
      firstName: 'Ahmed',
      lastName: 'Mostafa',
      gender: 'M',
      birthDate: DateTime(1990, 1, 2),
      documentNumber: '29001021234567',
      nationalityCode: 'EGY',
      residenceCode: 'EGY',
    );
    await _pump(tester, draft);
    expect(find.text('Ahmed Mostafa'), findsOneWidget);
  });

  testWidgets('labels an empty draft by its slot', (tester) async {
    const draft = FlightPassengerDraft(type: FlightPassengerType.child);
    await _pump(tester, draft);
    expect(find.text('Child 2'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/flight/presentation/flight_passenger_row_test.dart`
Expected: FAIL — `FlightPassengerRow` is not defined.

- [ ] **Step 4: Write the row**

Create `lib/features/flight/presentation/widgets/flight_passenger_row.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_validation.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// One traveller in the list. The subtitle names what is still missing —
/// "Missing national ID" rather than a silent warning dot — so the rider
/// knows which row to open without opening all of them.
class FlightPassengerRow extends StatelessWidget {
  const FlightPassengerRow({
    super.key,
    required this.draft,
    required this.ordinal,
    required this.onTap,
    this.serverError,
  });

  final FlightPassengerDraft draft;

  /// Position within this passenger's own type, 1-based.
  final int ordinal;
  final VoidCallback onTap;

  /// A message the API pinned to this traveller, which outranks any local
  /// completeness hint.
  final String? serverError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final missing = missingFlightPassengerFields(draft);
    final complete = missing.isEmpty;
    final hasError = serverError != null;

    final name = [draft.firstName, draft.lastName]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
    final slotLabel = switch (draft.type) {
      FlightPassengerType.adult => l10n.flightPassengerAdultN(ordinal),
      FlightPassengerType.child => l10n.flightPassengerChildN(ordinal),
      FlightPassengerType.infant => l10n.flightPassengerInfantN(ordinal),
    };

    final subtitle = hasError
        ? serverError!
        : complete
            ? slotLabel
            : l10n.flightPassengerMissing(_fieldLabel(l10n, missing.first));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: hasError
                ? AppColors.error
                : complete
                    ? AppColors.hairline
                    : AppColors.secondary,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasError
                  ? PhosphorIconsLight.warningCircle
                  : complete
                      ? PhosphorIconsLight.checkCircle
                      : PhosphorIconsLight.circle,
              size: 22,
              color: hasError
                  ? AppColors.error
                  : complete
                      ? AppColors.success
                      : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? slotLabel : name,
                    style: AppTypography.body,
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: hasError
                          ? AppColors.error
                          : complete
                              ? AppColors.textMuted
                              : AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const LtrIcon(
              PhosphorIconsLight.caretRight,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  static String _fieldLabel(
    AppLocalizations l10n,
    FlightPassengerField field,
  ) {
    return switch (field) {
      FlightPassengerField.title => l10n.flightFieldTitle,
      FlightPassengerField.firstName => l10n.flightFieldFirstName,
      FlightPassengerField.lastName => l10n.flightFieldLastName,
      FlightPassengerField.gender => l10n.flightFieldGender,
      FlightPassengerField.birthDate => l10n.flightFieldBirthDate,
      FlightPassengerField.documentNumber => l10n.flightFieldDocumentNumber,
      FlightPassengerField.nationality => l10n.flightFieldNationality,
      FlightPassengerField.residence => l10n.flightFieldResidence,
    };
  }
}
```

The chevron uses `LtrIcon` from `lib/shared/widgets/ltr_icon.dart`, which mirrors a directional glyph to match the active text direction — so it points into the row in both Arabic and English. Add its import:

```dart
import 'package:safaria/shared/widgets/ltr_icon.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter gen-l10n && flutter test test/features/flight/presentation/flight_passenger_row_test.dart`
Expected: PASS — 3 tests.

- [ ] **Step 6: Write the list screen**

Create `lib/features/flight/presentation/flight_passengers_screen.dart`. It carries the step bar, the contact block, the rows, and a Continue gated on every row being complete.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';
import 'package:safaria/features/flight/domain/entities/flight_wizard_step.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_validation.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_booking_step_bar.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_passenger_row.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Wizard step 3.
class FlightPassengersScreen extends ConsumerStatefulWidget {
  const FlightPassengersScreen({super.key});

  @override
  ConsumerState<FlightPassengersScreen> createState() =>
      _FlightPassengersScreenState();
}

class _FlightPassengersScreenState
    extends ConsumerState<FlightPassengersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(flightBookingProvider.notifier).seedPassengerDrafts();
    });
  }

  /// 1-based position within the traveller's own type, so the labels read
  /// "Adult 1, Adult 2, Child 1" rather than numbering straight through.
  int _ordinalOf(List<FlightPassengerDraft> drafts, int index) {
    var seen = 0;
    for (var i = 0; i <= index; i++) {
      if (drafts[i].type == drafts[index].type) seen++;
    }
    return seen;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(flightBookingProvider);
    final notifier = ref.read(flightBookingProvider.notifier);

    if (state.confirmedOrder == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(FlightRoutes.results);
      });
      return const SizedBox.shrink();
    }

    final drafts = state.passengerDrafts;
    final contactFilled = state.contact.email.trim().isNotEmpty &&
        state.contact.phone.trim().isNotEmpty;
    final allComplete =
        drafts.isNotEmpty && drafts.every(isFlightPassengerComplete);
    final canContinue = contactFilled && allComplete;

    return Scaffold(
      appBar: BookingAppBar(title: l10n.flightPassengersTitle),
      body: Column(
        children: [
          FlightBookingStepBar(
            current: FlightWizardStep.passengers,
            haveBundles: state.selectedOffer?.haveBundles ?? false,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  l10n.flightContactSection,
                  style: AppTypography.body,
                ),
                Text(
                  l10n.flightContactOnce,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  initialValue: state.contact.email,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration:
                      InputDecoration(labelText: l10n.flightContactEmail),
                  onChanged: (value) => notifier.setContactDetails(
                    state.contact.copyWith(email: value),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  initialValue: state.contact.phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration:
                      InputDecoration(labelText: l10n.flightContactPhone),
                  onChanged: (value) => notifier.setContactDetails(
                    state.contact.copyWith(phone: value),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (var i = 0; i < drafts.length; i++)
                  FlightPassengerRow(
                    draft: drafts[i],
                    ordinal: _ordinalOf(drafts, i),
                    serverError: state.passengerErrors[i]?.values.first,
                    onTap: () => context.push(
                      FlightRoutes.passengerForm,
                      extra: i,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: PrimaryButton(
              label: l10n.flightContinue,
              loading:
                  state.status == FlightBookingStatus.submittingPassengers,
              onPressed: canContinue
                  ? () async {
                      final ok = await notifier.submitPassengers();
                      if (ok && context.mounted) {
                        context.push(FlightRoutes.results);
                      }
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
```

The success branch points at results until Phase 4 adds the pay route.

- [ ] **Step 7: Register the routes**

In `flight_routes.dart`:

```dart
  static const passengers = '/flight/passengers';
  static const passengerForm = '/flight/passengers/form';
```

```dart
      GoRoute(
        path: FlightRoutes.passengers,
        builder: (context, state) => const FlightPassengersScreen(),
      ),
      GoRoute(
        path: FlightRoutes.passengerForm,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! int) return const FlightPassengersScreen();
          return FlightPassengerFormScreen(index: extra);
        },
      ),
```

Register the form route only after Task 9 creates that screen.

- [ ] **Step 8: Commit**

```bash
git add lib/features/flight lib/l10n/app_en.arb lib/l10n/app_ar.arb test/features/flight/presentation/flight_passenger_row_test.dart
git commit -m "Add Flight Passenger List With Shared Contact Details"
```

---

## Task 9: Passenger form screen

**Files:**
- Create: `lib/features/flight/presentation/flight_passenger_form_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`

- [ ] **Step 1: Add the strings**

In `lib/l10n/app_en.arb`:

```json
  "flightNameAsPassport": "As printed on your passport",
  "flightFirstName": "First name",
  "flightMiddleName": "Middle name",
  "flightLastName": "Last name",
  "flightTitleMr": "Mr",
  "flightTitleMrs": "Mrs",
  "flightTitleMs": "Ms",
  "flightGenderMale": "Male",
  "flightGenderFemale": "Female",
  "flightSavedTravellers": "Saved travellers",
  "flightSaveForNextTime": "Save for next time",
  "flightNidLength": "The national ID is 14 digits",
  "flightTypeMismatch": "This date of birth does not match the fare booked for this traveller",
  "flightSave": "Save",
```

In `lib/l10n/app_ar.arb`:

```json
  "flightNameAsPassport": "زي ما هو مكتوب في الجواز",
  "flightFirstName": "الاسم الأول",
  "flightMiddleName": "الاسم الأوسط",
  "flightLastName": "اسم العيلة",
  "flightTitleMr": "السيد",
  "flightTitleMrs": "السيدة",
  "flightTitleMs": "الآنسة",
  "flightGenderMale": "ذكر",
  "flightGenderFemale": "أنثى",
  "flightSavedTravellers": "مسافرين محفوظين",
  "flightSaveForNextTime": "احفظ للمرات الجاية",
  "flightNidLength": "الرقم القومي 14 رقم",
  "flightTypeMismatch": "تاريخ الميلاد ده مش مطابق للتذكرة المحجوزة للراكب ده",
  "flightSave": "حفظ",
```

- [ ] **Step 2: Write the form**

Create `lib/features/flight/presentation/flight_passenger_form_screen.dart`.

Structure, top to bottom:

1. **Saved-traveller chips** — from `flightSavedTravellersStoreProvider.read()`; tapping one fills every field except `savedId`, which stays on the stored record.
2. **Title and gender** — two dropdowns side by side. Selecting a gender sets the title when it is still blank (`M` → `MR`, `F` → `MRS`), never overwriting a title the rider chose.
3. **Names** — three text fields, each with `textDirection: TextDirection.ltr` and `textAlign: TextAlign.left`, under one hint reading `l10n.flightNameAsPassport`. Carriers match the name to the travel document, so an Arabic name is rejected at the gate — these fields stay Latin even though the app is RTL.
4. **Birth date** — a date picker whose `lastDate` is the departure date. After picking, call `flightPassengerTypeMismatch`; when non-null show `l10n.flightTypeMismatch` beneath the field as a warning that does not block saving.
5. **National ID** — `TextDirection.ltr`, numeric keyboard, validated as exactly 14 digits with `l10n.flightNidLength`.
6. **Nationality and residence** — two `FlightCountryField`s, each writing `country.passengerCode`.
7. **Save for next time** — a checkbox; when ticked, `save` on the store before popping.

Server errors for this passenger come from `state.passengerErrors[index]` and attach to their field by the API's key name — `documentNumber`, `firstName`, and so on.

Save writes through `notifier.updatePassengerDraft(index, draft)` and pops.

```dart
class FlightPassengerFormScreen extends ConsumerStatefulWidget {
  const FlightPassengerFormScreen({super.key, required this.index});

  final int index;

  @override
  ConsumerState<FlightPassengerFormScreen> createState() =>
      _FlightPassengerFormScreenState();
}

class _FlightPassengerFormScreenState
    extends ConsumerState<FlightPassengerFormScreen> {
  late FlightPassengerDraft _draft;
  bool _saveForNextTime = false;

  @override
  void initState() {
    super.initState();
    final drafts = ref.read(flightBookingProvider).passengerDrafts;
    _draft = widget.index < drafts.length
        ? drafts[widget.index]
        : const FlightPassengerDraft(type: FlightPassengerType.adult);
  }

  /// Departure is the first leg's date — the reference point for age, since
  /// a child who turns 12 before the flight travels on an adult fare.
  DateTime _departureDate() {
    final params = ref.read(flightBookingProvider).searchParams;
    return params?.legs.first.date ?? DateTime.now();
  }

  Future<void> _save() async {
    ref
        .read(flightBookingProvider.notifier)
        .updatePassengerDraft(widget.index, _draft);
    if (_saveForNextTime) {
      await ref.read(flightSavedTravellersStoreProvider).save(_draft);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final errors =
        ref.watch(flightBookingProvider).passengerErrors[widget.index] ?? {};
    final departure = _departureDate();
    final mismatch =
        flightPassengerTypeMismatch(_draft, departureDate: departure);

    return Scaffold(
      appBar: BookingAppBar(title: l10n.flightPassengersTitle),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _SavedTravellerChips(
            onPick: (picked) => setState(() {
              _draft = picked.copyWith(
                type: _draft.type,
                savedId: picked.savedId,
              );
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _draft.title,
                  decoration:
                      InputDecoration(labelText: l10n.flightFieldTitle),
                  items: [
                    DropdownMenuItem(value: 'MR', child: Text(l10n.flightTitleMr)),
                    DropdownMenuItem(
                        value: 'MRS', child: Text(l10n.flightTitleMrs)),
                    DropdownMenuItem(value: 'MS', child: Text(l10n.flightTitleMs)),
                  ],
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(title: value)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _draft.gender,
                  decoration:
                      InputDecoration(labelText: l10n.flightFieldGender),
                  items: [
                    DropdownMenuItem(
                        value: 'M', child: Text(l10n.flightGenderMale)),
                    DropdownMenuItem(
                        value: 'F', child: Text(l10n.flightGenderFemale)),
                  ],
                  onChanged: (value) => setState(() {
                    // Derive the title from gender only while the rider has
                    // not chosen one — never overwrite their choice.
                    final title = _draft.title ??
                        (value == 'F' ? 'MRS' : 'MR');
                    _draft = _draft.copyWith(gender: value, title: title);
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.flightNameAsPassport,
            style:
                AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          _LatinField(
            label: l10n.flightFirstName,
            value: _draft.firstName,
            errorText: errors['firstName'],
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(firstName: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          _LatinField(
            label: l10n.flightMiddleName,
            value: _draft.middleName,
            errorText: errors['middleName'],
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(middleName: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          _LatinField(
            label: l10n.flightLastName,
            value: _draft.lastName,
            errorText: errors['lastName'],
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(lastName: v)),
          ),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _draft.birthDate ?? DateTime(1990),
                firstDate: DateTime(1920),
                lastDate: departure,
              );
              if (picked != null) {
                setState(() => _draft = _draft.copyWith(birthDate: picked));
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.flightFieldBirthDate,
                errorText: errors['birthDate'],
              ),
              child: Text(
                _draft.birthDate == null
                    ? ''
                    : toIsoDate(_draft.birthDate!),
                style: AppTypography.body,
              ),
            ),
          ),
          if (mismatch != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                l10n.flightTypeMismatch,
                style:
                    AppTypography.caption.copyWith(color: AppColors.warning),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            initialValue: _draft.documentNumber,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: l10n.flightFieldDocumentNumber,
              errorText: errors['documentNumber'] ??
                  ((_draft.documentNumber ?? '').isNotEmpty &&
                          _draft.documentNumber!.trim().length != 14
                      ? l10n.flightNidLength
                      : null),
            ),
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(documentNumber: v)),
          ),
          const SizedBox(height: AppSpacing.md),
          FlightCountryField(
            label: l10n.flightFieldNationality,
            value: _draft.nationalityCode,
            errorText: errors['nationalityCountryCode'],
            onChanged: (country) => setState(
              () => _draft =
                  _draft.copyWith(nationalityCode: country.passengerCode),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FlightCountryField(
            label: l10n.flightFieldResidence,
            value: _draft.residenceCode,
            errorText: errors['residenceCountryCode'],
            onChanged: (country) => setState(
              () => _draft =
                  _draft.copyWith(residenceCode: country.passengerCode),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _saveForNextTime,
            onChanged: (value) =>
                setState(() => _saveForNextTime = value ?? false),
            title: Text(
              l10n.flightSaveForNextTime,
              style: AppTypography.body,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(label: l10n.flightSave, onPressed: _save),
        ],
      ),
    );
  }
}

/// Name fields stay Latin and left-to-right inside an otherwise RTL app —
/// carriers match the name to the travel document, and an Arabic name is
/// rejected at the gate.
class _LatinField extends StatelessWidget {
  const _LatinField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final String label;
  final String? value;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(labelText: label, errorText: errorText),
      onChanged: onChanged,
    );
  }
}

/// Tappable chips for previously saved travellers. Renders nothing when the
/// store is empty, so a first-time rider sees no dead affordance.
class _SavedTravellerChips extends ConsumerWidget {
  const _SavedTravellerChips({required this.onPick});

  final ValueChanged<FlightPassengerDraft> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<FlightPassengerDraft>>(
      future: ref.read(flightSavedTravellersStoreProvider).read(),
      builder: (context, snapshot) {
        final saved = snapshot.data ?? const <FlightPassengerDraft>[];
        if (saved.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.flightSavedTravellers,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final traveller in saved)
                  ActionChip(
                    label: Text(
                      [traveller.firstName, traveller.lastName]
                          .whereType<String>()
                          .join(' '),
                    ),
                    onPressed: () => onPick(traveller),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
```

The imports this file needs, beyond the Flutter and Riverpod basics:

```dart
import 'package:safaria/core/utils/date_formatting.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/data/flight_saved_travellers_store.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_validation.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_country_field.dart';
```

`toIsoDate` lives in `lib/core/utils/date_formatting.dart:76`.

- [ ] **Step 3: Register the form route**

Add the `GoRoute` from Task 8 step 7 now that the screen exists.

- [ ] **Step 4: Verify**

Run: `flutter gen-l10n && flutter analyze && flutter test`
Expected: no analyzer issues; all tests pass.

Run: `flutter run`. Book two adults and one child. Confirm the list shows three rows labelled Adult 1, Adult 2, Child 1; that an incomplete row names its first missing field; that Continue is disabled until contact details and all rows are filled; and that setting a child's birth date to 15 years ago shows the mismatch warning.

- [ ] **Step 5: Commit**

```bash
git add lib/features/flight lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "Add Flight Passenger Form"
```

---

## Task 10: Saved travellers management in the profile

Without this, the app holds national ID numbers with no way for the rider to clear them.

**Files:**
- Create: `lib/features/profile/presentation/saved_travellers_screen.dart`
- Modify: `lib/features/profile/presentation/profile_routes.dart`, `profile_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`

- [ ] **Step 1: Add the strings**

In `lib/l10n/app_en.arb`:

```json
  "savedTravellersTitle": "Saved travellers",
  "savedTravellersEmpty": "You have no saved travellers",
  "savedTravellersDelete": "Delete",
  "savedTravellersDeleteAll": "Delete all",
  "savedTravellersConfirm": "Delete this traveller's saved details?",
  "savedTravellersCancel": "Cancel",
```

In `lib/l10n/app_ar.arb`:

```json
  "savedTravellersTitle": "المسافرين المحفوظين",
  "savedTravellersEmpty": "مفيش مسافرين محفوظين",
  "savedTravellersDelete": "امسح",
  "savedTravellersDeleteAll": "امسح الكل",
  "savedTravellersConfirm": "تمسح البيانات المحفوظة للمسافر ده؟",
  "savedTravellersCancel": "إلغاء",
```

- [ ] **Step 2: Write the screen**

Create `lib/features/profile/presentation/saved_travellers_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/data/flight_saved_travellers_store.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Lets the rider see and delete the travellers the app has kept.
///
/// These records hold names, birth dates, and national ID numbers. Storing
/// them without a way to clear them would leave identity data on the device
/// with no recourse, so this screen is part of the saved-travellers feature,
/// not an optional extra.
class SavedTravellersScreen extends ConsumerStatefulWidget {
  const SavedTravellersScreen({super.key});

  @override
  ConsumerState<SavedTravellersScreen> createState() =>
      _SavedTravellersScreenState();
}

class _SavedTravellersScreenState extends ConsumerState<SavedTravellersScreen> {
  List<FlightPassengerDraft> _travellers = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final all = await ref.read(flightSavedTravellersStoreProvider).read();
    if (!mounted) return;
    setState(() {
      _travellers = all;
      _loading = false;
    });
  }

  Future<bool> _confirm() async {
    final l10n = AppLocalizations.of(context);
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.savedTravellersConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.savedTravellersCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.savedTravellersDelete,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  /// Only the last four digits are shown — enough for the rider to tell two
  /// records apart, without printing a full national ID on screen.
  String _maskedDocument(String? document) {
    final value = document?.trim() ?? '';
    if (value.length <= 4) return value;
    return '•••• ${value.substring(value.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: BookingAppBar(
        title: l10n.savedTravellersTitle,
        action: _travellers.isEmpty
            ? null
            : TextButton(
                onPressed: () async {
                  if (!await _confirm()) return;
                  await ref.read(flightSavedTravellersStoreProvider).clear();
                  await _reload();
                },
                child: Text(
                  l10n.savedTravellersDeleteAll,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.error),
                ),
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _travellers.isEmpty
              ? Center(
                  child: Text(
                    l10n.savedTravellersEmpty,
                    style: AppTypography.body
                        .copyWith(color: AppColors.textMuted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: _travellers.length,
                  itemBuilder: (context, i) {
                    final traveller = _travellers[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        [traveller.firstName, traveller.lastName]
                            .whereType<String>()
                            .join(' '),
                        style: AppTypography.body,
                      ),
                      subtitle: Text(
                        _maskedDocument(traveller.documentNumber),
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          PhosphorIconsLight.trash,
                          color: AppColors.error,
                        ),
                        onPressed: () async {
                          final id = traveller.savedId;
                          if (id == null || !await _confirm()) return;
                          await ref
                              .read(flightSavedTravellersStoreProvider)
                              .delete(id);
                          await _reload();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
```

The project has no shared cancel key — the existing ones are scoped per dialog (`profileLogoutCancel`, `tripDetailOpenMapsCancel`), so this screen adds its own in the same style.

- [ ] **Step 3: Add the route and the profile entry**

In `profile_routes.dart`:

```dart
  static const savedTravellers = '/profile/saved-travellers';
```

```dart
      GoRoute(
        path: ProfileRoutes.savedTravellers,
        builder: (context, state) => const SavedTravellersScreen(),
      ),
```

Add a row to `profile_screen.dart` matching the existing menu rows, pointing at that route.

- [ ] **Step 4: Verify and commit**

Run: `flutter gen-l10n && flutter analyze && flutter test`
Expected: clean.

Run the app, save a traveller from the passenger form, then delete it from the profile and confirm it no longer appears as a chip.

```bash
git add lib/features/profile lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "Manage Saved Flight Travellers From Profile"
```

---

## Task 11: Wire the wizard into the passenger step

**Files:**
- Modify: `lib/features/flight/presentation/flight_review_screen.dart`
- Modify: `lib/features/flight/presentation/flight_bundles_screen.dart`

- [ ] **Step 1: Point both Continue actions at passengers**

In `flight_review_screen.dart`, the CTA currently sends offers without bundles to `FlightRoutes.results`. Replace that branch:

```dart
                onPressed: () => context.push(
                  offer.haveBundles
                      ? FlightRoutes.bundles
                      : FlightRoutes.passengers,
                ),
```

In `flight_bundles_screen.dart`, replace the Continue destination:

```dart
                  onPressed: allChosen
                      ? () => context.push(FlightRoutes.passengers)
                      : null,
```

- [ ] **Step 2: Verify the full chain**

Run: `flutter gen-l10n && flutter analyze && flutter test`
Expected: clean.

Run: `flutter run`. Walk an offer with bundles all the way: results → review → bundles → passengers, and confirm the step bar shows four nodes with the third active on the passenger screen. Repeat with an offer without bundles and confirm three nodes and that review goes straight to passengers.

- [ ] **Step 3: Commit**

```bash
git add lib/features/flight/presentation
git commit -m "Reach Passenger Step From Review And Bundles"
```

---

## Done when

- [ ] `flutter analyze` is clean and `flutter test` passes
- [ ] Task 1's answer is recorded in the flow spec and `kPassengerCountryCodeWidth` matches it
- [ ] A 2 adult + 1 child booking submits and returns a new offer id
- [ ] A rejected passenger shows its message on the right row, not a general banner
- [ ] Saved travellers survive an app restart and can be deleted from the profile
- [ ] Opening `/flight/passengers` with no confirmed order bounces to results
