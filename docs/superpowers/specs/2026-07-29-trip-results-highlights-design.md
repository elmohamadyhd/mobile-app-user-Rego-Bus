# Trip Results Fastest / Cheapest Marks — Design Spec
_Date: 2026-07-29 | Status: approved_

## Scope

On bus trip **search results**, flag trips that are the **cheapest** and/or
**fastest** in the loaded search, show a header badge on those cards, and
add **Cheapest** / **Fastest** options to the existing filter sheet (chips
+ clear). Clearing filters removes the filter chips but **keeps** the
badges on cards.

## Out of scope

- Backend-provided `isCheapest` / `isFastest` fields
- Recomputing marks when the rider changes boarding/drop-off on a card
- Flight / private-car results
- Auto-sorting by price or duration without an explicit highlight filter
- New sort tabs outside the filter sheet

## Decisions (from brainstorming)

| Topic | Choice |
|---|---|
| Same trip wins both | Single **Best deal** badge (not two pills) |
| Ties | Badge **every** tied trip |
| Mark source | Full loaded search (`state.trips`), not the filtered subset |
| Metrics | `terminalPriceEgp` (cheapest), `durationMin` (fastest) |
| Stop picks on card | Do **not** recompute marks |
| Filter chips | Normal chips; clear removes chips, marks remain |
| Highlight filter behavior | Keep marked trips **and** pin them to the top |
| Both chips on | **Union** (cheapest OR fastest); Best deal first |
| Badge placement | Header trailing end (next to operator · class) |
| Architecture | Domain helper + `BusTripFilters` fields (Approach 2) |

## Marking rules

Given the full list `trips` from search (before client filters):

1. `minPrice = min(trip.terminalPriceEgp)` over non-empty list.
2. `minDuration = min(trip.durationMin)` over non-empty list.
3. A trip is **price-winning** if `terminalPriceEgp == minPrice`.
4. A trip is **duration-winning** if `durationMin == minDuration`.
5. Highlight for trip id:
   - both → `TripHighlight.bestDeal`
   - price only → `TripHighlight.cheapest`
   - duration only → `TripHighlight.fastest`
   - neither → absent from map / `null` on card

Empty search → empty highlight map.

## Filters & list order

Extend `BusTripFilters` with:

- `bool cheapest` (default `false`)
- `bool fastest` (default `false`)

Pipeline on results screen:

1. Apply existing constraints (operators, depart window, price range)
   **and** highlight flags when set.
2. If `cheapest` and/or `fastest` is true, keep trips whose highlight is
   in the requested set:
   - `cheapest` alone → `cheapest | bestDeal`
   - `fastest` alone → `fastest | bestDeal`
   - both → union of those sets
3. Sort:
   - Rank 0: `bestDeal`
   - Rank 1: other marked (`cheapest` or `fastest`)
   - Rank 2: unmarked
   - Within rank: earliest `departTime` first

Clear-all / remove chips sets `cheapest`/`fastest` to false. Highlight
map is recomputed only from `state.trips`, so badges stay.

When highlight filters leave zero trips → existing empty state
(`tripResultsNoMatchingTrips` + clear).

## UI

### Card badge

- `TripCard` accepts optional `TripHighlight? highlight`.
- Pill at header **trailing** end (RTL-safe `Row` end), sized like
  `OrderStatusBadge`.
- Colors (tokens only):
  - Cheapest → `secondaryTint` / `onSecondary`
  - Fastest → `success` @ ~14% alpha / `success`
  - Best deal → `primaryTint` / `primary`
- Labels via l10n (reuse `tripResultsSortCheapest` for cheapest where
  wording matches; add keys for fastest + best deal if missing).
- Include mark in the card’s accessibility label.

### Filter sheet

- New section (above or below operators): two switches/toggles —
  Cheapest, Fastest — bound to draft `BusTripFilters`.
- Active chips use new `ActiveFilterChipKind.cheapest` /
  `.fastest` with localized labels.
- `busTripFilterActiveCount` includes these flags.

## Architecture

| Piece | Location |
|---|---|
| `TripHighlight` enum | `lib/features/bus/domain/entities/trip_highlight.dart` |
| `computeTripHighlights` | `lib/features/bus/domain/utils/compute_trip_highlights.dart` |
| `sortTripsWithHighlights` | same utils file (or adjacent) |
| Filter fields + chips | `bus_trip_filters.dart` (+ freezed codegen) |
| Match + count | `apply_bus_trip_filters.dart` |
| Wire-up | `trip_results_screen.dart` |
| Badge | `trip_card.dart` |
| Toggles | `trip_filter_sheet.dart` |

Presentation imports domain only. No cross-feature imports.

## Testing

- Unit: ties, best-deal, empty list, filter union, pin order,
  clear-filters independence of marks.
- Widget: badge on card; chip apply/remove; clear chips keeps badge.

## Error / edge cases

- Single trip in search → it is Best deal if it is both min price and
  min duration (always both when n=1).
- All trips same price and duration → all Best deal.
- Highlight filter + other filters: apply all conjunctively (must match
  operator/time/price **and** highlight set).
