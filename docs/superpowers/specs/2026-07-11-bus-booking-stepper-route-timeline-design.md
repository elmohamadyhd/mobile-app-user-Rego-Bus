# Bus booking — stepped timeline flow + full-route stop picker

> Design spec · 2026-07-11
> Feature slice: `lib/features/bus`
> Builds on the approved `2026-07-08-bus-flow-redesign-design.md`.

> **Revision (2026-07-11, post-implementation):** Step 1's stop picker shipped
> as an **interactive winding road** (`RouteRoad`, `route_road.dart`) instead of
> the straight vertical `RouteTimeline` described below. Stops lay out on a
> snaking, road-drawn path (CustomPainter) with name + time labels; **tap**
> focuses a stop and **long-press** opens a role menu (pickup / drop-off) with
> only the valid side enabled. All other sections (step bar, seat step, confirm
> recap, data flow, `setStops` wiring) are unchanged from this spec.

## Goal

Turn the post-search bus booking into a guided **3-step wizard** with a visible
progress timeline, and make Step 1 a **full-route timeline** where the rider sees
every stop in order and taps to choose where they get on and off.

Steps: **Route → Seat → Confirm**

1. **Route** — see the whole route as one vertical timeline; tap to change the
   pickup (boarding) and drop-off stops. Fare updates live.
2. **Seat** — choose seats (existing seat grid).
3. **Confirm** — recap of *everything the rider chose* (operator, chosen stops +
   times, date, seats, price, payment), then book.

## Non-goals (YAGNI)

- No routing rewrite. The existing three `GoRoute`s and `push`/`pop` navigation stay.
- No merge into a single `PageView`/`Stepper` host screen.
- No new API calls. No change to `BusRepository` or the network layer.
- No change to `BusBookingState`'s data fields or notifier methods.
- No range-select gesture, no map, no seat-map changes.
- Results screen (`/trips`) and e-ticket screen (`/booking/ticket`) are untouched.

## Current state (what exists today)

Flow after search, all sharing one `busBookingProvider`:

| Route | Screen | Role |
|-------|--------|------|
| `/trips` | `TripResultsScreen` | trip list (not part of the wizard) |
| `/trips/detail` | `BusTripDetailsScreen` | ticket card + amenities + **two `StopSelector` lists** (board / drop-off) + "Choose seats" |
| `/trips/seats` | `SeatSelectionScreen` | seat grid + "Continue" |
| `/trips/confirm` | `PassengerConfirmScreen` | trip summary + passenger + payment + price + "Confirm booking" |
| `/booking/ticket` | `BusTicketScreen` | e-ticket (flow end) |

Navigation is linear `context.push`; back is `context.pop()`. All three booking
screens use `BookingAppBar(title, subtitle?)`.

Relevant data (`BusTripSummary`):

- `boardingStops: List<BusStop>` — all in the **origin city**.
- `dropoffStops: List<BusStop>` — all in the **destination city**.
- Each `BusStop { locationId, name, cityId, cityName, arrivalAt?, finalPrice, originalPrice }`.
- Origin stops always precede destination stops in time ⇒ **any board + any
  drop-off pair is valid**; no cross-validation needed.
- `setStops({from, to})` updates the pair and recomputes `segmentFare`
  (`to.finalPrice`); this already drives the live fare + footer.

## Design

### 1. Step model + `BookingStepBar` widget

New enum (presentation-only, lives with the widget or in `bus_routes.dart`):

```dart
enum BusBookingStep { route, seat, confirm }
```

New widget `lib/features/bus/presentation/widgets/booking_step_bar.dart`:

```
BookingStepBar({ required BusBookingStep current })
```

- Renders 3 nodes on a connecting line: Route → Seat → Confirm, each with an
  icon + label. Labels localized.
- Node states by index vs `current`:
  - **completed** (index < current): filled `AppColors.primary` + check icon;
    **tappable** → navigates back to that step.
  - **current** (index == current): filled/emphasized, label bold.
  - **upcoming** (index > current): muted outline (`AppColors.hairline` /
    `textMuted`), not tappable.
- Connector segment before/at the current step is `AppColors.primary`; segments
  after are `AppColors.hairline`.
- **RTL**: built with a plain `Row` so order flips automatically in Arabic; icons
  that imply direction are not used inside the bar (nodes are symmetric).
- **Back navigation on tap of a completed step:** pop the nav stack
  `current.index - target.index` times via `context.pop()`. Guard each pop with
  `context.canPop()`. Rationale: the three screens are sequential pushes, so
  popping N frames returns to the target screen with its state intact. Forward
  jumps are not possible from the bar (gated by each screen's CTA).

Placement: rendered as the **first child of each booking screen's body**, directly
under `BookingAppBar`, inside the existing `Scaffold`. `BookingAppBar` itself is
**not modified** (keeps it isolated/reusable).

- `BusTripDetailsScreen` → `BookingStepBar(current: BusBookingStep.route)`
- `SeatSelectionScreen` → `BookingStepBar(current: BusBookingStep.seat)`
- `PassengerConfirmScreen` → `BookingStepBar(current: BusBookingStep.confirm)`

### 2. Step 1 "Route" — `RouteTimeline` widget

New widget `lib/features/bus/presentation/widgets/route_timeline.dart`:

```
RouteTimeline({
  required List<BusStop> boardingStops,
  required List<BusStop> dropoffStops,
  required BusStop selectedFrom,
  required BusStop selectedTo,
  required void Function(BusStop) onBoardSelected,
  required void Function(BusStop) onDropoffSelected,
})
```

Behavior:

- Builds one ordered display list: `boardingStops` (sorted by `arrivalAt`, nulls
  last) followed by `dropoffStops` (same sort). Each entry tagged as a **board
  candidate** or **drop-off candidate** by which list it came from.
- Each row = a dot on a shared vertical connector + time (trailing) + stop name +
  city name.
- **Board candidates** styled blue (`AppColors.primary`); tapping calls
  `onBoardSelected(stop)`. The selected board stop gets a filled dot + a
  "Board here" pill.
- **Drop-off candidates** styled amber (`AppColors.secondary`); tapping calls
  `onDropoffSelected(stop)`. The selected drop-off gets a filled dot + a
  "Drop off" pill.
- The connector line **between** the selected board and drop-off is emphasized
  (solid, colored); rows **before** the selected board or **after** the selected
  drop-off dim to `textMuted` but remain tappable (re-pick).
- Stops with null `arrivalAt` render without a time.
- **RTL**: connector column leads (`Row` with the connector first, directional
  padding), times on the trailing side — same approach as the existing
  `_TicketTimeline`.

Integration in `BusTripDetailsScreen`:

- Remove the two `StopSelector` sections (widget file `stop_selector.dart` becomes
  unused; delete it and its import).
- Add one `RouteTimeline` section (with a "Trip route" section title) in their place.
- Wire callbacks to the notifier:
  - `onBoardSelected: (s) => notifier.setStops(from: s, to: currentTo)`
  - `onDropoffSelected: (s) => notifier.setStops(from: currentFrom, to: s)`
- Keep the `_TripTicketCard` (operator + amenities + selected-journey summary +
  live fare stub) and the `_AmenitiesSection` and `_PriceFooter` as they are.

### 3. Step 2 "Seat"

No functional change. Add `BookingStepBar(current: seat)` at the top of the body
(above the existing `_LegendRow`). Everything else — legend, grid, bottom panel —
unchanged.

### 4. Step 3 "Confirm" — full choice recap

Enrich `_BusTripSummaryCard` in `PassengerConfirmScreen` so the recap shows all
choices. Add, to what already exists (operator + class, seat count pill):

- A compact **route recap**: boarding stop (`name · cityName · time`) →
  drop-off stop (`name · cityName · time`), rendered as a small two-point
  from→to block (reuse the visual language of `_TicketTimeline` — a mini
  timeline, not the full interactive `RouteTimeline`).
- The **trip date** (from `state.searchParams.date`, formatted via the existing
  `date_formatting` util).
- The **selected seat numbers** as chips (already available as `state.selectedSeats`).

The existing `_PassengerSection`, `_PaymentSection`, `_PriceBreakdown`, and the
"Confirm booking" CTA stay. Add `BookingStepBar(current: confirm)` at the top of
the body.

### 5. Localization

Add keys to `lib/l10n/app_en.arb` and `app_ar.arb` (Arabic-first). Proposed keys:

| Key | en | ar (guide) |
|-----|----|-----|
| `bookingStepRoute` | Route | المسار |
| `bookingStepSeat` | Seat | المقعد |
| `bookingStepConfirm` | Confirm | التأكيد |
| `tripDetailRouteSection` | Trip route | مسار الرحلة |
| `tripDetailBoardHere` | Board here | تصعد هنا |
| `tripDetailDropOffHere` | Drop off | تنزل هنا |
| `confirmRouteSection` | Your journey | رحلتك |
| `confirmDateLabel` | Date | التاريخ |

Existing keys reused where possible (`tripDetailChooseSeats`,
`seatSelectionContinue`, `confirmBook`, `seatSelectionSeatsLabel`, etc.). The
existing `tripDetailBoardAt` / `tripDetailDropOffAt` may become unused once the
`StopSelector` lists are removed — remove them if no other references remain.

## Files touched

New:

- `lib/features/bus/presentation/widgets/booking_step_bar.dart`
- `lib/features/bus/presentation/widgets/route_timeline.dart`

Modified:

- `lib/features/bus/presentation/trip_details_screen.dart` (step bar; swap stop
  lists for `RouteTimeline`)
- `lib/features/bus/presentation/seat_selection_screen.dart` (step bar)
- `lib/features/bus/presentation/passenger_confirm_screen.dart` (step bar; enrich
  recap card)
- `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` (+ generated localizations)
- `bus_routes.dart` **only if** `BusBookingStep` is placed there (optional)

Removed:

- `lib/features/bus/presentation/widgets/stop_selector.dart` (superseded by
  `RouteTimeline`), if no remaining references.

## Edge cases

- Single boarding stop and/or single drop-off stop: still render; that stop is the
  (pre-seeded) selection. Timeline is informative even with one option per end.
- Empty `boardingStops` / `dropoffStops`: fall back to `defaultBoardingStop` /
  `defaultDropoffStop` (already seeded into `fromStop`/`toStop`), so the timeline
  shows at least the default pair.
- Null `arrivalAt`: row shows no time.
- Deep-linking / provider reset mid-flow: each screen already guards
  `selectedTrip == null`; `BookingStepBar` is presentational and safe to render
  regardless.
- Back button vs step-bar tap: both use `context.pop()`; behavior is consistent.

## Testing

- Widget test: `RouteTimeline` renders all stops in order, marks the selected
  board/drop-off, and fires `onBoardSelected`/`onDropoffSelected` on tap of the
  right group.
- Widget test: `BookingStepBar` renders correct node states for each `current`
  value; tapping a completed node pops.
- Widget test: confirm recap shows chosen stop names, date, and seat chips.
- `flutter analyze && flutter test` clean.

## Verification

Run the app (`/run`), open a bus trip: confirm the step bar appears on all three
screens, the route timeline lets you change board/drop-off with live fare, the
confirm step lists the chosen stops + seats, and tapping a completed step returns
to it. Verify in Arabic (RTL) too.
