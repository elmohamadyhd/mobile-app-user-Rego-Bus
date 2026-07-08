# Booking Flow — Design Spec
_Date: 2026-06-30 | Status: superseded_

> **Superseded (2026-07-08)** by
> [`2026-07-08-bus-flow-redesign-design.md`](2026-07-08-bus-flow-redesign-design.md),
> which rebases the bus flow on the real `/buses/*` API (city→station model,
> per-segment stop pricing, per-seat classes) and the per-mode feature
> architecture in `2026-07-08-multi-vehicle-architecture-design.md`. This
> document is kept for history — the screen designs below are still a useful
> visual reference, but the single flat-price `BookingFlowNotifier` and the
> stop chips crammed into the results card are replaced there.

## Scope

Build 6 screens for the core bus-booking journey, faithfully matching `design/V1/REGO Buses - Batch 1+2.dc.html` (screens 07–13):

| # | Screen | Route |
|---|--------|-------|
| 07 | Home (full rebuild) | `/` |
| 09 | Trip results | `/trips` |
| 10 | Trip details | `/trips/detail` |
| 11 | Seat selection | `/trips/seats` |
| 12 | Passenger & confirm | `/trips/confirm` |
| 13 | E-ticket | `/booking/ticket` |

Out of scope: real API integration, payment processing, other transport modes (Flight/Train/Private — tabs exist but are inactive).

---

## Architecture: Approach A — Single Booking Notifier

All booking state lives in one Riverpod `Notifier<BookingFlowState>`. No route args are passed between booking screens — screens read/mutate this provider directly. Navigation is triggered by the notifier after state transitions.

### Why A over B (GoRouter args)

B is cleaner for testability, but A is faster to build and the booking flow is a linear wizard where shared state is the rule, not the exception. Real API wiring (a future task) can introduce per-screen providers at that point.

---

## State

```dart
// features/booking/presentation/providers/booking_providers.dart

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
```

### Notifier actions

| Method | Effect | Navigation |
|--------|--------|-----------|
| `searchTrips(from, to, date)` | status → loadingTrips → idle, populates `trips` | caller pushes `/trips` |
| `selectTrip(TripSummary)` | sets `selectedTrip`, loads mock `tripDetail` | caller pushes `/trips/detail` |
| `toggleSeat(String id)` | adds/removes id from `selectedSeats` | — |
| `setPaymentMethod(PaymentMethod)` | updates `paymentMethod` | — |
| `confirmBooking()` | status → confirming → confirmed, produces `ticket` | caller pushes `/booking/ticket` |
| `reset()` | clears all fields back to initial state | — |

---

## Entities (Freezed, no JSON yet)

### `TripSummary`
```
id, operatorName, operatorCode (2-char e.g. "GB"),
serviceClass ("VIP" / "Deluxe" / "Economy"),
departTime, arriveTime (TimeOfDay),
durationMin (int), priceEgp (int), seatsLeft (int)
```

### `TripDetail` (extends summary snapshot)
```
terminalFrom, terminalFromSub,
terminalTo, terminalToSub,
amenities: List<String>   // ["Wi-Fi", "A/C", "Sockets", "Water"]
```

### `SeatStatus` enum
`available | booked | selected`

### `SeatCell`
```
id (e.g. "A3"), status: SeatStatus
```

### `SeatRow`
```
cells: List<SeatCell?>   // null = aisle gap
```

### `ETicket`
```
bookingRef (String),
trip: TripDetail snapshot,
seats: List<String>,
passengerName, gate (String),
issuedAt: DateTime
```

---

## Mock Data (`data/mock_booking_data.dart`)

- 3 trip results: Go Bus VIP (180 EGP, 6 seats, 3h30m), Blue Bus Deluxe (150 EGP, 12 seats, 3h10m), SuperJet Economy (120 EGP, 2 seats, 3h45m)
- Trip detail for Go Bus VIP: Cairo Gateway / Abbassia, Alexandria / Moharam Bek, amenities: Wi-Fi + A/C + Sockets + Water
- Seat layout: 5 rows × 4 seats (2+aisle+2), with A1/B2/D4 booked, A3+A4 pre-selected in the design snapshot
- Wallet balance: 340.50 EGP

---

## File Layout

```
lib/features/
  home/presentation/
    home_screen.dart              ← full rebuild (StatefulWidget — tab state)
    widgets/
      home_search_card.dart       ← transport tabs + From/To form + Search btn
      popular_destinations.dart   ← 2 gradient cards row
      main_nav_bar.dart           ← floating white pill, 5 items

  booking/
    domain/entities/
      trip.dart                   ← TripSummary + TripDetail (Freezed + codegen)
      seat.dart                   ← SeatCell, SeatRow, SeatStatus
      booking.dart                ← ETicket (Freezed + codegen)
    data/
      mock_booking_data.dart      ← static fake data
    presentation/
      providers/
        booking_providers.dart    ← BookingFlowState, BookingFlowNotifier
      trip_results_screen.dart
      trip_details_screen.dart
      seat_selection_screen.dart
      passenger_confirm_screen.dart
      eticket_screen.dart
      widgets/
        booking_app_bar.dart      ← white PreferredSizeWidget (back + title + action)
        trip_card.dart            ← card used in results list
        seat_grid.dart            ← bus layout grid widget
        amenity_chip.dart         ← icon + label chip
```

---

## Routes

Added to `core/router/app_router.dart` and `AppRoutes`:

```dart
static const trips        = '/trips';
static const tripDetail   = '/trips/detail';
static const tripSeats    = '/trips/seats';
static const tripConfirm  = '/trips/confirm';
static const eTicket      = '/booking/ticket';
```

All 5 new routes are **auth-guarded** (already handled by the existing router redirect logic — they are not in `_authRoutes`).

---

## Screen-by-screen design

### 07 Home (rebuild)

**Widget:** `StatefulWidget` (owns `_selectedTab` int).

**Layout:**
1. Blue gradient hero (`LinearGradient 160° #1D6FF2→#0E50C7→#0A3FA3`, `borderRadius 0 0 40 40`): avatar circle + greeting, notification bell (amber dot badge), "Book your trip in one tap" headline + decorative circles
2. `HomeSearchCard` floats over hero with negative top margin (`-24px`), white, `borderRadius 24`, shadow
   - Transport tabs row (Bus / Private / Flight / Train) — only Bus is functional
   - From/To input pair separated by a hairline, swap circle button (blue, right-aligned)
   - Date row (calendar icon + "Today, 25 Jun") + pax label (right)
   - Search button (blue, full-width, shadow)
3. "Popular destinations" header + "See all"
4. Two gradient destination cards (Luxor blue, Aswan amber) side by side
5. `MainNavBar` at bottom (position absolute, `bottom: 30`, floating pill)

**`MainNavBar`:** 5 items — Home (blue, active), Tickets (muted), Search FAB (blue circle, `translateY(-18)`), Wallet (muted), Profile (muted). Non-Home tabs call `reset()` on booking notifier and show "Coming soon" snackbar.

### 09 Trip results

**Widget:** `ConsumerWidget`, watches `bookingFlowProvider.select((s) => (s.trips, s.status))`.

**Layout:**
1. White top bar (back arrow, "Cairo → Alexandria" title, 1 pax subtitle, blue filter button)
2. Sort chips row (Times selected/blue, Cheapest muted, Seats muted) — UI only, no sort logic
3. Scrollable list of `TripCard` widgets (gap 12px)

**`TripCard`:**
- Operator logo circle (colored bg + 2-char code), name + class, seats-left badge (amber ≥3, red <3)
- Depart time, duration line (blue dot → amber dot), arrive time
- Hairline divider, price (blue large) + "Select" button
- On tap: `notifier.selectTrip(trip)` then `context.push(AppRoutes.tripDetail)`

### 10 Trip details

**Widget:** `ConsumerWidget`, watches `bookingFlowProvider.select((s) => s.tripDetail)`.

**Layout:**
1. `BookingAppBar` ("Trip details")
2. Operator card (logo, name, class, star rating badge amber)
3. Route timeline card: vertical connector (blue circle → amber dot, flex line between), departure/arrival with station sub-labels and times
4. Amenities section: `Wrap` of `AmenityChip` (Wi-Fi, A/C, Sockets, Water) with blue stroke SVG icons
5. Price footer card (label + price) — sticky at bottom
6. "Choose seats" `PrimaryButton` → `context.push(AppRoutes.tripSeats)`

### 11 Seat selection

**Widget:** `ConsumerStatefulWidget` (for seat toggle interactions).

**Layout:**
1. `BookingAppBar` ("Select seats")
2. Legend row (Available white-border, Booked gray, Selected blue)
3. `SeatGrid` widget: scrollable bus layout
   - Steering wheel icon top-right
   - Rows of `SeatCell` widgets (34×34 dp, borderRadius 8): booked=`#DCE3F0`, available=white+border, selected=blue+label
   - Aisle gap (24 dp wide) between col 2 and col 3
4. Bottom sheet panel: selected seat labels + total price + "Continue" button → `context.push(AppRoutes.tripConfirm)`

**`SeatGrid`:** pure widget, takes `List<SeatRow>` + `selectedSeats` + `onToggle` callback. Notifier mutation via `toggleSeat(id)`.

### 12 Passenger & confirm (Review & confirm)

**Widget:** `ConsumerWidget`.

**Layout:**
1. `BookingAppBar` ("Review & confirm")
2. Trip summary card (operator code + name, date, route row with timeline dots, seat labels below)
3. "Passenger" section: name field (read-only display) + phone field (read-only display) — tappable to edit (deferred: shows snackbar for now)
4. "Payment method" section: two cards side by side — Wallet (blue border, selected, shows balance) and Card (gray border). Tap to `setPaymentMethod`
5. Price breakdown card: Ticket × 2, service fee, total (blue large price)
6. "Confirm booking" `PrimaryButton` → calls `notifier.confirmBooking()`, watches `status`, on `confirmed` → `context.go(AppRoutes.eTicket)`

### 13 E-ticket

**Widget:** `ConsumerWidget`, watches `bookingFlowProvider.select((s) => s.ticket)`.

**Layout:**
1. Full-screen blue gradient background (`170° #1D6FF2 → #0A3FA3`)
2. Green checkmark circle (white outer, green inner with check SVG)
3. "Booking confirmed" + "Your e-ticket is ready" subtitle (white)
4. White boarding pass card (`borderRadius 24`, shadow):
   - Header: operator logo + "Boarding pass" label
   - Route: depart time + bus icon + arrival time
   - Dashed tear line (with half-circles cut-outs in gradient color)
   - Details row: Date, Seats, Gate
   - QR code SVG (static, decorative)
5. Two action buttons: "Download" (white bg, blue text) + "Share" (translucent white border)
6. "Back to home" gesture: `notifier.reset()` then `context.go(AppRoutes.home)` — triggered by system back or explicit button (add a subtle "Back to home" text link below buttons)

---

## Codegen

All new Freezed entities require:
```bash
dart run build_runner build --delete-conflicting-outputs
```

Run after creating the entity files before writing screens.

---

## Error handling

- `loadingTrips` status → show shimmer skeleton in `TripResultsScreen` (3 placeholder cards)
- `error` status → show inline error message with retry button
- `confirming` status → `PrimaryButton` shows loading spinner
- Seat selection requires ≥1 seat: "Continue" button disabled when `selectedSeats.isEmpty`

---

## Deferred / out of scope

- Passenger detail editing (name/phone are pre-filled read-only for now)
- Real payment gateway
- Download / Share ticket functionality (shows "coming soon" snackbar)
- Sort/filter logic on results screen
- Flight / Train / Private / Transfer flows
- Dark mode for new screens (light-only matches existing screens)
