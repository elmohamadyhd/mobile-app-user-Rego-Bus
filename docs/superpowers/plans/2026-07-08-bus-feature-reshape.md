# Bus Feature Reshape Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reshape today's bus-only `features/booking/` into a clean, self-contained `features/bus/` slice — bus-owned entity/provider names, a repository data boundary, federated routes, and no leaked flight fields — with behavior unchanged.

**Architecture:** Behavior-preserving refactor. This is Phase 1 of `docs/superpowers/specs/2026-07-08-multi-vehicle-architecture-design.md`. The redesigned bus screens and data model (stops, per-seat pricing) in `docs/superpowers/specs/2026-07-08-bus-flow-redesign-design.md` are a **separate follow-up plan** that builds on this one. Scope kept tight on purpose: this plan does not change any screen UI, route URL, or observable flow — only structure and names.

**Tech Stack:** Flutter, Riverpod (`Notifier`/`Provider`), Freezed + build_runner codegen, go_router. Tests via `flutter_test` + `ProviderContainer` (no mocking framework; hand-written fakes).

**Deferred to the redesign plan (out of scope here):** extracting `bus_search_form.dart` out of `home_search_card.dart`; renaming screen files to `bus_*`; moving route URLs to `/bus/*`; routing the static seat layout / wallet constants through the repository. These are all reworked when the screens are rebuilt, so touching them here would be wasted churn.

**Global rules for every task:**
- Run codegen after any change to a file containing `@freezed`: `dart run build_runner build --delete-conflicting-outputs`
- A task is "green" only when BOTH pass: `flutter analyze` (no errors) and `flutter test` (all pass).
- Generated `*.freezed.dart` / `*.g.dart` are gitignored — never stage them.

---

### Task 1: Move the feature directory `booking` → `bus`

**Files:**
- Move: `lib/features/booking/` → `lib/features/bus/`
- Move: `test/features/booking/` → `test/features/bus/`
- Modify (import paths only): every file importing `package:rego/features/booking/...`

- [ ] **Step 1: Move both directories on disk (keeps generated files with them)**

Run:
```bash
mv "lib/features/booking" "lib/features/bus"
mv "test/features/booking" "test/features/bus"
```

- [ ] **Step 2: Rewrite all import paths `features/booking` → `features/bus`**

Run:
```bash
grep -rl "features/booking" lib test | xargs sed -i "s#features/booking#features/bus#g"
```

- [ ] **Step 3: Regenerate codegen (part directives still reference in-dir filenames, unchanged)**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: build succeeds, no missing-part errors.

- [ ] **Step 4: Verify green**

Run: `flutter analyze && flutter test`
Expected: analyze clean; all tests pass (class names unchanged — only paths moved).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(bus): move booking feature dir to features/bus"
```

---

### Task 2: Rename trip/ticket entities to bus-owned names

Renames: `TripSummary`→`BusTripSummary`, `TripSummaryX`→`BusTripSummaryX`, `TripDetail`→`BusTripDetail`, `ETicket`→`BusTicket`. Files: `trip.dart`→`bus_trip.dart`, `booking.dart`→`bus_ticket.dart`. (`seat.dart` and its `SeatCell`/`SeatRow`/`SeatStatus` keep their names — they are already bus-generic.)

**Files:**
- Move: `lib/features/bus/domain/entities/trip.dart` → `bus_trip.dart`
- Move: `lib/features/bus/domain/entities/booking.dart` → `bus_ticket.dart`
- Modify: every file referencing those types (`mock_bus_data.dart`, `booking_providers.dart`, the 5 screens + widgets, `home_search_card.dart`, `test/features/bus/booking_notifier_test.dart`)

- [ ] **Step 1: Rename the entity files**

Run:
```bash
git mv "lib/features/bus/domain/entities/trip.dart" "lib/features/bus/domain/entities/bus_trip.dart"
git mv "lib/features/bus/domain/entities/booking.dart" "lib/features/bus/domain/entities/bus_ticket.dart"
```

- [ ] **Step 2: Update part directives and import paths for the renamed files**

Run:
```bash
sed -i "s#part 'trip.freezed.dart'#part 'bus_trip.freezed.dart'#" "lib/features/bus/domain/entities/bus_trip.dart"
sed -i "s#part 'booking.freezed.dart'#part 'bus_ticket.freezed.dart'#" "lib/features/bus/domain/entities/bus_ticket.dart"
grep -rl "entities/trip.dart" lib test | xargs sed -i "s#entities/trip.dart#entities/bus_trip.dart#g"
grep -rl "entities/booking.dart" lib test | xargs sed -i "s#entities/booking.dart#entities/bus_ticket.dart#g"
```

- [ ] **Step 3: Rename the class identifiers everywhere (plain substring — also fixes `_$`/`_` freezed variants)**

Run:
```bash
grep -rl "TripSummary" lib test | xargs sed -i "s/TripSummary/BusTripSummary/g"
grep -rl "TripDetail"  lib test | xargs sed -i "s/TripDetail/BusTripDetail/g"
grep -rl "ETicket"     lib test | xargs sed -i "s/ETicket/BusTicket/g"
```
Note: `TripSummaryX` becomes `BusTripSummaryX` and `_$TripSummary`/`_TripSummary` become `_$BusTripSummary`/`_BusTripSummary` automatically (substring match). `ETicketScreen` in the screen file becomes `BusTicketScreen` — that is fine and intended; Task 6 references the same new name.

- [ ] **Step 4: Delete stale generated files and regenerate**

Run:
```bash
rm -f lib/features/bus/domain/entities/trip.freezed.dart lib/features/bus/domain/entities/booking.freezed.dart
dart run build_runner build --delete-conflicting-outputs
```
Expected: generates `bus_trip.freezed.dart`, `bus_ticket.freezed.dart`.

- [ ] **Step 5: Verify green**

Run: `flutter analyze && flutter test`
Expected: analyze clean; all tests pass.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor(bus): rename Trip/ETicket entities to Bus-owned names"
```

---

### Task 3: Rename the notifier to `BusBooking*` and drop flight leakage

Renames: `BookingFlowState`→`BusBookingState`, `BookingFlowNotifier`→`BusBookingNotifier`, `BookingFlowStatus`→`BusBookingStatus`, `bookingFlowProvider`→`busBookingProvider`. File: `booking_providers.dart`→`bus_booking_providers.dart`. Removes the flight fields (`flightClass`, `isRoundTrip`, `searchReturnDate`) and simplifies `searchTrips`.

**Files:**
- Move: `lib/features/bus/presentation/providers/booking_providers.dart` → `bus_booking_providers.dart`
- Modify: `lib/features/home/presentation/widgets/home_search_card.dart` (the search call)
- Modify: the 5 bus screens + `test/features/bus/booking_notifier_test.dart` (identifier references)

- [ ] **Step 1: Rename the provider file and its part directive + import paths**

Run:
```bash
git mv "lib/features/bus/presentation/providers/booking_providers.dart" "lib/features/bus/presentation/providers/bus_booking_providers.dart"
sed -i "s#part 'booking_providers.freezed.dart'#part 'bus_booking_providers.freezed.dart'#" "lib/features/bus/presentation/providers/bus_booking_providers.dart"
grep -rl "providers/booking_providers.dart" lib test | xargs sed -i "s#providers/booking_providers.dart#providers/bus_booking_providers.dart#g"
```

- [ ] **Step 2: Rename the identifiers everywhere**

Run:
```bash
grep -rl "BookingFlowState"    lib test | xargs sed -i "s/BookingFlowState/BusBookingState/g"
grep -rl "BookingFlowNotifier" lib test | xargs sed -i "s/BookingFlowNotifier/BusBookingNotifier/g"
grep -rl "BookingFlowStatus"   lib test | xargs sed -i "s/BookingFlowStatus/BusBookingStatus/g"
grep -rl "bookingFlowProvider" lib test | xargs sed -i "s/bookingFlowProvider/busBookingProvider/g"
```

- [ ] **Step 3: Replace the provider file body (drops flight fields; simplifies `searchTrips`; keeps `Notifier` reading the mock directly for now — the repository lands in Task 5)**

Overwrite `lib/features/bus/presentation/providers/bus_booking_providers.dart` with:

```dart
// lib/features/bus/presentation/providers/bus_booking_providers.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rego/core/utils/date_formatting.dart';
import 'package:rego/features/bus/data/mock_bus_data.dart';
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';

part 'bus_booking_providers.freezed.dart';

enum BusBookingStatus {
  idle,
  loadingTrips,
  loadingDetail,
  confirming,
  confirmed,
  error,
}

enum PaymentMethod { wallet, card }

@freezed
abstract class BusBookingState with _$BusBookingState {
  const factory BusBookingState({
    @Default([]) List<BusTripSummary> trips,
    @Default(BusBookingStatus.idle) BusBookingStatus status,
    BusTripSummary? selectedTrip,
    BusTripDetail? tripDetail,
    @Default([]) List<String> selectedSeats,
    @Default('Ahmed Hassan') String passengerName,
    @Default('+20 10 1234 5678') String passengerPhone,
    @Default(PaymentMethod.wallet) PaymentMethod paymentMethod,
    BusTicket? ticket,
    String? error,
    String? searchFrom,
    String? searchTo,
    DateTime? searchDate,
  }) = _BusBookingState;
}

class BusBookingNotifier extends Notifier<BusBookingState> {
  @override
  BusBookingState build() => const BusBookingState();

  Future<void> searchTrips(String from, String to, String date) async {
    final parsedDate = parseIsoDate(date) ?? dateOnly(DateTime.now());
    state = state.copyWith(
      status: BusBookingStatus.loadingTrips,
      searchFrom: from,
      searchTo: to,
      searchDate: parsedDate,
    );
    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      state = state.copyWith(
        status: BusBookingStatus.idle,
        trips: MockBusData.trips,
      );
    } catch (e) {
      state = state.copyWith(
        status: BusBookingStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> selectTrip(BusTripSummary trip) async {
    state = state.copyWith(
      status: BusBookingStatus.loadingDetail,
      selectedTrip: trip,
      selectedSeats: [],
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    state = state.copyWith(
      status: BusBookingStatus.idle,
      tripDetail: MockBusData.detailFor(trip.id),
    );
  }

  void toggleSeat(String id) {
    final seats = List<String>.from(state.selectedSeats);
    if (seats.contains(id)) {
      seats.remove(id);
    } else {
      seats.add(id);
    }
    state = state.copyWith(selectedSeats: seats);
  }

  void setPaymentMethod(PaymentMethod method) {
    state = state.copyWith(paymentMethod: method);
  }

  Future<void> confirmBooking() async {
    final detail = state.tripDetail;
    if (detail == null) {
      state = state.copyWith(
        status: BusBookingStatus.error,
        error: 'No trip selected',
      );
      return;
    }
    state = state.copyWith(status: BusBookingStatus.confirming, error: null);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final bookingRef =
        'RG-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    final ticket = BusTicket(
      bookingRef: bookingRef,
      trip: detail,
      seats: List.unmodifiable(state.selectedSeats),
      passengerName: state.passengerName,
      gate: 'A3',
      issuedAt: DateTime.now(),
    );
    state = state.copyWith(
      status: BusBookingStatus.confirmed,
      ticket: ticket,
    );
  }

  void reset() => state = const BusBookingState();
}

final busBookingProvider =
    NotifierProvider<BusBookingNotifier, BusBookingState>(
        BusBookingNotifier.new);
```

- [ ] **Step 4: Fix the search call in `home_search_card.dart`**

In `lib/features/home/presentation/widgets/home_search_card.dart`, find the `searchTrips` call (currently passes `isRoundTrip`, `returnDate`, `flightClass`) and replace the whole call with the 3-arg form:

```dart
    await ref.read(busBookingProvider.notifier).searchTrips(
          _fromCity.apiName,
          _toCity.apiName,
          toIsoDate(_travelDate),
        );
```

Leave the rest of the widget (tabs, round-trip toggle UI, flight-class picker UI) untouched — those are home's UI concerns and get reworked in the redesign plan; they simply no longer feed the bus search.

- [ ] **Step 5: Regenerate and verify green**

Run:
```bash
rm -f lib/features/bus/presentation/providers/booking_providers.freezed.dart
dart run build_runner build --delete-conflicting-outputs
flutter analyze && flutter test
```
Expected: analyze clean (watch for unused-variable/import warnings from the removed flight fields — remove any now-dead local in `home_search_card.dart` if flagged); all tests pass. The existing `booking_notifier_test.dart` now exercises `busBookingProvider` and still passes (behavior unchanged).

- [ ] **Step 6: Rename the notifier test file to match**

Run:
```bash
git mv "test/features/bus/booking_notifier_test.dart" "test/features/bus/bus_booking_notifier_test.dart"
flutter test test/features/bus/bus_booking_notifier_test.dart
```
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor(bus): rename notifier to BusBooking and drop flight fields"
```

---

### Task 4: Rename the mock data source

Renames: `MockBookingData`→`MockBusData`. File: `mock_booking_data.dart`→`mock_bus_data.dart`.

**Files:**
- Move: `lib/features/bus/data/mock_booking_data.dart` → `mock_bus_data.dart`
- Modify: files referencing `MockBookingData` or the old path (`bus_booking_providers.dart`, any screen reading the seat layout/wallet constant)

- [ ] **Step 1: Rename file, path references, and identifier**

Run:
```bash
git mv "lib/features/bus/data/mock_booking_data.dart" "lib/features/bus/data/mock_bus_data.dart"
grep -rl "data/mock_booking_data.dart" lib test | xargs sed -i "s#data/mock_booking_data.dart#data/mock_bus_data.dart#g"
grep -rl "MockBookingData" lib test | xargs sed -i "s/MockBookingData/MockBusData/g"
```

- [ ] **Step 2: Verify green**

Run: `flutter analyze && flutter test`
Expected: analyze clean; all tests pass.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "refactor(bus): rename MockBookingData to MockBusData"
```

---

### Task 5: Introduce the `BusRepository` data boundary

Move the notifier's data access behind a repository interface + mock impl, injected via a provider (mirrors `authRepositoryProvider`). This is the one genuinely new piece of code, so it is TDD'd.

**Files:**
- Create: `lib/features/bus/domain/repositories/bus_repository.dart`
- Create: `lib/features/bus/data/bus_repository_impl.dart`
- Test: `test/features/bus/data/bus_repository_impl_test.dart`
- Modify: `lib/features/bus/presentation/providers/bus_booking_providers.dart`

- [ ] **Step 1: Write the failing repository test**

Create `test/features/bus/data/bus_repository_impl_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rego/features/bus/data/bus_repository_impl.dart';
import 'package:rego/features/bus/data/mock_bus_data.dart';

void main() {
  group('BusRepositoryImpl', () {
    test('searchTrips returns the mock trip list', () async {
      final repo = BusRepositoryImpl();
      final trips = await repo.searchTrips('Cairo', 'Alexandria', '2026-06-30');
      expect(trips, MockBusData.trips);
      expect(trips.length, 3);
    });

    test('tripDetail returns the detail for the given trip id', () async {
      final repo = BusRepositoryImpl();
      final trip = MockBusData.trips.first;
      final detail = await repo.tripDetail(trip.id);
      expect(detail.summary.id, trip.id);
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/bus/data/bus_repository_impl_test.dart`
Expected: FAIL — `BusRepositoryImpl` and its file do not exist yet.

- [ ] **Step 3: Create the repository interface**

Create `lib/features/bus/domain/repositories/bus_repository.dart`:

```dart
import 'package:rego/features/bus/domain/entities/bus_trip.dart';

abstract interface class BusRepository {
  Future<List<BusTripSummary>> searchTrips(String from, String to, String date);
  Future<BusTripDetail> tripDetail(String tripId);
}
```

- [ ] **Step 4: Create the mock-backed implementation**

Create `lib/features/bus/data/bus_repository_impl.dart`:

```dart
import 'package:rego/features/bus/data/mock_bus_data.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/domain/repositories/bus_repository.dart';

/// Mock-backed for now. When the live `/buses/*` API is wired, this gains a
/// `BusApi` dependency (via `dioProvider`) and maps DTOs to entities — the
/// notifier and providers do not change.
class BusRepositoryImpl implements BusRepository {
  @override
  Future<List<BusTripSummary>> searchTrips(
    String from,
    String to,
    String date,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return MockBusData.trips;
  }

  @override
  Future<BusTripDetail> tripDetail(String tripId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return MockBusData.detailFor(tripId);
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/bus/data/bus_repository_impl_test.dart`
Expected: PASS.

- [ ] **Step 6: Wire the notifier to the repository**

In `lib/features/bus/presentation/providers/bus_booking_providers.dart`:

Replace the mock import line
```dart
import 'package:rego/features/bus/data/mock_bus_data.dart';
```
with
```dart
import 'package:rego/features/bus/data/bus_repository_impl.dart';
import 'package:rego/features/bus/domain/repositories/bus_repository.dart';
```

Add the repository provider immediately above `@freezed abstract class BusBookingState`:
```dart
final busRepositoryProvider =
    Provider<BusRepository>((ref) => BusRepositoryImpl());
```

Add the repo accessor as the first line inside `class BusBookingNotifier`:
```dart
  BusRepository get _repo => ref.read(busRepositoryProvider);
```

In `searchTrips`, replace the delay+assignment block
```dart
      await Future<void>.delayed(const Duration(milliseconds: 600));
      state = state.copyWith(
        status: BusBookingStatus.idle,
        trips: MockBusData.trips,
      );
```
with
```dart
      final trips = await _repo.searchTrips(from, to, date);
      state = state.copyWith(status: BusBookingStatus.idle, trips: trips);
```

In `selectTrip`, replace
```dart
    await Future<void>.delayed(const Duration(milliseconds: 400));
    state = state.copyWith(
      status: BusBookingStatus.idle,
      tripDetail: MockBusData.detailFor(trip.id),
    );
```
with
```dart
    final detail = await _repo.tripDetail(trip.id);
    state = state.copyWith(status: BusBookingStatus.idle, tripDetail: detail);
```

(The seat layout and wallet constants are still read as `MockBusData` statics by the seat/summary screens — that is intentional; they move behind the repository in the redesign plan when those screens are rebuilt.)

- [ ] **Step 7: Regenerate and verify green (full suite, incl. the renamed notifier test)**

Run:
```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze && flutter test
```
Expected: analyze clean; all tests pass — `bus_booking_notifier_test.dart` still passes because `busRepositoryProvider` defaults to the same mock data.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor(bus): add BusRepository boundary behind the notifier"
```

---

### Task 6: Federate bus routes out of the app router

Move the bus route definitions into the feature and have the app router spread them. URL strings stay identical (behavior-preserving; the existing `app_router_test.dart` keeps passing).

**Files:**
- Create: `lib/features/bus/presentation/bus_routes.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: the 5 bus screens + `home_search_card.dart` (swap `AppRoutes.*` bus refs → `BusRoutes.*`)

- [ ] **Step 1: Create the federated route module**

Create `lib/features/bus/presentation/bus_routes.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/features/bus/presentation/trip_results_screen.dart';
import 'package:rego/features/bus/presentation/trip_details_screen.dart';
import 'package:rego/features/bus/presentation/seat_selection_screen.dart';
import 'package:rego/features/bus/presentation/passenger_confirm_screen.dart';
import 'package:rego/features/bus/presentation/eticket_screen.dart';

/// Bus booking route paths. URLs are unchanged from the pre-reshape router.
abstract final class BusRoutes {
  static const results = '/trips';
  static const detail = '/trips/detail';
  static const seats = '/trips/seats';
  static const confirm = '/trips/confirm';
  static const ticket = '/booking/ticket';
}

List<RouteBase> busRoutes() => [
      GoRoute(
        path: BusRoutes.results,
        builder: (context, state) => const TripResultsScreen(),
      ),
      GoRoute(
        path: BusRoutes.detail,
        builder: (context, state) => const TripDetailsScreen(),
      ),
      GoRoute(
        path: BusRoutes.seats,
        builder: (context, state) => const SeatSelectionScreen(),
      ),
      GoRoute(
        path: BusRoutes.confirm,
        builder: (context, state) => const PassengerConfirmScreen(),
      ),
      GoRoute(
        path: BusRoutes.ticket,
        builder: (context, state) => const BusTicketScreen(),
      ),
    ];
```

Note: the e-ticket screen class was renamed `ETicketScreen`→`BusTicketScreen` by Task 2's substring rename. If `flutter analyze` reports the class is still `ETicketScreen`, use that name instead — but Task 2 should have renamed it. Verify with `grep -n "class .*TicketScreen" lib/features/bus/presentation/eticket_screen.dart`.

- [ ] **Step 2: Swap bus route references in screens + home to `BusRoutes.*`**

Run:
```bash
grep -rl "AppRoutes.trips\|AppRoutes.tripDetail\|AppRoutes.tripSeats\|AppRoutes.tripConfirm\|AppRoutes.eTicket" lib \
  | xargs sed -i \
    -e "s/AppRoutes.tripDetail/BusRoutes.detail/g" \
    -e "s/AppRoutes.tripSeats/BusRoutes.seats/g" \
    -e "s/AppRoutes.tripConfirm/BusRoutes.confirm/g" \
    -e "s/AppRoutes.eTicket/BusRoutes.ticket/g" \
    -e "s/AppRoutes.trips/BusRoutes.results/g"
```
(Order matters: `tripDetail`/`tripSeats`/`tripConfirm` are replaced before the shorter `trips`, so `AppRoutes.trips` only matches the bare results route.)

- [ ] **Step 3: Add the `bus_routes.dart` import to each file that now uses `BusRoutes`**

Run:
```bash
grep -rL "presentation/bus_routes.dart" $(grep -rl "BusRoutes\." lib) \
  | xargs -r sed -i "0,/^import /s//import 'package:rego\/features\/bus\/presentation\/bus_routes.dart';\nimport /"
```
Then run `flutter analyze` and manually confirm each `BusRoutes` user imports `bus_routes.dart` exactly once; fix any file the script missed by hand. Screens that still use `AppRoutes.home` (e.g. the e-ticket screen) must keep their `app_router.dart` import too.

- [ ] **Step 4: Update `app_router.dart` — remove inline bus routes/constants, spread `busRoutes()`**

In `lib/core/router/app_router.dart`:

Remove the 5 bus screen imports:
```dart
import 'package:rego/features/booking/presentation/trip_results_screen.dart';
import 'package:rego/features/booking/presentation/trip_details_screen.dart';
import 'package:rego/features/booking/presentation/seat_selection_screen.dart';
import 'package:rego/features/booking/presentation/passenger_confirm_screen.dart';
import 'package:rego/features/booking/presentation/eticket_screen.dart';
```
(they were rewritten to `features/bus/...` in Task 1 — remove whichever path they currently show), and add:
```dart
import 'package:rego/features/bus/presentation/bus_routes.dart';
```

Remove these constants from `abstract final class AppRoutes`:
```dart
  static const trips = '/trips';
  static const tripDetail = '/trips/detail';
  static const tripSeats = '/trips/seats';
  static const tripConfirm = '/trips/confirm';
  static const eTicket = '/booking/ticket';
```

Replace the 5 inline bus `GoRoute(...)` entries (the block from `GoRoute(path: AppRoutes.trips ...)` through the e-ticket route, just before the final `],`) with a single line:
```dart
      ...busRoutes(),
```

- [ ] **Step 5: Regenerate and verify green**

Run:
```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze && flutter test
```
Expected: analyze clean (no dangling `AppRoutes.trips` references, no unused imports); all tests pass including `test/core/router/app_router_test.dart` (URLs unchanged).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor(bus): federate bus routes into the feature"
```

---

### Task 7: Full-flow verification

**Files:** none (verification only).

- [ ] **Step 1: Clean codegen + static + unit gate**

Run:
```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```
Expected: all clean/green.

- [ ] **Step 2: Confirm no `booking`-named bus artifacts remain**

Run:
```bash
grep -rn "features/booking\|BookingFlow\|MockBookingData\|\bTripSummary\b\|\bTripDetail\b\|\bETicket\b" lib test || echo "clean"
```
Expected: `clean` (only intended names remain; `SeatCell`/`SeatRow`/`SeatStatus` and `BusBooking*`/`Bus*` are fine).

- [ ] **Step 3: Drive the bus flow in the running app**

Run: `flutter run` (or the `/run` skill). Walk: Home → Buses tab → From/To + date → Find/Search → results list → a trip → seat selection → confirm → e-ticket. Confirm each screen renders and navigates exactly as before the reshape.

- [ ] **Step 4: Commit any final touch-ups**

```bash
git add -A
git commit -m "test(bus): verify reshaped bus flow end-to-end"
```

---

## What this plan deliberately does NOT do

- Change any screen layout, copy, or the booking UX (that is the redesign plan).
- Add the stops/segment-fare model, per-seat pricing, or new screens.
- Change route URLs or extract the search form from `home_search_card.dart`.

The immediate next plan — from `2026-07-08-bus-flow-redesign-design.md` — builds on this clean `features/bus/` slice.
