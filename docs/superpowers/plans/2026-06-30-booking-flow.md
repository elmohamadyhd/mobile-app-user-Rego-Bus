# Booking Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build 6 screens (Home rebuild + Trip results, Trip details, Seat selection, Passenger & confirm, E-ticket) implementing the core bus-booking journey from `design/V1`.

**Architecture:** Single `BookingFlowNotifier extends Notifier<BookingFlowState>` owns all booking state (selected trip, seats, payment method, ticket). Screens read/mutate via `bookingFlowProvider`; navigation is triggered by screens after watching state transitions. All data is mocked — no real API calls yet.

**Tech Stack:** Flutter, flutter_riverpod 2.x (`Notifier` / `NotifierProvider`), go_router, freezed, flutter_test, `ProviderContainer` for unit tests.

**Spec:** `docs/superpowers/specs/2026-06-30-booking-flow-design.md`

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `lib/features/booking/domain/entities/trip.dart` | `TripSummary`, `TripDetail` (Freezed) |
| Create | `lib/features/booking/domain/entities/seat.dart` | `SeatStatus`, `SeatCell`, `SeatRow` (Freezed) |
| Create | `lib/features/booking/domain/entities/booking.dart` | `ETicket` (Freezed) |
| Create | `lib/features/booking/data/mock_booking_data.dart` | Static fake trips + seat layout |
| Create | `lib/features/booking/presentation/providers/booking_providers.dart` | `BookingFlowState`, `BookingFlowNotifier`, `bookingFlowProvider` |
| Create | `lib/features/booking/presentation/widgets/booking_app_bar.dart` | White `PreferredSizeWidget` (back + title + optional action) |
| Create | `lib/features/booking/presentation/widgets/trip_card.dart` | Card used in trip results list |
| Create | `lib/features/booking/presentation/widgets/seat_grid.dart` | Bus seat layout grid |
| Create | `lib/features/booking/presentation/widgets/amenity_chip.dart` | Icon + label chip for trip details |
| Create | `lib/features/booking/presentation/trip_results_screen.dart` | Screen 09 |
| Create | `lib/features/booking/presentation/trip_details_screen.dart` | Screen 10 |
| Create | `lib/features/booking/presentation/seat_selection_screen.dart` | Screen 11 |
| Create | `lib/features/booking/presentation/passenger_confirm_screen.dart` | Screen 12 |
| Create | `lib/features/booking/presentation/eticket_screen.dart` | Screen 13 |
| Create | `lib/features/home/presentation/widgets/home_search_card.dart` | Transport tabs + From/To form |
| Create | `lib/features/home/presentation/widgets/popular_destinations.dart` | Two gradient destination cards |
| Create | `lib/features/home/presentation/widgets/main_nav_bar.dart` | Floating bottom nav bar |
| Modify | `lib/features/home/presentation/home_screen.dart` | Replace stub with full Skyline design |
| Modify | `lib/core/router/app_router.dart` | Add 5 new routes + `AppRoutes` constants |
| Create | `test/features/booking/booking_notifier_test.dart` | Notifier unit tests |

---

## Task 1 — Domain entities

**Files:**
- Create: `lib/features/booking/domain/entities/trip.dart`
- Create: `lib/features/booking/domain/entities/seat.dart`
- Create: `lib/features/booking/domain/entities/booking.dart`

- [ ] **Step 1.1 — Create trip.dart**

```dart
// lib/features/booking/domain/entities/trip.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'trip.freezed.dart';

@freezed
class TripSummary with _$TripSummary {
  const factory TripSummary({
    required String id,
    required String operatorName,
    required String operatorCode,
    required String serviceClass,
    required int departHour,
    required int departMinute,
    required int arriveHour,
    required int arriveMinute,
    required int durationMin,
    required int priceEgp,
    required int seatsLeft,
  }) = _TripSummary;
}

extension TripSummaryX on TripSummary {
  String get departLabel =>
      '${departHour.toString().padLeft(2, '0')}:${departMinute.toString().padLeft(2, '0')}';
  String get arriveLabel =>
      '${arriveHour.toString().padLeft(2, '0')}:${arriveMinute.toString().padLeft(2, '0')}';
  String get durationLabel {
    final h = durationMin ~/ 60;
    final m = durationMin % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

@freezed
class TripDetail with _$TripDetail {
  const factory TripDetail({
    required TripSummary summary,
    required String terminalFrom,
    required String terminalFromSub,
    required String terminalTo,
    required String terminalToSub,
    required List<String> amenities,
  }) = _TripDetail;
}
```

- [ ] **Step 1.2 — Create seat.dart**

```dart
// lib/features/booking/domain/entities/seat.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'seat.freezed.dart';

enum SeatStatus { available, booked }

@freezed
class SeatCell with _$SeatCell {
  const factory SeatCell({
    required String id,
    required SeatStatus status,
  }) = _SeatCell;
}

@freezed
class SeatRow with _$SeatRow {
  const factory SeatRow({
    required List<SeatCell?> cells, // null element = aisle gap
  }) = _SeatRow;
}
```

- [ ] **Step 1.3 — Create booking.dart**

```dart
// lib/features/booking/domain/entities/booking.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rego/features/booking/domain/entities/trip.dart';

part 'booking.freezed.dart';

@freezed
class ETicket with _$ETicket {
  const factory ETicket({
    required String bookingRef,
    required TripDetail trip,
    required List<String> seats,
    required String passengerName,
    required String gate,
    required DateTime issuedAt,
  }) = _ETicket;
}
```

---

## Task 2 — Run codegen

**Files:** Generates `trip.freezed.dart`, `seat.freezed.dart`, `booking.freezed.dart`

- [ ] **Step 2.1 — Run build_runner**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: exits 0, three `*.freezed.dart` files created next to their source files. If you see a conflict error, the `--delete-conflicting-outputs` flag handles it. If `part 'x.freezed.dart'` is not found, ensure the file path in the `part` directive matches exactly.

- [ ] **Step 2.2 — Verify compilation**

```bash
flutter analyze lib/features/booking/domain/
```

Expected: No errors. Warnings about unused imports are fine for now.

---

## Task 3 — Mock data

**Files:**
- Create: `lib/features/booking/data/mock_booking_data.dart`

- [ ] **Step 3.1 — Create mock_booking_data.dart**

```dart
// lib/features/booking/data/mock_booking_data.dart
import 'package:rego/features/booking/domain/entities/seat.dart';
import 'package:rego/features/booking/domain/entities/trip.dart';

abstract final class MockBookingData {
  static const double walletBalance = 340.50;
  static const int serviceFeeEgp = 10;

  static final List<TripSummary> trips = [
    const TripSummary(
      id: 'gb-vip-0800',
      operatorName: 'Go Bus',
      operatorCode: 'GB',
      serviceClass: 'VIP',
      departHour: 8,
      departMinute: 0,
      arriveHour: 11,
      arriveMinute: 30,
      durationMin: 210,
      priceEgp: 180,
      seatsLeft: 6,
    ),
    const TripSummary(
      id: 'bc-dlx-0915',
      operatorName: 'Blue Bus',
      operatorCode: 'BC',
      serviceClass: 'Deluxe',
      departHour: 9,
      departMinute: 15,
      arriveHour: 12,
      arriveMinute: 25,
      durationMin: 190,
      priceEgp: 150,
      seatsLeft: 12,
    ),
    const TripSummary(
      id: 'sj-eco-1030',
      operatorName: 'SuperJet',
      operatorCode: 'SJ',
      serviceClass: 'Economy',
      departHour: 10,
      departMinute: 30,
      arriveHour: 14,
      arriveMinute: 15,
      durationMin: 225,
      priceEgp: 120,
      seatsLeft: 2,
    ),
  ];

  // 5 rows × 4 seats (2 + aisle + 2). null = aisle gap.
  // Seats A3 and A4 are the "default selection" shown in design/V1 screen 11.
  static final List<SeatRow> seatLayout = [
    SeatRow(cells: [
      const SeatCell(id: 'A1', status: SeatStatus.booked),
      const SeatCell(id: 'A2', status: SeatStatus.available),
      null,
      const SeatCell(id: 'C1', status: SeatStatus.available),
      const SeatCell(id: 'D1', status: SeatStatus.available),
    ]),
    SeatRow(cells: [
      const SeatCell(id: 'A3', status: SeatStatus.available),
      const SeatCell(id: 'A4', status: SeatStatus.available),
      null,
      const SeatCell(id: 'C2', status: SeatStatus.booked),
      const SeatCell(id: 'D2', status: SeatStatus.available),
    ]),
    SeatRow(cells: [
      const SeatCell(id: 'A5', status: SeatStatus.available),
      const SeatCell(id: 'A6', status: SeatStatus.available),
      null,
      const SeatCell(id: 'C3', status: SeatStatus.available),
      const SeatCell(id: 'D3', status: SeatStatus.available),
    ]),
    SeatRow(cells: [
      const SeatCell(id: 'A7', status: SeatStatus.available),
      const SeatCell(id: 'A8', status: SeatStatus.available),
      null,
      const SeatCell(id: 'C4', status: SeatStatus.booked),
      const SeatCell(id: 'D4', status: SeatStatus.available),
    ]),
    SeatRow(cells: [
      const SeatCell(id: 'A9', status: SeatStatus.available),
      const SeatCell(id: 'A10', status: SeatStatus.available),
      null,
      const SeatCell(id: 'C5', status: SeatStatus.available),
      const SeatCell(id: 'D5', status: SeatStatus.available),
    ]),
  ];

  static TripDetail detailFor(String tripId) {
    final summary = trips.firstWhere(
      (t) => t.id == tripId,
      orElse: () => trips.first,
    );
    return TripDetail(
      summary: summary,
      terminalFrom: 'Cairo Gateway',
      terminalFromSub: 'Abbassia terminal',
      terminalTo: 'Alexandria',
      terminalToSub: 'Moharam Bek station',
      amenities: const ['Wi-Fi', 'A/C', 'Sockets', 'Water'],
    );
  }
}
```

---

## Task 4 — Notifier unit tests (write first, they fail until Task 5)

**Files:**
- Create: `test/features/booking/booking_notifier_test.dart`

- [ ] **Step 4.1 — Create the test file**

```dart
// test/features/booking/booking_notifier_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rego/features/booking/data/mock_booking_data.dart';
import 'package:rego/features/booking/presentation/providers/booking_providers.dart';

void main() {
  group('BookingFlowNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(container.dispose);

    test('initial state: idle, empty trips, no selection', () {
      final s = container.read(bookingFlowProvider);
      expect(s.status, BookingFlowStatus.idle);
      expect(s.trips, isEmpty);
      expect(s.selectedTrip, isNull);
      expect(s.selectedSeats, isEmpty);
      expect(s.ticket, isNull);
      expect(s.paymentMethod, PaymentMethod.wallet);
    });

    test('searchTrips: populates trips and returns to idle', () async {
      await container
          .read(bookingFlowProvider.notifier)
          .searchTrips('Cairo', 'Alexandria', 'Today');

      final s = container.read(bookingFlowProvider);
      expect(s.status, BookingFlowStatus.idle);
      expect(s.trips, hasLength(3));
      expect(s.trips.first.operatorCode, 'GB');
    });

    test('selectTrip: sets selectedTrip, loads detail, resets seats', () async {
      final notifier = container.read(bookingFlowProvider.notifier);
      await notifier.searchTrips('Cairo', 'Alexandria', 'Today');

      // Pre-select a seat then change trip — seats must reset
      notifier.toggleSeat('A3');
      expect(container.read(bookingFlowProvider).selectedSeats, isNotEmpty);

      final trip = container.read(bookingFlowProvider).trips.first;
      await notifier.selectTrip(trip);

      final s = container.read(bookingFlowProvider);
      expect(s.selectedTrip, trip);
      expect(s.tripDetail, isNotNull);
      expect(s.tripDetail!.summary.id, trip.id);
      expect(s.selectedSeats, isEmpty);
    });

    test('toggleSeat: adds seat when not selected', () {
      container.read(bookingFlowProvider.notifier).toggleSeat('A3');
      expect(container.read(bookingFlowProvider).selectedSeats, contains('A3'));
    });

    test('toggleSeat: removes seat when already selected', () {
      final n = container.read(bookingFlowProvider.notifier);
      n.toggleSeat('A3');
      n.toggleSeat('A3');
      expect(container.read(bookingFlowProvider).selectedSeats, isEmpty);
    });

    test('toggleSeat: multiple seats accumulate', () {
      final n = container.read(bookingFlowProvider.notifier);
      n.toggleSeat('A3');
      n.toggleSeat('A4');
      expect(
        container.read(bookingFlowProvider).selectedSeats,
        containsAll(['A3', 'A4']),
      );
    });

    test('setPaymentMethod: updates paymentMethod', () {
      container
          .read(bookingFlowProvider.notifier)
          .setPaymentMethod(PaymentMethod.card);
      expect(
        container.read(bookingFlowProvider).paymentMethod,
        PaymentMethod.card,
      );
    });

    test('confirmBooking: creates ticket with bookingRef and confirmed status',
        () async {
      final n = container.read(bookingFlowProvider.notifier);
      await n.searchTrips('Cairo', 'Alexandria', 'Today');
      await n.selectTrip(container.read(bookingFlowProvider).trips.first);
      n.toggleSeat('A3');
      n.toggleSeat('A4');

      await n.confirmBooking();

      final s = container.read(bookingFlowProvider);
      expect(s.status, BookingFlowStatus.confirmed);
      expect(s.ticket, isNotNull);
      expect(s.ticket!.bookingRef, startsWith('RG-'));
      expect(s.ticket!.seats, containsAll(['A3', 'A4']));
      expect(s.ticket!.passengerName, s.passengerName);
    });

    test('reset: clears all booking state back to initial', () async {
      final n = container.read(bookingFlowProvider.notifier);
      await n.searchTrips('Cairo', 'Alexandria', 'Today');
      n.toggleSeat('A3');

      n.reset();

      final s = container.read(bookingFlowProvider);
      expect(s.status, BookingFlowStatus.idle);
      expect(s.trips, isEmpty);
      expect(s.selectedSeats, isEmpty);
      expect(s.ticket, isNull);
    });
  });
}
```

- [ ] **Step 4.2 — Run tests to confirm they fail (provider not defined yet)**

```bash
flutter test test/features/booking/booking_notifier_test.dart
```

Expected: compile error — `bookingFlowProvider`, `BookingFlowStatus`, `PaymentMethod` not found. This is correct at this stage.

---

## Task 5 — BookingFlowNotifier

**Files:**
- Create: `lib/features/booking/presentation/providers/booking_providers.dart`

- [ ] **Step 5.1 — Create booking_providers.dart**

```dart
// lib/features/booking/presentation/providers/booking_providers.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rego/features/booking/data/mock_booking_data.dart';
import 'package:rego/features/booking/domain/entities/booking.dart';
import 'package:rego/features/booking/domain/entities/seat.dart';
import 'package:rego/features/booking/domain/entities/trip.dart';

part 'booking_providers.freezed.dart';

enum BookingFlowStatus { idle, loadingTrips, loadingDetail, confirming, confirmed, error }

enum PaymentMethod { wallet, card }

@freezed
class BookingFlowState with _$BookingFlowState {
  const factory BookingFlowState({
    @Default([]) List<TripSummary> trips,
    @Default(BookingFlowStatus.idle) BookingFlowStatus status,
    TripSummary? selectedTrip,
    TripDetail? tripDetail,
    @Default([]) List<String> selectedSeats,
    @Default('Ahmed Hassan') String passengerName,
    @Default('+20 10 1234 5678') String passengerPhone,
    @Default(PaymentMethod.wallet) PaymentMethod paymentMethod,
    ETicket? ticket,
    String? error,
  }) = _BookingFlowState;
}

class BookingFlowNotifier extends Notifier<BookingFlowState> {
  @override
  BookingFlowState build() => const BookingFlowState();

  Future<void> searchTrips(String from, String to, String date) async {
    state = state.copyWith(status: BookingFlowStatus.loadingTrips, error: null);
    // Simulate network latency — swap for real API call later.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    state = state.copyWith(
      trips: MockBookingData.trips,
      status: BookingFlowStatus.idle,
    );
  }

  Future<void> selectTrip(TripSummary trip) async {
    state = state.copyWith(
      selectedTrip: trip,
      selectedSeats: const [],
      status: BookingFlowStatus.loadingDetail,
      error: null,
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    state = state.copyWith(
      tripDetail: MockBookingData.detailFor(trip.id),
      status: BookingFlowStatus.idle,
    );
  }

  void toggleSeat(String id) {
    final seats = [...state.selectedSeats];
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
    state = state.copyWith(status: BookingFlowStatus.confirming, error: null);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final ref = 'RG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final ticket = ETicket(
      bookingRef: ref,
      trip: state.tripDetail!,
      seats: state.selectedSeats,
      passengerName: state.passengerName,
      gate: '3',
      issuedAt: DateTime.now(),
    );
    state = state.copyWith(status: BookingFlowStatus.confirmed, ticket: ticket);
  }

  void reset() => state = const BookingFlowState();
}

final bookingFlowProvider =
    NotifierProvider<BookingFlowNotifier, BookingFlowState>(
  BookingFlowNotifier.new,
);
```

- [ ] **Step 5.2 — Run codegen for the new Freezed class**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `booking_providers.freezed.dart` generated alongside the source file.

- [ ] **Step 5.3 — Run the unit tests — all should pass**

```bash
flutter test test/features/booking/booking_notifier_test.dart
```

Expected: `All tests passed.` (9 tests). If any fail, check the `copyWith` field names match `BookingFlowState`.

- [ ] **Step 5.4 — Commit**

```bash
git add lib/features/booking/domain/ lib/features/booking/data/ lib/features/booking/presentation/providers/ test/features/booking/
git commit -m "feat(booking): domain entities, mock data, and BookingFlowNotifier"
```

---

## Task 6 — Router additions

**Files:**
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 6.1 — Add route constants to `AppRoutes`**

Open `lib/core/router/app_router.dart`. In `abstract final class AppRoutes`, add after `static const home = '/';`:

```dart
static const trips        = '/trips';
static const tripDetail   = '/trips/detail';
static const tripSeats    = '/trips/seats';
static const tripConfirm  = '/trips/confirm';
static const eTicket      = '/booking/ticket';
```

- [ ] **Step 6.2 — Add import at top of app_router.dart**

After the last existing import, add:

```dart
import 'package:rego/features/booking/presentation/trip_results_screen.dart';
import 'package:rego/features/booking/presentation/trip_details_screen.dart';
import 'package:rego/features/booking/presentation/seat_selection_screen.dart';
import 'package:rego/features/booking/presentation/passenger_confirm_screen.dart';
import 'package:rego/features/booking/presentation/eticket_screen.dart';
```

- [ ] **Step 6.3 — Register the 5 new GoRoutes**

Inside the `routes: [` list, after the existing `GoRoute` for `AppRoutes.home`, add:

```dart
GoRoute(
  path: AppRoutes.trips,
  builder: (context, state) => const TripResultsScreen(),
),
GoRoute(
  path: AppRoutes.tripDetail,
  builder: (context, state) => const TripDetailsScreen(),
),
GoRoute(
  path: AppRoutes.tripSeats,
  builder: (context, state) => const SeatSelectionScreen(),
),
GoRoute(
  path: AppRoutes.tripConfirm,
  builder: (context, state) => const PassengerConfirmScreen(),
),
GoRoute(
  path: AppRoutes.eTicket,
  builder: (context, state) => const ETicketScreen(),
),
```

These 5 routes are not in `_authRoutes`, so the existing redirect guard already protects them: unauthenticated users go to login, authenticated users pass through.

- [ ] **Step 6.4 — Create stub screens so the router compiles**

Create each of the 5 screen files with a minimal stub. Example for `trip_results_screen.dart` (repeat pattern for the other 4):

```dart
// lib/features/booking/presentation/trip_results_screen.dart
import 'package:flutter/material.dart';

class TripResultsScreen extends StatelessWidget {
  const TripResultsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Trip results — coming soon')));
}
```

```dart
// lib/features/booking/presentation/trip_details_screen.dart
import 'package:flutter/material.dart';

class TripDetailsScreen extends StatelessWidget {
  const TripDetailsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Trip details — coming soon')));
}
```

```dart
// lib/features/booking/presentation/seat_selection_screen.dart
import 'package:flutter/material.dart';

class SeatSelectionScreen extends StatelessWidget {
  const SeatSelectionScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Seat selection — coming soon')));
}
```

```dart
// lib/features/booking/presentation/passenger_confirm_screen.dart
import 'package:flutter/material.dart';

class PassengerConfirmScreen extends StatelessWidget {
  const PassengerConfirmScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Passenger confirm — coming soon')));
}
```

```dart
// lib/features/booking/presentation/eticket_screen.dart
import 'package:flutter/material.dart';

class ETicketScreen extends StatelessWidget {
  const ETicketScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('E-ticket — coming soon')));
}
```

- [ ] **Step 6.5 — Verify it compiles**

```bash
flutter analyze lib/core/router/ lib/features/booking/presentation/
```

Expected: no errors.

- [ ] **Step 6.6 — Commit**

```bash
git add lib/core/router/app_router.dart lib/features/booking/presentation/*.dart
git commit -m "feat(router): add 5 booking routes with stub screens"
```

---

## Task 7 — Shared booking widgets

**Files:**
- Create: `lib/features/booking/presentation/widgets/booking_app_bar.dart`
- Create: `lib/features/booking/presentation/widgets/trip_card.dart`
- Create: `lib/features/booking/presentation/widgets/seat_grid.dart`
- Create: `lib/features/booking/presentation/widgets/amenity_chip.dart`

- [ ] **Step 7.1 — BookingAppBar**

White app bar matching the design's `background:#fff; padding:50px 18px 16px`. Flutter's `AppBar` with `toolbarHeight` handles the status-bar inset automatically.

```dart
// lib/features/booking/presentation/widgets/booking_app_bar.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_typography.dart';

class BookingAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BookingAppBar({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.bgElevated,
      elevation: 0,
      scrolledUnderElevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      surfaceTintColor: Colors.transparent,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: _BackButton(),
      ),
      title: Text(
        title,
        style: AppTypography.title.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
      actions: action != null
          ? [Padding(padding: const EdgeInsets.only(right: 12), child: action!)]
          : null,
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pop(),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.bgBase,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(
          Icons.chevron_left_rounded,
          color: AppColors.textPrimary,
          size: 26,
        ),
      ),
    );
  }
}
```

- [ ] **Step 7.2 — TripCard**

```dart
// lib/features/booking/presentation/widgets/trip_card.dart
import 'package:flutter/material.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/booking/domain/entities/trip.dart';

class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, required this.onSelect});

  final TripSummary trip;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _OperatorRow(trip: trip),
          const SizedBox(height: 14),
          _TimelineRow(trip: trip),
          const Divider(height: 28, color: AppColors.hairline, thickness: 1),
          _PriceRow(trip: trip, onSelect: onSelect),
        ],
      ),
    );
  }
}

class _OperatorRow extends StatelessWidget {
  const _OperatorRow({required this.trip});
  final TripSummary trip;

  Color get _logoColor =>
      trip.operatorCode == 'BC' ? AppColors.secondaryTint : AppColors.primaryTint;
  Color get _logoTextColor =>
      trip.operatorCode == 'BC' ? const Color(0xFFD98A2B) : AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final isLow = trip.seatsLeft <= 3;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _logoColor,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            trip.operatorCode,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w800,
              color: _logoTextColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${trip.operatorName} · ${trip.serviceClass}',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isLow ? const Color(0xFFFDE7E7) : AppColors.secondaryTint,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          child: Text(
            '${trip.seatsLeft} seats left',
            style: AppTypography.overline.copyWith(
              fontWeight: FontWeight.w800,
              color: isLow ? const Color(0xFFD14343) : const Color(0xFFD98A2B),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.trip});
  final TripSummary trip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TimeBlock(time: trip.departLabel, label: 'Cairo'),
        Expanded(
          child: Column(
            children: [
              Text(
                trip.durationLabel,
                style: AppTypography.overline.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 4),
              Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(height: 2, color: AppColors.hairline),
                  const Positioned(
                    left: 0,
                    child: _Dot(color: AppColors.primary),
                  ),
                  const Positioned(
                    right: 0,
                    child: _Dot(color: AppColors.secondary),
                  ),
                ],
              ),
            ],
          ),
        ),
        _TimeBlock(time: trip.arriveLabel, label: 'Alexandria', align: CrossAxisAlignment.end),
      ],
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.time, required this.label, this.align = CrossAxisAlignment.start});
  final String time;
  final String label;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          time,
          style: AppTypography.h1.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        Text(label, style: AppTypography.overline.copyWith(color: AppColors.textMuted)),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.trip, required this.onSelect});
  final TripSummary trip;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(children: [
              TextSpan(
                text: '${trip.priceEgp}',
                style: AppTypography.h1.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  fontSize: 22,
                ),
              ),
              TextSpan(
                text: '  EGP',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ]),
          ),
        ),
        GestureDetector(
          onTap: onSelect,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            child: Text(
              'Select',
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 7.3 — SeatGrid**

```dart
// lib/features/booking/presentation/widgets/seat_grid.dart
import 'package:flutter/material.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/booking/domain/entities/seat.dart';

class SeatGrid extends StatelessWidget {
  const SeatGrid({
    super.key,
    required this.rows,
    required this.selectedSeats,
    required this.onToggle,
  });

  final List<SeatRow> rows;
  final List<String> selectedSeats;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rows
          .map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SeatRowWidget(
                  row: row,
                  selectedSeats: selectedSeats,
                  onToggle: onToggle,
                ),
              ))
          .toList(),
    );
  }
}

class _SeatRowWidget extends StatelessWidget {
  const _SeatRowWidget({
    required this.row,
    required this.selectedSeats,
    required this.onToggle,
  });

  final SeatRow row;
  final List<String> selectedSeats;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: row.cells.map((cell) {
        if (cell == null) return const SizedBox(width: 24);
        final isSelected = selectedSeats.contains(cell.id);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: _SeatCellWidget(
            cell: cell,
            isSelected: isSelected,
            onToggle: cell.status == SeatStatus.booked ? null : onToggle,
          ),
        );
      }).toList(),
    );
  }
}

class _SeatCellWidget extends StatelessWidget {
  const _SeatCellWidget({
    required this.cell,
    required this.isSelected,
    required this.onToggle,
  });

  final SeatCell cell;
  final bool isSelected;
  final ValueChanged<String>? onToggle;

  Color get _bg {
    if (cell.status == SeatStatus.booked) return const Color(0xFFDCE3F0);
    if (isSelected) return AppColors.primary;
    return AppColors.bgElevated;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle != null ? () => onToggle!(cell.id) : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(8),
          border: (cell.status == SeatStatus.available && !isSelected)
              ? Border.all(color: const Color(0xFFDCE3F0), width: 1.5)
              : null,
        ),
        alignment: Alignment.center,
        child: isSelected
            ? Text(
                cell.id,
                style: AppTypography.overline.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontSize: 10,
                ),
              )
            : null,
      ),
    );
  }
}
```

- [ ] **Step 7.4 — AmenityChip**

```dart
// lib/features/booking/presentation/widgets/amenity_chip.dart
import 'package:flutter/material.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_typography.dart';

class AmenityChip extends StatelessWidget {
  const AmenityChip({super.key, required this.label});

  final String label;

  IconData _icon() {
    switch (label) {
      case 'Wi-Fi':
        return Icons.wifi_rounded;
      case 'A/C':
        return Icons.ac_unit_rounded;
      case 'Sockets':
        return Icons.electrical_services_rounded;
      case 'Water':
        return Icons.water_drop_outlined;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(), size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7.5 — Verify compilation**

```bash
flutter analyze lib/features/booking/presentation/widgets/
```

Expected: no errors.

- [ ] **Step 7.6 — Commit**

```bash
git add lib/features/booking/presentation/widgets/
git commit -m "feat(booking): BookingAppBar, TripCard, SeatGrid, AmenityChip widgets"
```

---

## Task 8 — Home screen rebuild

**Files:**
- Create: `lib/features/home/presentation/widgets/home_search_card.dart`
- Create: `lib/features/home/presentation/widgets/popular_destinations.dart`
- Create: `lib/features/home/presentation/widgets/main_nav_bar.dart`
- Modify: `lib/features/home/presentation/home_screen.dart`

- [ ] **Step 8.1 — HomeSearchCard**

```dart
// lib/features/home/presentation/widgets/home_search_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/booking/presentation/providers/booking_providers.dart';

class HomeSearchCard extends ConsumerStatefulWidget {
  const HomeSearchCard({super.key});

  @override
  ConsumerState<HomeSearchCard> createState() => _HomeSearchCardState();
}

class _HomeSearchCardState extends ConsumerState<HomeSearchCard> {
  int _tab = 0; // 0=Bus, 1=Private, 2=Flight, 3=Train

  static const _tabs = ['Bus', 'Private', 'Flight', 'Train'];
  static const _tabIcons = [
    Icons.directions_bus_rounded,
    Icons.airport_shuttle_rounded,
    Icons.flight_rounded,
    Icons.train_rounded,
  ];

  Future<void> _search() async {
    final notifier = ref.read(bookingFlowProvider.notifier);
    await notifier.searchTrips('Cairo', 'Alexandria', 'Today');
    if (mounted) context.push(AppRoutes.trips);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E50C7).withValues(alpha: 0.2),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Transport tabs
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgBase,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final active = _tab == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tab = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _tabIcons[i],
                            size: 16,
                            color: active ? Colors.white : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _tabs[i],
                            style: AppTypography.overline.copyWith(
                              fontWeight: FontWeight.w700,
                              color: active ? Colors.white : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),
          // From/To picker
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.hairline),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    _LocationRow(
                      label: 'From',
                      city: 'Cairo',
                      iconColor: AppColors.primary,
                      iconBg: AppColors.primaryTint,
                    ),
                    const Divider(height: 1, color: AppColors.hairline, indent: 16, endIndent: 16),
                    _LocationRow(
                      label: 'To',
                      city: 'Alexandria',
                      iconColor: const Color(0xFFD98A2B),
                      iconBg: AppColors.secondaryTint,
                    ),
                  ],
                ),
                Positioned(
                  right: 14,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x991464EC),
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.swap_vert_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Date + pax row
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'Today, 25 Jun',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '1 passenger',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Search button
          GestureDetector(
            onTap: _search,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: Text(
                'Search Buses',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.label,
    required this.city,
    required this.iconColor,
    required this.iconBg,
  });

  final String label;
  final String city;
  final Color iconColor;
  final Color iconBg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(Icons.location_on_rounded, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.overline.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
              Text(
                city,
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8.2 — PopularDestinations**

```dart
// lib/features/home/presentation/widgets/popular_destinations.dart
import 'package:flutter/material.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_typography.dart';

class PopularDestinations extends StatelessWidget {
  const PopularDestinations({super.key});

  static const _destinations = [
    (
      city: 'Luxor',
      price: 240,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1D6FF2), Color(0xFF0A3FA3)],
      ),
    ),
    (
      city: 'Aswan',
      price: 290,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFBA834), Color(0xFFE0871A)],
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Popular destinations',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
              ),
              Text(
                'See all',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _destinations.map((d) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Container(
                    height: 118,
                    decoration: BoxDecoration(
                      gradient: d.gradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -16,
                          bottom: -24,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.city,
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  fontSize: 17,
                                ),
                              ),
                              const Spacer(),
                              Text.rich(
                                TextSpan(children: [
                                  TextSpan(
                                    text: 'from ',
                                    style: AppTypography.overline.copyWith(
                                      color: Colors.white.withValues(alpha: 0.85),
                                    ),
                                  ),
                                  TextSpan(
                                    text: '${d.price} EGP',
                                    style: AppTypography.overline.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 8.3 — MainNavBar**

```dart
// lib/features/home/presentation/widgets/main_nav_bar.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_typography.dart';

class MainNavBar extends StatelessWidget {
  const MainNavBar({super.key, required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E50C7).withValues(alpha: 0.18),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            active: currentIndex == 0,
            onTap: () {},
          ),
          _NavItem(
            icon: Icons.confirmation_number_rounded,
            label: 'Tickets',
            active: currentIndex == 1,
            onTap: () => _comingSoon(context),
          ),
          // Search FAB (centre)
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.55),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(Icons.search_rounded, color: Colors.white, size: 26),
            ),
          ),
          _NavItem(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Wallet',
            active: currentIndex == 3,
            onTap: () => _comingSoon(context),
          ),
          _NavItem(
            icon: Icons.person_rounded,
            label: 'Profile',
            active: currentIndex == 4,
            onTap: () => _comingSoon(context),
          ),
        ],
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Coming soon')));
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppTypography.overline.copyWith(
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8.4 — Replace home_screen.dart**

Replace the entire file:

```dart
// lib/features/home/presentation/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/home/presentation/widgets/home_search_card.dart';
import 'package:rego/features/home/presentation/widgets/main_nav_bar.dart';
import 'package:rego/features/home/presentation/widgets/popular_destinations.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _HeroHeader()),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              const SliverToBoxAdapter(child: HomeSearchCard()),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              const SliverToBoxAdapter(child: PopularDestinations()),
              // Bottom padding so content clears the nav bar
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          // Floating nav bar
          Positioned(
            left: 14,
            right: 14,
            bottom: 30,
            child: const MainNavBar(currentIndex: 0),
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 24,
        right: 24,
        bottom: 54, // extra so the search card floats over the bottom
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: avatar + greeting + bell
          Row(
            children: [
              // Avatar
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                alignment: Alignment.center,
                child: Text(
                  'A',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, Ahmed',
                    style: AppTypography.overline.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                  Text(
                    'Where to today?',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Notification bell
              Stack(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  Positioned(
                    top: 9,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Headline
          Text(
            'Book your trip\nin one tap',
            style: AppTypography.display.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontSize: 25,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8.5 — Verify compilation**

```bash
flutter analyze lib/features/home/
```

Expected: no errors.

- [ ] **Step 8.6 — Commit**

```bash
git add lib/features/home/
git commit -m "feat(home): rebuild HomeScreen with Skyline hero, search card, and nav bar"
```

---

## Task 9 — Trip results screen

**Files:**
- Modify: `lib/features/booking/presentation/trip_results_screen.dart` (replace stub)

- [ ] **Step 9.1 — Replace stub with full implementation**

```dart
// lib/features/booking/presentation/trip_results_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/booking/domain/entities/trip.dart';
import 'package:rego/features/booking/presentation/providers/booking_providers.dart';
import 'package:rego/features/booking/presentation/widgets/trip_card.dart';

class TripResultsScreen extends ConsumerWidget {
  const TripResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingFlowProvider);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Column(
        children: [
          _ResultsHeader(),
          _SortChips(),
          Expanded(
            child: state.status == BookingFlowStatus.loadingTrips
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? _ErrorView(message: state.error!)
                    : _TripList(trips: state.trips),
          ),
        ],
      ),
    );
  }
}

class _ResultsHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.bgElevated,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 18,
        right: 18,
        bottom: 14,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.bgBase,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.chevron_left_rounded, size: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cairo → Alexandria',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Today, 25 Jun · 1 passenger',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

class _SortChips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const labels = ['Times', 'Cheapest', 'Seats'];
    return Container(
      color: AppColors.bgElevated,
      padding: const EdgeInsets.only(left: 18, right: 18, bottom: 14),
      child: Row(
        children: labels.asMap().entries.map((e) {
          final active = e.key == 0;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.bgBase,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                e.value,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TripList extends ConsumerWidget {
  const _TripList({required this.trips});
  final List<TripSummary> trips;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (trips.isEmpty) {
      return Center(
        child: Text(
          'No trips found',
          style: AppTypography.body.copyWith(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final trip = trips[i];
        return TripCard(
          trip: trip,
          onSelect: () async {
            await ref.read(bookingFlowProvider.notifier).selectTrip(trip);
            if (context.mounted) context.push(AppRoutes.tripDetail);
          },
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: AppTypography.body.copyWith(color: AppColors.error),
        textAlign: TextAlign.center,
      ),
    );
  }
}
```

- [ ] **Step 9.2 — Verify and commit**

```bash
flutter analyze lib/features/booking/presentation/trip_results_screen.dart
git add lib/features/booking/presentation/trip_results_screen.dart
git commit -m "feat(booking): Trip results screen"
```

---

## Task 10 — Trip details screen

**Files:**
- Modify: `lib/features/booking/presentation/trip_details_screen.dart` (replace stub)

- [ ] **Step 10.1 — Replace stub with full implementation**

```dart
// lib/features/booking/presentation/trip_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/booking/domain/entities/trip.dart';
import 'package:rego/features/booking/presentation/providers/booking_providers.dart';
import 'package:rego/features/booking/presentation/widgets/amenity_chip.dart';
import 'package:rego/features/booking/presentation/widgets/booking_app_bar.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class TripDetailsScreen extends ConsumerWidget {
  const TripDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingFlowProvider);
    final detail = state.tripDetail;

    if (state.status == BookingFlowStatus.loadingDetail || detail == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(title: 'Trip details'),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _OperatorCard(detail: detail),
                  const SizedBox(height: 14),
                  _RouteCard(detail: detail),
                  const SizedBox(height: 14),
                  _AmenitiesSection(amenities: detail.amenities),
                  const SizedBox(height: 14),
                  _PriceCard(priceEgp: detail.summary.priceEgp),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PrimaryButton(
                label: 'Choose seats',
                onPressed: () => context.push(AppRoutes.tripSeats),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OperatorCard extends StatelessWidget {
  const _OperatorCard({required this.detail});
  final TripDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = detail.summary;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Text(
              s.operatorCode,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.operatorName} · ${s.serviceClass}',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Mercedes Travego · 45 seats',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.secondaryTint,
              borderRadius: BorderRadius.circular(9),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, size: 13, color: Color(0xFFD98A2B)),
                const SizedBox(width: 4),
                Text(
                  '4.8',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFD98A2B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.detail});
  final TripDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = detail.summary;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline connector
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 3),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.hairline,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFBA834),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detail.terminalFrom,
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            detail.terminalFromSub,
                            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      Text(
                        s.departLabel,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 44),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detail.terminalTo,
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            detail.terminalToSub,
                            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      Text(
                        s.arriveLabel,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmenitiesSection extends StatelessWidget {
  const _AmenitiesSection({required this.amenities});
  final List<String> amenities;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amenities',
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: amenities.map((a) => AmenityChip(label: a)).toList(),
        ),
      ],
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.priceEgp});
  final int priceEgp;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Price per seat',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
                RichText(
                  text: TextSpan(children: [
                    TextSpan(
                      text: '$priceEgp',
                      style: AppTypography.h1.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        fontSize: 22,
                      ),
                    ),
                    TextSpan(
                      text: '  EGP',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 10.2 — Verify and commit**

```bash
flutter analyze lib/features/booking/presentation/trip_details_screen.dart
git add lib/features/booking/presentation/trip_details_screen.dart lib/features/booking/presentation/widgets/amenity_chip.dart lib/features/booking/presentation/widgets/booking_app_bar.dart
git commit -m "feat(booking): Trip details screen"
```

---

## Task 11 — Seat selection screen

**Files:**
- Modify: `lib/features/booking/presentation/seat_selection_screen.dart` (replace stub)

- [ ] **Step 11.1 — Replace stub with full implementation**

```dart
// lib/features/booking/presentation/seat_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/booking/data/mock_booking_data.dart';
import 'package:rego/features/booking/presentation/providers/booking_providers.dart';
import 'package:rego/features/booking/presentation/widgets/booking_app_bar.dart';
import 'package:rego/features/booking/presentation/widgets/seat_grid.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class SeatSelectionScreen extends ConsumerWidget {
  const SeatSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingFlowProvider);
    final selectedSeats = state.selectedSeats;
    final trip = state.selectedTrip;
    final totalPrice = selectedSeats.length * (trip?.priceEgp ?? 0);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(title: 'Select seats'),
      body: Column(
        children: [
          const _SeatLegend(),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Steering wheel icon (decorative)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.bgBase,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.radio_button_unchecked_rounded,
                            color: AppColors.textMuted,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SeatGrid(
                        rows: MockBookingData.seatLayout,
                        selectedSeats: selectedSeats,
                        onToggle: ref.read(bookingFlowProvider.notifier).toggleSeat,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Bottom panel
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedSeats.isEmpty
                                ? 'No seats selected'
                                : 'Seats ${selectedSeats.join(', ')}',
                            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                          ),
                          RichText(
                            text: TextSpan(children: [
                              TextSpan(
                                text: '$totalPrice',
                                style: AppTypography.h1.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                  fontSize: 22,
                                ),
                              ),
                              TextSpan(
                                text: '  EGP',
                                style: AppTypography.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Continue',
                  onPressed: selectedSeats.isEmpty
                      ? null
                      : () => context.push(AppRoutes.tripConfirm),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatLegend extends StatelessWidget {
  const _SeatLegend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          _LegendItem(label: 'Available', color: Colors.white, hasBorder: true),
          SizedBox(width: 18),
          _LegendItem(label: 'Booked', color: Color(0xFFDCE3F0)),
          SizedBox(width: 18),
          _LegendItem(label: 'Selected', color: AppColors.primary),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.color, this.hasBorder = false});

  final String label;
  final Color color;
  final bool hasBorder;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
            border: hasBorder ? Border.all(color: const Color(0xFFDCE3F0), width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 11.2 — Verify and commit**

```bash
flutter analyze lib/features/booking/presentation/seat_selection_screen.dart
git add lib/features/booking/presentation/seat_selection_screen.dart lib/features/booking/presentation/widgets/seat_grid.dart
git commit -m "feat(booking): Seat selection screen with interactive grid"
```

---

## Task 12 — Passenger & confirm screen

**Files:**
- Modify: `lib/features/booking/presentation/passenger_confirm_screen.dart` (replace stub)

- [ ] **Step 12.1 — Replace stub with full implementation**

```dart
// lib/features/booking/presentation/passenger_confirm_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/booking/data/mock_booking_data.dart';
import 'package:rego/features/booking/presentation/providers/booking_providers.dart';
import 'package:rego/features/booking/presentation/widgets/booking_app_bar.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class PassengerConfirmScreen extends ConsumerWidget {
  const PassengerConfirmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingFlowProvider);
    final trip = state.selectedTrip;
    final detail = state.tripDetail;

    if (trip == null || detail == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final ticketTotal = trip.priceEgp * state.selectedSeats.length;
    final grandTotal = ticketTotal + MockBookingData.serviceFeeEgp;

    // Navigate on confirmation
    ref.listen(bookingFlowProvider.select((s) => s.status), (_, next) {
      if (next == BookingFlowStatus.confirmed && context.mounted) {
        context.go(AppRoutes.eTicket);
      }
    });

    final isConfirming = state.status == BookingFlowStatus.confirming;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(title: 'Review & confirm'),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TripSummaryCard(state: state),
                  const SizedBox(height: 16),
                  _SectionLabel(label: 'Passenger'),
                  const SizedBox(height: 10),
                  _PassengerFields(state: state),
                  const SizedBox(height: 16),
                  _SectionLabel(label: 'Payment method'),
                  const SizedBox(height: 10),
                  _PaymentMethod(state: state, ref: ref),
                  const SizedBox(height: 16),
                  _PriceBreakdown(
                    seatCount: state.selectedSeats.length,
                    ticketTotal: ticketTotal,
                    serviceFee: MockBookingData.serviceFeeEgp,
                    grandTotal: grandTotal,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PrimaryButton(
                label: 'Confirm booking',
                loading: isConfirming,
                onPressed: isConfirming
                    ? null
                    : () => ref.read(bookingFlowProvider.notifier).confirmBooking(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.body.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        fontSize: 14,
      ),
    );
  }
}

class _TripSummaryCard extends StatelessWidget {
  const _TripSummaryCard({required this.state});
  final BookingFlowState state;

  @override
  Widget build(BuildContext context) {
    final trip = state.selectedTrip!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  trip.operatorCode,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${trip.operatorName} · ${trip.serviceClass}',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                'Today, 25 Jun',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.departLabel,
                    style: AppTypography.h2.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                  Text('Cairo', style: AppTypography.overline.copyWith(color: AppColors.textMuted)),
                ],
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(height: 2, color: AppColors.hairline),
                    const Positioned(
                      left: 8,
                      child: CircleAvatar(radius: 3, backgroundColor: AppColors.primary),
                    ),
                    const Positioned(
                      right: 8,
                      child: CircleAvatar(radius: 3, backgroundColor: Color(0xFFFBA834)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    trip.arriveLabel,
                    style: AppTypography.h2.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                  Text('Alexandria', style: AppTypography.overline.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: 'Seats ',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
                TextSpan(
                  text: state.selectedSeats.join(', '),
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _PassengerFields extends StatelessWidget {
  const _PassengerFields({required this.state});
  final BookingFlowState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ReadonlyField(icon: Icons.person_outline_rounded, value: state.passengerName),
        const SizedBox(height: 11),
        _ReadonlyField(icon: Icons.phone_outlined, value: state.passengerPhone),
      ],
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              value,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethod extends StatelessWidget {
  const _PaymentMethod({required this.state, required this.ref});
  final BookingFlowState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PaymentCard(
            label: 'Wallet',
            subLabel: '${MockBookingData.walletBalance.toStringAsFixed(2)} EGP',
            icon: Icons.account_balance_wallet_rounded,
            selected: state.paymentMethod == PaymentMethod.wallet,
            onTap: () => ref.read(bookingFlowProvider.notifier).setPaymentMethod(PaymentMethod.wallet),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PaymentCard(
            label: 'Card',
            subLabel: 'Visa · Master',
            icon: Icons.credit_card_rounded,
            selected: state.paymentMethod == PaymentMethod.card,
            onTap: () => ref.read(bookingFlowProvider.notifier).setPaymentMethod(PaymentMethod.card),
          ),
        ),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.label,
    required this.subLabel,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subLabel;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryTint : AppColors.bgElevated,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.hairline,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 22, color: selected ? AppColors.primary : AppColors.textMuted),
                if (selected)
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 11),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
            Text(
              subLabel,
              style: AppTypography.caption.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceBreakdown extends StatelessWidget {
  const _PriceBreakdown({
    required this.seatCount,
    required this.ticketTotal,
    required this.serviceFee,
    required this.grandTotal,
  });

  final int seatCount;
  final int ticketTotal;
  final int serviceFee;
  final int grandTotal;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _PriceRow(label: 'Ticket × $seatCount', amount: '$ticketTotal EGP'),
          const SizedBox(height: 8),
          _PriceRow(label: 'Service fee', amount: '$serviceFee EGP'),
          const Divider(height: 20, color: AppColors.hairline),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              RichText(
                text: TextSpan(children: [
                  TextSpan(
                    text: '$grandTotal',
                    style: AppTypography.h1.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      fontSize: 20,
                    ),
                  ),
                  TextSpan(
                    text: '  EGP',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.amount});
  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
        Text(
          amount,
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 12.2 — Verify and commit**

```bash
flutter analyze lib/features/booking/presentation/passenger_confirm_screen.dart
git add lib/features/booking/presentation/passenger_confirm_screen.dart
git commit -m "feat(booking): Passenger review & confirm screen"
```

---

## Task 13 — E-ticket screen

**Files:**
- Modify: `lib/features/booking/presentation/eticket_screen.dart` (replace stub)

- [ ] **Step 13.1 — Replace stub with full implementation**

```dart
// lib/features/booking/presentation/eticket_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/booking/domain/entities/booking.dart';
import 'package:rego/features/booking/presentation/providers/booking_providers.dart';

class ETicketScreen extends ConsumerWidget {
  const ETicketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticket = ref.watch(bookingFlowProvider.select((s) => s.ticket));

    if (ticket == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      // On system back, reset booking and go home
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          ref.read(bookingFlowProvider.notifier).reset();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Column(
                children: [
                  const _ConfirmedHeader(),
                  const SizedBox(height: 24),
                  Expanded(child: _BoardingPass(ticket: ticket)),
                  const SizedBox(height: 20),
                  _ActionButtons(
                    onBackHome: () {
                      ref.read(bookingFlowProvider.notifier).reset();
                      context.go(AppRoutes.home);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmedHeader extends StatelessWidget {
  const _ConfirmedHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Booking confirmed',
          style: AppTypography.h1.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontSize: 21,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your e-ticket is ready',
          style: AppTypography.body.copyWith(color: Colors.white.withValues(alpha: 0.82)),
        ),
      ],
    );
  }
}

class _BoardingPass extends StatelessWidget {
  const _BoardingPass({required this.ticket});
  final ETicket ticket;

  @override
  Widget build(BuildContext context) {
    final trip = ticket.trip.summary;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 50,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      trip.operatorCode,
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${trip.operatorName} · ${trip.serviceClass}',
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Boarding pass',
                          style: AppTypography.overline.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Times row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.departLabel,
                        style: AppTypography.display.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          fontSize: 24,
                        ),
                      ),
                      Text('Cairo', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Icon(Icons.directions_bus_rounded, color: AppColors.primary, size: 22),
                        const SizedBox(height: 4),
                        Container(height: 2, color: AppColors.hairline),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        trip.arriveLabel,
                        style: AppTypography.display.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          fontSize: 24,
                        ),
                      ),
                      Text('Alexandria', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
            // Tear line
            Stack(
              children: [
                const Divider(height: 1, color: AppColors.hairline, indent: 14, endIndent: 14),
                Positioned(
                  left: 0,
                  child: Container(
                    width: 12,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDeep,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDeep,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            // Details row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _DetailCol(label: 'Date', value: '25 Jun 2026'),
                  _DetailCol(label: 'Seats', value: ticket.seats.join(', ')),
                  _DetailCol(label: 'Gate', value: ticket.gate),
                ],
              ),
            ),
            // QR code (decorative placeholder)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 22),
              child: Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.bgBase,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_rounded,
                    size: 80,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCol extends StatelessWidget {
  const _DetailCol({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.overline.copyWith(color: AppColors.textMuted)),
        Text(
          value,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.onBackHome});
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TicketButton(
                label: 'Download',
                icon: Icons.download_rounded,
                solid: true,
                onTap: () => ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(content: Text('Coming soon'))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TicketButton(
                label: 'Share',
                icon: Icons.share_rounded,
                solid: false,
                onTap: () => ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(content: Text('Coming soon'))),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onBackHome,
          child: Text(
            'Back to home',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.85),
              decoration: TextDecoration.underline,
              decorationColor: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketButton extends StatelessWidget {
  const _TicketButton({
    required this.label,
    required this.icon,
    required this.solid,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool solid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: solid ? AppColors.bgElevated : Colors.white.withValues(alpha: 0.14),
          border: solid ? null : Border.all(color: Colors.white.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(15),
        ),
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: solid ? AppColors.primary : Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w800,
                color: solid ? AppColors.primary : Colors.white,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 13.2 — Verify and commit**

```bash
flutter analyze lib/features/booking/presentation/eticket_screen.dart
git add lib/features/booking/presentation/eticket_screen.dart
git commit -m "feat(booking): E-ticket / booking confirmed screen"
```

---

## Task 14 — Final integration pass

- [ ] **Step 14.1 — Run full analysis**

```bash
flutter analyze
```

Expected: no errors. Ignore any `info`-level hints about `unused_import` if they're in generated files.

- [ ] **Step 14.2 — Run all tests**

```bash
flutter test
```

Expected: all tests pass, including the 9 notifier tests.

- [ ] **Step 14.3 — Smoke-test the flow manually**

```bash
flutter run
```

Walk through:
1. App launches → Splash → Home (blue hero, search card, destinations)
2. Tap "Search Buses" → Trip results (3 cards: Go Bus, Blue Bus, SuperJet)
3. Tap "Select" on Go Bus → Trip details (route timeline, amenities, price)
4. Tap "Choose seats" → Seat selection grid
5. Tap any 2 available seats → price updates in bottom panel
6. Tap "Continue" → Review & confirm (trip summary, passenger, wallet selected)
7. Tap "Confirm booking" → E-ticket with QR code
8. Tap "Back to home" → Home (booking state cleared)
9. Verify nav bar non-Home tabs show "Coming soon" snackbar

- [ ] **Step 14.4 — Tag and final commit if clean**

```bash
git add -A
git commit -m "feat(booking): complete bus-booking flow — screens 07–13"
```
