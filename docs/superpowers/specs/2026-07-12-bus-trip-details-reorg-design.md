# Bus trip details — reorganize around stop choosing

> Design spec · 2026-07-12
> Feature slice: `lib/features/bus`
> Builds on `2026-07-08-bus-flow-redesign-design.md`; supersedes the
> winding-road revision in `2026-07-11-bus-booking-stepper-route-timeline-design.md`.

## Problem

The Route step of the booking wizard (`/trips/detail`,
`BusTripDetailsScreen`) does too much on one screen: a tall boarding-pass
style ticket card (own mini timeline + fare stub), a duplicate amenities
chips section, and an interactive winding-road stop picker whose gesture
model (tap = focus only, long-press = role menu) is not discoverable.

## Scope

UI-only, trip-details screen only. `BusBookingState`, the notifier
(`setStops`, `segmentFare`, `selectTrip`), routes, entities, and the API are
unchanged. Results, seat selection, confirm, and e-ticket screens are
untouched.

## Screen's job

One job: let the rider choose boarding + drop-off stops and see the live
fare. Trip identity (operator, times, amenities) is secondary confirmation
context, not the headline.

## New composition (top → bottom)

1. `BookingStepBar(current: route)` — unchanged.
2. **Compact trip header card** (`_TripHeaderCard`, replaces `_TripTicketCard`):
   operator avatar + name + `serviceClass`, `AmenityIconsRow`, and one compact
   `07:00 → 09:30 · 2h 30m` line computed from the *currently selected* stops
   (falls back to `trip.departTime`/`arriveTime` if a stop has no
   `arrivalAt`), updating live as stops change. Tapping the amenity icons
   opens a bottom sheet with labeled `AmenityChip`s (reuses `amenityIconFor`
   and the existing label mapping). No ticket notch, no fare stub — fare
   lives only in the footer.
3. **`RouteTimeline`** (new widget, replaces `RouteRoad`): a single vertical
   timeline split into two labeled, single-tap zones:
   - **Board at** — boarding stops sorted by `arrivalAt` (nulls first),
     accent `AppColors.primary`.
   - **Drop off at** — drop-off stops, accent `AppColors.secondary`, each row
     showing a small muted trailing fare (`stop.finalPrice` + currency) so
     the fare-per-stop relationship is visible while choosing.
   - Row = dot on a shared connector + stop name/city + time (trailing);
     tapping a row in its zone calls `onBoardSelected`/`onDropoffSelected`.
     No long-press, no separate focus state — a single tap both focuses and
     selects.
   - Selected rows get a filled dot, accent text, and a pill
     (`tripDetailBoardHere` / `tripDetailDropOffHere`); the connector between
     the selected pair is emphasized; rows outside the pair dim to
     `textMuted` but stay tappable.
   - RTL: plain `Row` + directional padding, no direction-implying icons.
4. Fare-hint caption (`tripDetailFareLiveHint`) moves under the timeline.
5. `_PriceFooter` (live fare total + "Choose seats") — unchanged.

## Rationale for approach ("straight timeline" over sequential steps or a
two-field picker)

A single always-visible timeline keeps both choices and their consequence
(the fare) on screen at once — closest to the winding road's information
density but without the ambiguous gesture split. It's also the smallest
change: `RouteTimeline` is a drop-in replacement for `RouteRoad` with the
same constructor shape, so `setStops` wiring in `trip_details_screen.dart`
does not change.

## Data

No new entities. Reuses `BusStop { locationId, name, cityId, cityName,
arrivalAt?, finalPrice, originalPrice }`, `BusTripSummary.boardingStops` /
`.dropoffStops`, and the existing `_byArrival` null-first sort convention
from `RouteRoad`.

## Files

**New**
- `lib/features/bus/presentation/widgets/route_timeline.dart`
- `test/features/bus/presentation/route_timeline_test.dart`

**Modified**
- `lib/features/bus/presentation/trip_details_screen.dart`
- `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` (+ generated localizations) —
  add `tripDetailBoardAt` / `tripDetailDropOffAt`
- `test/features/bus/presentation/trip_details_screen_test.dart`

**Deleted**
- `lib/features/bus/presentation/widgets/route_road.dart`
- `test/features/bus/presentation/route_road_test.dart`

## Edge cases

- Single boarding and/or single drop-off stop: still renders as a one-row
  zone; that stop is the pre-seeded selection.
- Empty `boardingStops`/`dropoffStops`: falls back to
  `defaultBoardingStop`/`defaultDropoffStop` (already seeded into
  `fromStop`/`toStop`).
- Null `arrivalAt`: row renders without a time; sorts first (same as today).
- Header's compact time line: if a selected stop lacks `arrivalAt`, falls
  back to `trip.departTime`/`arriveTime`.

## Testing

- `RouteTimeline` widget test: renders all stops in both zones in order,
  shows drop-off fares, marks selected board/drop-off with pills, dims
  out-of-range rows, fires the right callback on a tap in each zone.
- `trip_details_screen_test.dart`: updated for the new header + timeline
  composition (tap-based selection instead of long-press + menu); RTL case
  unchanged in intent.
- `flutter analyze && flutter test` clean.

## Verification

Run the app on a mobile emulator/device (REGO is mobile-only — no web
preview). Search a bus trip → results → open a trip. Confirm: the compact
header updates times as stops change; tapping amenity icons opens the
labeled sheet; a single tap on a boarding/drop-off row moves the selection
and the footer fare updates; drop-off rows show per-stop fares; rows outside
the selected pair are dimmed but tappable. Repeat in Arabic (RTL).
