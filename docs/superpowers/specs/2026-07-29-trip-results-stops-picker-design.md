# Trip Results Stops Picker — Design Spec
_Date: 2026-07-29 | Status: approved_

## Scope

Let riders **preview and pick** boarding + drop-off stops from a trip
results card **before** tapping Select. Picks update that card only
(names, cities, times, fare). Select still starts booking, seeding the
chosen pair into `busBookingProvider`.

Builds on the current `TripCard` (governorate labels, combined stops
count on the duration line, ticket shape). Does not replace trip-details
`RouteTimeline`.

## Out of scope

- Picking stops that immediately call `selectTrip` / navigate
- Inline card expand (no sheet)
- Per-side sheets (boarding-only / drop-off-only)
- Embedding full interactive `RouteTimeline` (coach marks, long-press Maps)
- Changing trip-details, seat map, or payment flows beyond seeding stops
- New backend fields — use existing `boardingStops` / `dropoffStops`

## Problem

Each `BusTripSummary` already carries alternate `stations_from` /
`stations_to`, but the results card only shows one boarding stop and the
**terminal** drop-off, plus a combined “N stops” label. Riders who care
about a specific station or fare must enter trip details first. There is
no way to preview alternatives or lock a pair on the results list.

## Decisions (from brainstorming)

| Topic | Choice |
|---|---|
| Intent | Preview **and** pick |
| Chrome | One bottom sheet opened from the stops count |
| After Apply | Update **card only**; Select still continues booking |
| Architecture | Card-local picks + sheet; seed `selectTrip` on Select |

## Approach

### Entry

On `TripCard`, the stops portion of `_DurationStopsLabel` (e.g. “4 stops”
/ “4 محطات”) is tappable when `trip.stopsCount > 0`.

- Tap opens the stops sheet for **that** trip.
- Tap does **not** trigger Select / `onTap`.
- Duration text stays non-interactive (or the whole duration+stops row
  may share the stops hit target only on the stops chip — prefer
  wrapping only the stops `Text` in an `InkWell` / `GestureDetector` with
  min 48×48 touch target via padding).

When `stopsCount == 0`, keep today’s non-tappable label (duration only).

### Sheet

Modal bottom sheet (`showModalBottomSheet`), scrollable, SafeArea,
`AppRadius.sheet`, tokens from `AppColors` / `AppSpacing` / `AppTypography`.

**Contents**

1. Title — new l10n key `tripResultsStopsSheetTitle` (“Stops” / “المحطات”).
2. Boarding zone — header reuse `tripDetailBoardAt`; list
   `trip.boardingStops` (non-empty only).
3. Drop-off zone — header reuse `tripDetailDropOffAt`; list
   `trip.dropoffStops`.
4. Primary CTA — `tripResultsStopsApply` (“Apply” / “تطبيق”).

**Row**

- Stop name (primary), city name (secondary), time if `arrivalAt != null`.
- Drop-off rows also show fare: `{finalPrice.round()} {currency}`.
- Selected row uses primary/secondary accent tint (boarding = primary,
  drop-off = secondary), matching timeline dots on the card.
- One selection per zone.

**Draft state**

- Opening the sheet seeds draft from the card’s **current** display pair
  (not always API defaults — if the user already Applied once, re-open
  with those picks).
- Dismiss (drag / scrim / back) without Apply → discard draft.
- Apply → write draft into card-local state and close.

Apply is enabled only when both zones have a non-empty selection
(`locationId` non-empty).

No Maps affordance in this sheet.

### Card after Apply

`TripCard` holds local `BusStop selectedFrom` / `selectedTo`:

| Field | Initial default |
|---|---|
| `selectedFrom` | `trip.defaultBoardingStop` |
| `selectedTo` | `trip.terminalDropoffStop` |

After Apply, the card renders:

- Times from `selectedFrom.arrivalAt` / `selectedTo.arrivalAt` (same
  `_formatTime` rules as today; fall back to trip-level times if null).
- Duration from the selected pair’s time difference (same formula as
  `terminalDurationLabel`, but for the selected pair).
- City + station from the selected stops.
- Fare stub from `selectedTo.finalPrice.round()` and `trip.currency`.
- Stops count label still `trip.stopsCount` (total options, not “extras”).

List identity: when the parent rebuilds the same trip from search
results, keep picks by making `TripCard` a `StatefulWidget` keyed with
`ValueKey(trip.id)` so state survives list rebuilds/filter refreshes
for the same id. New search → new list → fresh defaults.

### Select

`TripCard.onTap` becomes:

```dart
void Function({required BusStop from, required BusStop to}) onSelect;
```

Results screen:

```dart
onSelect: ({required from, required to}) =>
  _selectTrip(trips[i], from: from, to: to),
```

Extend notifier:

```dart
Future<void> selectTrip(
  BusTripSummary trip, {
  BusStop? from,
  BusStop? to,
}) async
```

Seed:

- `fromStop`: `from ?? trip.defaultBoardingStop`
- `toStop`: `to ?? trip.terminalDropoffStop`
- `segmentFare`: chosen `toStop.finalPrice`

**Enrichment rule:** after `tripById` merge, keep the user-seeded
`fromStop` / `toStop` when their `locationId` is still present in the
merged boarding/drop-off lists. If a seeded id vanished after
enrichment, fall back to `merged.defaultBoardingStop` /
`merged.terminalDropoffStop`.

Trip-details `RouteTimeline` remains the place to change stops after
entry; results picks are only the initial seed.

## Data

No entity changes. Reuse:

- `BusTripSummary.boardingStops` / `dropoffStops` / `stopsCount`
- `BusStop` (`name`, `cityName`, `arrivalAt`, `finalPrice`, `locationId`)
- Existing `orderTripRouteStops` sort optional — sheet may list in API
  order or arrival order; prefer `orderTripRouteStops` for consistency
  with trip details.

## Localization

Add to `app_en.arb` + `app_ar.arb`, then `flutter gen-l10n`:

| Key | EN | AR |
|---|---|---|
| `tripResultsStopsSheetTitle` | Stops | المحطات |
| `tripResultsStopsApply` | Apply | تطبيق |

Reuse `tripDetailBoardAt`, `tripDetailDropOffAt`, existing stops-count
plural.

All new UI strings via `AppLocalizations` — no hardcoded copy in
widgets.

## RTL / BiDi

- Sheet and card use directional layout (`EdgeInsetsDirectional`,
  `CrossAxisAlignment.start` / end as today).
- Keep duration (`LtrText`) and stops count as **separate** widgets
  (already required for Arabic).
- Operator / class remain separate widgets.
- Latin stop names / times: prefer separate widgets or `LtrText` for
  time runs; do not concatenate Arabic + Latin into one string.

## Accessibility

- Stops count tappable control: semantic button label from
  `tripResultsStopsCount` (or “View stops”); min touch target 48dp.
- Sheet rows: selected state announced; Apply disabled when incomplete.
- Select button unchanged.

## Error / edge cases

| Case | Behavior |
|---|---|
| Empty boarding or drop-off list | Hide that zone; Apply stays disabled if either side missing a pick |
| Single stop per side | Sheet still opens (preview); Apply keeps that pair |
| Filter refresh, same `trip.id` | `ValueKey(trip.id)` preserves card picks |
| New search | New cards → defaults |
| Select while another card loading | Unchanged — ignore second tap |

## Testing

- Widget: tapping stops count opens sheet; does not call `onSelect`.
- Widget: Apply updates displayed station names + fare on the card.
- Widget: Select callback receives Applied pair (not defaults) after Apply.
- Widget: Arabic — stops count and sheet title render; no BiDi split of
  count + “محطات”.
- Notifier: `selectTrip(trip, from:, to:)` seeds those stops; enrichment
  keeps them when ids still exist.
- Notifier: missing optional args keep today’s default/terminal seeding.

## Files (expected)

| Path | Role |
|---|---|
| `lib/features/bus/presentation/widgets/trip_card.dart` | Local picks, tappable stops, display from selection |
| `lib/features/bus/presentation/widgets/trip_stops_sheet.dart` | New sheet UI + `showTripStopsSheet` |
| `lib/features/bus/presentation/trip_results_screen.dart` | Wire `onSelect` + `_selectTrip(..., from:, to:)` |
| `lib/features/bus/presentation/providers/bus_booking_providers.dart` | `selectTrip` optional from/to + enrichment keep rule |
| `lib/l10n/app_en.arb` / `app_ar.arb` | New keys |
| `test/features/bus/presentation/trip_card_test.dart` | Card + sheet interaction |
| `test/features/bus/presentation/trip_stops_sheet_test.dart` | Sheet selection / Apply |
| `test/features/bus/bus_booking_notifier_test.dart` | `selectTrip` seeding |

## Success criteria

1. Rider can open all boarding/drop-off options from the results card.
2. Apply updates that card’s route endpoints and fare without navigating.
3. Select enters booking with the Applied pair (details timeline shows them).
4. Arabic layout remains correct (no BiDi reversal of company/class or
   stops label).
5. Ticket card shape / tear line unchanged.
