# Trip Results Stops Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let riders open a bottom sheet from the results card stops count, Apply boarding + drop-off picks onto that card, then Select into booking with those stops seeded.

**Architecture:** Card-local `selectedFrom` / `selectedTo` on a Stateful `TripCard`; new `showTripStopsSheet` for draft picks; `selectTrip(trip, {from, to})` seeds the notifier without overwriting valid user ids on enrichment.

**Tech Stack:** Flutter, Riverpod `BusBookingNotifier`, Freezed `BusStop` / `BusTripSummary`, `showModalBottomSheet`, `flutter_test`, ARB + `flutter gen-l10n`.

## Global Constraints

- Follow `docs/superpowers/specs/2026-07-29-trip-results-stops-picker-design.md` exactly — no scope creep.
- Package imports (`package:safaria/...`); design tokens only; RTL-safe / no Latin+Arabic string concat.
- Icons via `AppIcons`; strings via `AppLocalizations`.
- TDD for notifier + sheet + card interaction; `flutter gen-l10n` after ARB edits.
- Keep ticket `TicketBorder` geometry unchanged.
- Do not commit unless the user asks (skip Step “Commit” or leave staged only).

## File map

| File | Responsibility |
|---|---|
| `lib/l10n/app_en.arb`, `app_ar.arb` | `tripResultsStopsSheetTitle`, `tripResultsStopsApply` |
| `lib/features/bus/presentation/providers/bus_booking_providers.dart` | Optional `from`/`to` on `selectTrip` + enrichment keep rule |
| `lib/features/bus/presentation/widgets/trip_stops_sheet.dart` | Sheet UI + `showTripStopsSheet` |
| `lib/features/bus/presentation/widgets/trip_card.dart` | Local picks, tappable stops, display/fare from selection, `onSelect` |
| `lib/features/bus/presentation/trip_results_screen.dart` | Pass picks into `_selectTrip` |
| Tests under `test/features/bus/...` | Mirror above |

---

### Task 1: Localization keys

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ar.arb`

**Interfaces:**
- Produces: `AppLocalizations.tripResultsStopsSheetTitle`, `.tripResultsStopsApply`

- [ ] **Step 1: Add English keys** (near existing `tripResultsStopsCount`)

```json
  "tripResultsStopsSheetTitle": "Stops",
  "@tripResultsStopsSheetTitle": {
    "description": "Title of the trip results stops picker bottom sheet."
  },
  "tripResultsStopsApply": "Apply",
  "@tripResultsStopsApply": {
    "description": "Primary CTA on the trip results stops picker sheet."
  },
```

- [ ] **Step 2: Add Arabic keys**

```json
  "tripResultsStopsSheetTitle": "المحطات",
  "tripResultsStopsApply": "تطبيق",
```

- [ ] **Step 3: Generate l10n**

Run: `flutter gen-l10n`  
Expected: succeeds; generated getters exist.

---

### Task 2: `selectTrip` optional from/to + enrichment keep

**Files:**
- Modify: `lib/features/bus/presentation/providers/bus_booking_providers.dart`
- Modify: `test/features/bus/bus_booking_notifier_test.dart`

**Interfaces:**
- Consumes: `BusTripSummary`, `BusStop`
- Produces:
  ```dart
  Future<void> selectTrip(
    BusTripSummary trip, {
    BusStop? from,
    BusStop? to,
  })
  ```

- [ ] **Step 1: Write failing notifier tests**

Add to `bus_booking_notifier_test.dart` (reuse `FakeBusRepository.sampleTrip` which has multiple drop-offs):

```dart
test('selectTrip seeds explicit from/to when provided', () async {
  final trip = FakeBusRepository.sampleTrip;
  final from = trip.boardingStops.first;
  final to = trip.dropoffStops.first; // not necessarily terminal
  final container = makeContainer(FakeBusRepository());
  final notifier = container.read(busBookingProvider.notifier);

  await notifier.selectTrip(trip, from: from, to: to);

  final state = container.read(busBookingProvider);
  expect(state.fromStop?.locationId, from.locationId);
  expect(state.toStop?.locationId, to.locationId);
  expect(state.segmentFare, to.finalPrice);
});

test('selectTrip without from/to keeps terminal drop-off default', () async {
  final trip = FakeBusRepository.sampleTrip;
  final container = makeContainer(FakeBusRepository());
  final notifier = container.read(busBookingProvider.notifier);

  await notifier.selectTrip(trip);

  final state = container.read(busBookingProvider);
  expect(state.fromStop?.locationId, trip.defaultBoardingStop.locationId);
  expect(state.toStop?.locationId, trip.terminalDropoffStop.locationId);
});
```

- [ ] **Step 2: Run tests — expect FAIL** (if signature missing) or adjust until red on seeding behavior

Run: `flutter test test/features/bus/bus_booking_notifier_test.dart --name "selectTrip seeds explicit"`

- [ ] **Step 3: Implement `selectTrip`**

Replace the seed block in `selectTrip` with:

```dart
Future<void> selectTrip(
  BusTripSummary trip, {
  BusStop? from,
  BusStop? to,
}) async {
  final seedFrom = from ?? trip.defaultBoardingStop;
  final seedTo = to ?? trip.terminalDropoffStop;
  state = state.copyWith(
    status: BusBookingStatus.loadingDetail,
    selectedTrip: trip,
    fromStop: seedFrom,
    toStop: seedTo,
    segmentFare: seedTo.finalPrice,
    selectedSeats: [],
    seatMap: null,
    error: null,
  );

  try {
    final currency = state.searchParams?.currency ?? BusCurrency.defaultCode;
    final detail = await _repo.tripById(trip.id, currency: currency);
    if (detail.id.isNotEmpty) {
      final merged = trip.mergeEnrichment(detail);
      final keptFrom = _keepStopIfPresent(
        state.fromStop,
        merged.boardingStops,
        fallback: merged.defaultBoardingStop,
      );
      final keptTo = _keepStopIfPresent(
        state.toStop,
        merged.dropoffStops,
        fallback: merged.terminalDropoffStop,
      );
      state = state.copyWith(
        selectedTrip: merged,
        fromStop: keptFrom,
        toStop: keptTo,
        segmentFare: keptTo.finalPrice,
      );
    }
  } catch (_) {
    // Background enrichment is best-effort.
  } finally {
    if (state.status == BusBookingStatus.loadingDetail) {
      state = state.copyWith(status: BusBookingStatus.idle);
    }
  }
}

BusStop _keepStopIfPresent(
  BusStop? seeded,
  List<BusStop> candidates, {
  required BusStop fallback,
}) {
  if (seeded == null || seeded.locationId.isEmpty) return fallback;
  for (final stop in candidates) {
    if (stop.locationId == seeded.locationId) return stop;
  }
  return fallback;
}
```

Place `_keepStopIfPresent` as a private top-level function in the same file or a private method on the notifier class.

- [ ] **Step 4: Run notifier tests**

Run: `flutter test test/features/bus/bus_booking_notifier_test.dart`  
Expected: PASS (including existing `selectTrip seeds terminal drop-off` tests).

---

### Task 3: Stops sheet widget

**Files:**
- Create: `lib/features/bus/presentation/widgets/trip_stops_sheet.dart`
- Create: `test/features/bus/presentation/trip_stops_sheet_test.dart`

**Interfaces:**
- Produces:
  ```dart
  Future<({BusStop from, BusStop to})?> showTripStopsSheet(
    BuildContext context, {
    required BusTripSummary trip,
    required BusStop initialFrom,
    required BusStop initialTo,
  });
  ```
  - Returns record on Apply; `null` on dismiss.

- [ ] **Step 1: Write failing sheet tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/bus/domain/entities/bus_stop.dart';
import 'package:safaria/features/bus/domain/entities/bus_trip.dart';
import 'package:safaria/features/bus/presentation/widgets/trip_stops_sheet.dart';
import 'package:safaria/l10n/app_localizations.dart';

BusTripSummary _trip() {
  final board = BusStop(
    locationId: '1',
    name: 'Ramsis',
    cityId: 1,
    cityName: 'Cairo',
    arrivalAt: DateTime(2026, 2, 10, 8),
  );
  final board2 = board.copyWith(locationId: '2', name: 'Giza');
  final drop = BusStop(
    locationId: '9',
    name: 'Sidi Gaber',
    cityId: 2,
    cityName: 'Alexandria',
    arrivalAt: DateTime(2026, 2, 10, 11, 30),
    finalPrice: 180,
  );
  final drop2 = drop.copyWith(
    locationId: '10',
    name: 'Moharam Bek',
    arrivalAt: DateTime(2026, 2, 10, 12, 45),
    finalPrice: 250,
  );
  return BusTripSummary(
    id: '290545',
    gatewayId: 'Tazcara',
    operatorName: 'Go Bus',
    category: 'VIP',
    dateTime: DateTime(2026, 2, 10, 8),
    currency: 'EGP',
    defaultBoardingStop: board,
    defaultDropoffStop: drop,
    boardingStops: [board, board2],
    dropoffStops: [drop, drop2],
  );
}

void main() {
  testWidgets('Apply returns selected boarding and drop-off', (tester) async {
    final trip = _trip();
    ({BusStop from, BusStop to})? result;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showTripStopsSheet(
                  context,
                  trip: trip,
                  initialFrom: trip.defaultBoardingStop,
                  initialTo: trip.terminalDropoffStop,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Stops'), findsOneWidget);
    await tester.tap(find.text('Giza'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sidi Gaber'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(result?.from.locationId, '2');
    expect(result?.to.locationId, '9');
  });
}
```

- [ ] **Step 2: Run test — expect FAIL** (missing library)

Run: `flutter test test/features/bus/presentation/trip_stops_sheet_test.dart`

- [ ] **Step 3: Implement sheet**

Create `trip_stops_sheet.dart`:

- `showTripStopsSheet` → `showModalBottomSheet<({BusStop from, BusStop to})>` with `isScrollControlled: true`.
- Stateful content: draft `from` / `to` initialized from `initialFrom` / `initialTo`.
- Board / drop lists via `orderTripRouteStops` (board-only / drop-only calls as in `RouteTimeline`).
- Section headers: `l10n.tripDetailBoardAt` / `l10n.tripDetailDropOffAt`.
- Title: `l10n.tripResultsStopsSheetTitle`.
- CTA: `FilledButton` / primary Material button labeled `l10n.tripResultsStopsApply`; `onPressed: null` until both `locationId`s non-empty.
- On Apply: `Navigator.pop(context, (from: draftFrom, to: draftTo))`.
- Row: name, city, optional time; drop-off shows fare with `trip.currency`.
- Tokens only; `SafeArea`; max height ~70% via `DraggableScrollableSheet` **or** simple `ConstrainedBox` + `SingleChildScrollView` (prefer ConstrainedBox for simplicity).

- [ ] **Step 4: Run sheet tests**

Run: `flutter test test/features/bus/presentation/trip_stops_sheet_test.dart`  
Expected: PASS.

---

### Task 4: TripCard local picks + tappable stops + `onSelect`

**Files:**
- Modify: `lib/features/bus/presentation/widgets/trip_card.dart`
- Modify: `test/features/bus/presentation/trip_card_test.dart`
- Modify: any call sites of `TripCard(onTap:` (results screen in Task 5; fix compile breaks here if tests construct `onTap`)

**Interfaces:**
- Consumes: `showTripStopsSheet`
- Produces:
  ```dart
  class TripCard extends StatefulWidget {
    const TripCard({
      super.key,
      required this.trip,
      required this.onSelect,
      this.loading = false,
    });
    final BusTripSummary trip;
    final void Function({required BusStop from, required BusStop to}) onSelect;
    final bool loading;
  }
  ```

- [ ] **Step 1: Update / add failing card tests**

Replace `onTap` with `onSelect` in `_pumpCard` helpers.

Add:

```dart
testWidgets('tapping stops count opens sheet without selecting trip',
    (tester) async {
  var selected = 0;
  await _pumpCard(
    tester,
    _buildTrip(),
    onSelect: ({required from, required to}) => selected++,
  );

  await tester.tap(find.text('4 stops'));
  await tester.pumpAndSettle();

  expect(find.text('Stops'), findsOneWidget);
  expect(selected, 0);
});

testWidgets('Apply updates fare and Select returns chosen pair', (tester) async {
  BusStop? selectedFrom;
  BusStop? selectedTo;
  await _pumpCard(
    tester,
    _buildTrip(),
    onSelect: ({required from, required to}) {
      selectedFrom = from;
      selectedTo = to;
    },
  );

  await tester.tap(find.text('4 stops'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Giza'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sidi Gaber'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Apply'));
  await tester.pumpAndSettle();

  expect(find.text('Giza'), findsWidgets);
  expect(find.textContaining('180', findRichText: true), findsWidgets);

  await tester.tap(find.text('Select'));
  await tester.pumpAndSettle();

  expect(selectedFrom?.locationId, '2');
  expect(selectedTo?.locationId, '9');
});
```

Fix existing taps: `find.byType(TripCard)` still OK if whole-card InkWell calls `onSelect` with current picks.

- [ ] **Step 2: Run card tests — expect FAIL** on new API / missing sheet wiring

Run: `flutter test test/features/bus/presentation/trip_card_test.dart`

- [ ] **Step 3: Implement Stateful TripCard**

- Convert to `StatefulWidget`; in `initState` / `didUpdateWidget` when `trip.id` changes, reset:
  - `_from = trip.defaultBoardingStop`
  - `_to = trip.terminalDropoffStop`
- Display times/cities/names/fare/duration from `_from` / `_to` (add small helpers mirroring `terminalDurationLabel` for the pair).
- Wrap stops count `Text` in `InkWell` (when `stopsCount > 0`) that calls `showTripStopsSheet` and `setState` on non-null result.
- Card `InkWell` / Select button call:
  `widget.onSelect(from: _from, to: _to)`.
- Prefer `ValueKey(trip.id)` at the **call site** (Task 5).

Duration label: keep `LtrText(duration)` + separate stops text (BiDi).

- [ ] **Step 4: Run card + sheet tests**

Run:
`flutter test test/features/bus/presentation/trip_card_test.dart test/features/bus/presentation/trip_stops_sheet_test.dart`  
Expected: PASS.

---

### Task 5: Wire results screen

**Files:**
- Modify: `lib/features/bus/presentation/trip_results_screen.dart`
- Modify: `test/features/bus/presentation/trip_results_screen_test.dart` (only if it constructs `TripCard` / selects trips — update signatures)

**Interfaces:**
- Consumes: `TripCard.onSelect`, `selectTrip(trip, from:, to:)`

- [ ] **Step 1: Update list item**

```dart
itemBuilder: (context, i) => TripCard(
  key: ValueKey(trips[i].id),
  trip: trips[i],
  loading: _loadingTripId == trips[i].id,
  onSelect: ({required from, required to}) =>
      _selectTrip(trips[i], from: from, to: to),
),
```

- [ ] **Step 2: Update `_selectTrip`**

```dart
Future<void> _selectTrip(
  BusTripSummary trip, {
  required BusStop from,
  required BusStop to,
}) async {
  if (_loadingTripId != null) return;
  setState(() => _loadingTripId = trip.id);
  await ref.read(busBookingProvider.notifier).selectTrip(
        trip,
        from: from,
        to: to,
      );
  if (!mounted) return;
  setState(() => _loadingTripId = null);
  unawaited(context.push(BusRoutes.detail));
}
```

Add import for `BusStop` if missing.

- [ ] **Step 3: Run results + related tests**

Run:
```
flutter test test/features/bus/presentation/trip_results_screen_test.dart test/features/bus/presentation/trip_card_test.dart test/features/bus/bus_booking_notifier_test.dart
```
Expected: PASS.

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/features/bus`  
Expected: No issues.

---

## Spec coverage checklist

| Spec requirement | Task |
|---|---|
| l10n sheet title + Apply | Task 1 |
| `selectTrip` optional from/to | Task 2 |
| Enrichment keeps valid seeded ids | Task 2 |
| Bottom sheet boarding + drop-off + Apply | Task 3 |
| Dismiss discards draft | Task 3 |
| Tappable stops count, no Select | Task 4 |
| Apply updates card display/fare | Task 4 |
| Select passes Applied pair | Task 4 / 5 |
| `ValueKey(trip.id)` on list cards | Task 5 |
| Ticket shape unchanged | Task 4 (no `TicketBorder` edits) |
| RTL separate widgets for duration/stops | Task 4 |
| Out of scope: no Maps in sheet, no RouteTimeline embed | Task 3 |

## Plan self-review

- Spec coverage: all in-scope rows mapped; out-of-scope not tasked.
- No TBD/placeholder steps.
- `onSelect` / `showTripStopsSheet` / `selectTrip` signatures consistent across tasks.
- Commit steps omitted per repo preference unless user requests commits later.
