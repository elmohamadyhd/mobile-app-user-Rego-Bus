# Per-Passenger Email & Phone Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collect a unique email and phone for every flight passenger (adults, children, infants) instead of one shared booker contact.

**Architecture:** Move `email` / `phone` onto `FlightPassengerDraft`. Delete `FlightContactDetails` and the shared Contact details block on the passengers list. The passenger form owns the fields; completeness validation and the Continue gate require both on every draft; the passengers request body reads each traveller’s own values. Saved travellers persist email/phone with the rest of the draft JSON.

**Tech Stack:** Flutter, Riverpod (`Notifier`), Freezed + json_serializable, ARB / `flutter gen-l10n`, existing flight feature tests.

## Global Constraints

- Arabic-first / RTL: directional APIs; LTR `textDirection` on email/phone fields (same as today).
- No hardcoded user-facing strings — ARB keys only.
- Design tokens only (`AppSpacing`, `AppTypography`, etc.) — no new magic numbers.
- Phosphor Light icons only where icons appear (no Material chrome icons).
- Run `dart run build_runner build --delete-conflicting-outputs` after Freezed entity edits; never hand-edit `*.freezed.dart` / `*.g.dart`.
- Run `flutter gen-l10n` after ARB edits.
- Every passenger type requires non-empty email and phone (blank / whitespace = missing). No new format regex.
- Out of scope: payment/review redesign, email/phone format validation beyond non-empty, form layout redesign beyond adding the two fields.

## File map

| File | Role |
|------|------|
| `lib/features/flight/domain/entities/flight_passenger_draft.dart` | Add `email`/`phone`; delete `FlightContactDetails` |
| `lib/features/flight/domain/utils/flight_passenger_validation.dart` | Require email/phone for completeness |
| `lib/features/flight/data/flight_dto_mapper.dart` | Per-passenger email/phone in request body |
| `lib/features/flight/domain/repositories/flight_repository.dart` | Drop `contact` from `addPassengers` |
| `lib/features/flight/data/flight_repository_impl.dart` | Same |
| `test/features/flight/fake_flight_repository.dart` | Same; drop `lastContact` |
| `lib/features/flight/presentation/providers/flight_booking_providers.dart` | Drop `contact` / `setContactDetails` |
| `lib/features/flight/presentation/flight_passengers_screen.dart` | Remove shared contact UI; gate on drafts only |
| `lib/features/flight/presentation/flight_passenger_form_screen.dart` | Email + phone fields |
| `lib/features/flight/presentation/widgets/flight_passenger_row.dart` | Missing-field labels for email/phone |
| `lib/l10n/app_en.arb` / `app_ar.arb` | Field keys; remove unused contact section keys |
| `test/features/flight/domain/flight_passenger_validation_test.dart` | Completeness with email/phone |
| `test/features/flight/data/flight_passenger_body_test.dart` | Distinct per-passenger contact in body |

---

### Task 1: Domain — draft fields + validation

**Files:**
- Modify: `lib/features/flight/domain/entities/flight_passenger_draft.dart`
- Modify: `lib/features/flight/domain/utils/flight_passenger_validation.dart`
- Modify: `test/features/flight/domain/flight_passenger_validation_test.dart`
- Test: `test/features/flight/domain/flight_passenger_validation_test.dart`

**Interfaces:**
- Consumes: existing `FlightPassengerDraft` Freezed pattern
- Produces: `FlightPassengerDraft.email` / `.phone` as `String?`; `FlightPassengerField.email` / `.phone`; `FlightContactDetails` removed from this file

- [ ] **Step 1: Update the validation test helper and add failing completeness cases**

In `test/features/flight/domain/flight_passenger_validation_test.dart`, change `_adult` to include email/phone, and add tests:

```dart
FlightPassengerDraft _adult({
  String? documentNumber = '29001021234567',
  DateTime? birthDate,
  String? email = 'a@b.com',
  String? phone = '01090510796',
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
    addressCountryCode: 'EG',
    addressCityCode: 'CAI',
    addressLine1: 'Street 1',
    addressLine2: 'Apt 1',
    email: email,
    phone: phone,
  );
}
```

Inside the `completeness` group, add:

```dart
    test('a blank email is reported missing', () {
      expect(
        missingFlightPassengerFields(_adult(email: null)),
        contains(FlightPassengerField.email),
      );
    });

    test('a blank phone is reported missing', () {
      expect(
        missingFlightPassengerFields(_adult(phone: '  ')),
        contains(FlightPassengerField.phone),
      );
    });
```

Keep existing completeness tests — they will fail until `_adult`’s new fields are on the entity **and** validation requires them (after Step 3 they pass with the helper defaults).

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
flutter test test/features/flight/domain/flight_passenger_validation_test.dart
```

Expected: FAIL — `email`/`phone` not on `FlightPassengerDraft` and/or `FlightPassengerField` missing those enum values.

- [ ] **Step 3: Update the entity**

Replace `lib/features/flight/domain/entities/flight_passenger_draft.dart` with:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';

part 'flight_passenger_draft.freezed.dart';
part 'flight_passenger_draft.g.dart';

/// One traveller as the rider has filled them in so far. Every field is
/// nullable because a draft is valid at any stage of completion — the list
/// screen renders progress from exactly this.
///
/// [savedId] is set only for travellers persisted to secure storage.
///
/// Email and phone are per traveller (the passengers endpoint accepts them
/// on each entry).
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
    /// Address is required by the live passengers endpoint (Phase 3 Task 1).
    String? addressCountryCode,
    String? addressCityCode,
    String? addressLine1,
    String? addressLine2,
    String? email,
    String? phone,
  }) = _FlightPassengerDraft;

  factory FlightPassengerDraft.fromJson(Map<String, dynamic> json) =>
      _$FlightPassengerDraftFromJson(json);
}
```

Delete the entire `FlightContactDetails` class from this file.

- [ ] **Step 4: Require email/phone in validation**

In `lib/features/flight/domain/utils/flight_passenger_validation.dart`:

1. Add `email` and `phone` to the end of `FlightPassengerField` (after `addressLine2`).
2. Append to `missingFlightPassengerFields`:

```dart
    if (_blank(draft.email)) FlightPassengerField.email,
    if (_blank(draft.phone)) FlightPassengerField.phone,
```

- [ ] **Step 5: Regenerate Freezed code**

Run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: succeeds; `flight_passenger_draft.freezed.dart` / `.g.dart` include `email` / `phone`; no `FlightContactDetails`.

- [ ] **Step 6: Run validation tests**

Run:

```bash
flutter test test/features/flight/domain/flight_passenger_validation_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/flight/domain/entities/flight_passenger_draft.dart \
  lib/features/flight/domain/utils/flight_passenger_validation.dart \
  test/features/flight/domain/flight_passenger_validation_test.dart
git commit -m "$(cat <<'EOF'
feat(flight): require per-passenger email and phone on drafts

EOF
)"
```

(Include generated Freezed outputs only if this repo tracks them; they are gitignored here — do not force-add.)

---

### Task 2: Mapper + repository — stop sharing contact

**Files:**
- Modify: `lib/features/flight/data/flight_dto_mapper.dart` (passengersRequestBody)
- Modify: `lib/features/flight/domain/repositories/flight_repository.dart`
- Modify: `lib/features/flight/data/flight_repository_impl.dart`
- Modify: `test/features/flight/fake_flight_repository.dart`
- Modify: `test/features/flight/data/flight_passenger_body_test.dart`
- Test: `test/features/flight/data/flight_passenger_body_test.dart`

**Interfaces:**
- Consumes: `FlightPassengerDraft.email` / `.phone` from Task 1
- Produces:
  - `FlightDtoMapper.passengersRequestBody({ required List<FlightPassengerDraft> passengers })` — no `contact`
  - `FlightRepository.addPassengers({ required String offerId, required List<FlightPassengerDraft> passengers })`
  - Fake: `lastPassengers` only (remove `lastContact`)

- [ ] **Step 1: Rewrite the body test to assert per-passenger contact**

Replace `test/features/flight/data/flight_passenger_body_test.dart` contents with:

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
  addressCountryCode: 'EG',
  addressCityCode: 'CAI',
  addressLine1: 'Street 1',
  addressLine2: 'Apt 1',
  email: 'mona@example.com',
  phone: '01090510796',
);

void main() {
  test('builds one entry per passenger with that traveller email and phone', () {
    final second = _mona.copyWith(
      firstName: 'Omar',
      email: 'omar@example.com',
      phone: '01111111111',
    );
    final body = FlightDtoMapper.passengersRequestBody(
      passengers: [_mona, second],
    );
    final list = body['passengers'] as List;
    expect(list, hasLength(2));

    final first = list.first as Map<String, dynamic>;
    expect(first['title'], 'MRS');
    expect(first['firstName'], 'Mona');
    expect(first['birthDate'], '1992-03-14');
    expect(first['passengerTypeCode'], 'ADT');
    expect(first['nationalityCountryCode'], 'EGY');
    expect(first['email'], 'mona@example.com');
    expect(first['phone'], '01090510796');
    expect(first['address'], {
      'countryCode': 'EG',
      'cityCode': 'CAI',
      'line1': 'Street 1',
      'line2': 'Apt 1',
    });

    final other = list[1] as Map<String, dynamic>;
    expect(other['email'], 'omar@example.com');
    expect(other['phone'], '01111111111');
  });

  test('a null middle name is sent as an empty string, not omitted', () {
    final body = FlightDtoMapper.passengersRequestBody(
      passengers: [_mona.copyWith(middleName: null)],
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
    );
    expect(
      (body['passengers'] as List)
          .map((p) => (p as Map)['passengerTypeCode'])
          .toList(),
      ['ADT', 'CHD', 'INF'],
    );
  });

  test('null email and phone are sent as empty strings', () {
    final body = FlightDtoMapper.passengersRequestBody(
      passengers: [_mona.copyWith(email: null, phone: null)],
    );
    final first = (body['passengers'] as List).first as Map<String, dynamic>;
    expect(first['email'], '');
    expect(first['phone'], '');
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

- [ ] **Step 2: Run body tests — expect fail**

Run:

```bash
flutter test test/features/flight/data/flight_passenger_body_test.dart
```

Expected: FAIL — `passengersRequestBody` still requires `contact` and/or ignores draft email/phone.

- [ ] **Step 3: Update the mapper**

In `lib/features/flight/data/flight_dto_mapper.dart`, replace `passengersRequestBody` with:

```dart
  /// Builds the `POST /flights/{offer_id}/passengers` body.
  ///
  /// Email and phone are taken from each traveller draft.
  ///
  /// Address is required by the live backend (Phase 3 Task 1 spike).
  static Map<String, dynamic> passengersRequestBody({
    required List<FlightPassengerDraft> passengers,
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
            'email': p.email ?? '',
            'phone': p.phone ?? '',
            'passengerTypeCode': flightPassengerWireCode(p.type),
            'address': {
              'countryCode': p.addressCountryCode ?? '',
              'cityCode': p.addressCityCode ?? '',
              'line1': p.addressLine1 ?? '',
              'line2': p.addressLine2 ?? '',
            },
          },
      ],
    };
  }
```

- [ ] **Step 4: Drop `contact` from repository API**

`lib/features/flight/domain/repositories/flight_repository.dart`:

```dart
  Future<String> addPassengers({
    required String offerId,
    required List<FlightPassengerDraft> passengers,
  });
```

`lib/features/flight/data/flight_repository_impl.dart`:

```dart
  @override
  Future<String> addPassengers({
    required String offerId,
    required List<FlightPassengerDraft> passengers,
  }) {
    return _guard(() async {
      final body = await _api.addPassengers(
        offerId: offerId,
        body: FlightDtoMapper.passengersRequestBody(
          passengers: passengers,
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

`test/features/flight/fake_flight_repository.dart`:
- Remove `FlightContactDetails? lastContact;`
- Change `addPassengers` to:

```dart
  @override
  Future<String> addPassengers({
    required String offerId,
    required List<FlightPassengerDraft> passengers,
  }) {
    lastPassengers = passengers;
    if (addPassengersException != null) throw addPassengersException!;
    return Future.value(addPassengersResult ?? offerId);
  }
```

- [ ] **Step 5: Run body tests**

Run:

```bash
flutter test test/features/flight/data/flight_passenger_body_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/flight/data/flight_dto_mapper.dart \
  lib/features/flight/domain/repositories/flight_repository.dart \
  lib/features/flight/data/flight_repository_impl.dart \
  test/features/flight/fake_flight_repository.dart \
  test/features/flight/data/flight_passenger_body_test.dart
git commit -m "$(cat <<'EOF'
feat(flight): send each passenger email and phone on submit

EOF
)"
```

---

### Task 3: Booking provider — remove shared contact state

**Files:**
- Modify: `lib/features/flight/presentation/providers/flight_booking_providers.dart`
- (Analyzer will also flag call sites fixed in Task 4)

**Interfaces:**
- Consumes: Task 2 `addPassengers` without `contact`
- Produces: `FlightBookingState` without `contact`; no `setContactDetails`

- [ ] **Step 1: Strip contact from state and notifier**

In `lib/features/flight/presentation/providers/flight_booking_providers.dart`:

1. Remove the field:
   ```dart
   @Default(FlightContactDetails()) FlightContactDetails contact,
   ```
2. In `selectOffer`, remove:
   ```dart
   contact: const FlightContactDetails(),
   ```
3. Delete the entire `setContactDetails` method.
4. In `submitPassengers`, change the repo call to:

```dart
      final newOfferId = await _repo.addPassengers(
        offerId: offerId,
        passengers: state.passengerDrafts,
      );
```

5. Remove any unused import of `FlightContactDetails` if it becomes unused (the draft import stays for `FlightPassengerDraft`).

- [ ] **Step 2: Regenerate Freezed for booking state if annotated**

If `FlightBookingState` is Freezed in this file (or a sibling), run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

If it is a plain class / `@freezed` in the same providers file, regenerate accordingly. Expected: no references to `contact` remain on the state type.

- [ ] **Step 3: Analyze provider + repo compile surface**

Run:

```bash
flutter analyze lib/features/flight/presentation/providers/flight_booking_providers.dart \
  lib/features/flight/domain/repositories/flight_repository.dart \
  lib/features/flight/data/flight_repository_impl.dart
```

Expected: no errors in those files. Errors in `flight_passengers_screen.dart` about `contact` / `setContactDetails` are OK until Task 4.

- [ ] **Step 4: Commit**

```bash
git add lib/features/flight/presentation/providers/flight_booking_providers.dart
git commit -m "$(cat <<'EOF'
refactor(flight): drop shared contact from booking state

EOF
)"
```

---

### Task 4: L10n + UI — form fields, list cleanup, missing labels

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ar.arb`
- Modify: `lib/features/flight/presentation/flight_passenger_form_screen.dart`
- Modify: `lib/features/flight/presentation/flight_passengers_screen.dart`
- Modify: `lib/features/flight/presentation/widgets/flight_passenger_row.dart`

**Interfaces:**
- Consumes: `FlightPassengerField.email` / `.phone`; draft `email`/`phone`; provider without contact
- Produces: form writes email/phone onto draft; list Continue = all drafts complete; row can say Missing Email/Phone

- [ ] **Step 1: ARB updates**

In `lib/l10n/app_en.arb`:
- Delete keys `flightContactSection`, `flightContactOnce` and their `@` metadata blocks.
- Keep `flightContactEmail` / `flightContactPhone` (form labels).
- After `flightFieldAddressLine2` block, add:

```json
  "flightFieldEmail": "email",
  "@flightFieldEmail": {
    "description": "Passenger field name: email address."
  },
  "flightFieldPhone": "phone",
  "@flightFieldPhone": {
    "description": "Passenger field name: phone number."
  },
```

In `lib/l10n/app_ar.arb`:
- Delete `flightContactSection`, `flightContactOnce`.
- Keep `flightContactEmail` / `flightContactPhone`.
- After `flightFieldAddressLine2`, add:

```json
  "flightFieldEmail": "الإيميل",
  "flightFieldPhone": "الموبايل",
```

Run:

```bash
flutter gen-l10n
```

Expected: codegen succeeds; no getters for deleted keys.

- [ ] **Step 2: Passenger row missing labels**

In `lib/features/flight/presentation/widgets/flight_passenger_row.dart`, extend `_fieldLabel` switch:

```dart
      FlightPassengerField.addressLine2 => l10n.flightFieldAddressLine2,
      FlightPassengerField.email => l10n.flightFieldEmail,
      FlightPassengerField.phone => l10n.flightFieldPhone,
```

- [ ] **Step 3: Add email/phone fields to the form**

In `lib/features/flight/presentation/flight_passenger_form_screen.dart`, after the `addressLine2` `TextFormField` and **before** the `CheckboxListTile` for save-for-next-time, insert:

```dart
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: _draft.email,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: l10n.flightContactEmail,
              errorText: errors['email'],
            ),
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(email: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: _draft.phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: l10n.flightContactPhone,
              errorText: errors['phone'],
            ),
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(phone: v)),
          ),
```

Saving the draft (including “save for next time”) already persists the whole Freezed JSON — no store changes needed once fields exist on the draft.

- [ ] **Step 4: Strip shared contact from the list screen**

In `lib/features/flight/presentation/flight_passengers_screen.dart`:

1. Replace Continue gating with:

```dart
    final allComplete =
        drafts.isNotEmpty && drafts.every(isFlightPassengerComplete);
    final canContinue = allComplete;
```

(Remove `contactFilled`.)

2. Replace the `ListView` `children` so they start with the passenger rows only — delete the Contact section `Text`s and both contact `TextFormField`s and their spacers. Keep:

```dart
                    children: [
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
```

3. Remove unused imports if any (e.g. nothing contact-specific beyond draft/validation already used).

- [ ] **Step 5: Analyze + targeted tests**

Run:

```bash
flutter analyze lib/features/flight lib/l10n
flutter test test/features/flight/domain/flight_passenger_validation_test.dart \
  test/features/flight/data/flight_passenger_body_test.dart
```

Expected: no analyzer errors in flight feature; both test files PASS.

If any other flight tests construct complete drafts without email/phone, add `email`/`phone` to those fixtures the same way as `_adult` / `_mona`.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_ar.arb \
  lib/features/flight/presentation/flight_passenger_form_screen.dart \
  lib/features/flight/presentation/flight_passengers_screen.dart \
  lib/features/flight/presentation/widgets/flight_passenger_row.dart
git commit -m "$(cat <<'EOF'
feat(flight): collect email and phone on each passenger form

EOF
)"
```

(Include generated `app_localizations*.dart` only if tracked in this repo.)

---

## Self-review (plan)

1. **Coverage:** Per-passenger required contact (all types) → Task 1; API body → Task 2; remove shared state → Task 3; form/list/l10n → Task 4; saved travellers via draft JSON → Task 4 Step 3 note.
2. **Placeholders:** None — concrete code and commands in every step.
3. **Types:** `String? email`/`phone` on draft; mapper `p.email ?? ''`; repo `addPassengers` without `contact`; enum `FlightPassengerField.email`/`phone` consistent across tasks.

---
