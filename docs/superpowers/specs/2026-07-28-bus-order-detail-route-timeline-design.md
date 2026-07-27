# Bus Order Detail Route Timeline — Design Spec
_Date: 2026-07-28 | Status: approved_

## Scope

Improve the **Route** section of `BusOrderDetailSheet` so it shows real
trip departure/arrival times from `station_from` / `station_to` (not the
misleading order-level `date_time`), in a side-by-side layout. Tapping a
station opens Google Maps (confirm dialog first), reusing the existing
trip-detail Maps helper.

Extends `2026-07-15-bus-order-detail-sheet-design.md` — does not replace it.

## Out of scope

- Card layout changes
- Invoice download CTA inside the sheet
- Remapping `in_processing` status kind
- Showing city names under stations
- Review / `can_review` fields

## Problem

The Show/List order payload carries rich station objects:

```json
"station_from": {
  "id": "940",
  "name": "Sekka Club",
  "city_name": "Cairo",
  "latitude": "30.05…",
  "longitude": "31.30…",
  "arrival_at": "2026-07-30 05:45 am"
}
```

Today the mapper only extracts the station **name** into
`pickupStopLabel` / `dropoffStopLabel`, and the sheet shows a single
`dateTimeLabel` row from `date_time` (often booking/order time, e.g.
`12:01 AM`), not the trip legs.

## Approach: side-by-side + Maps on tap

Replace the flat From / To / Date `OrderInfoRow`s with a read-only
side-by-side block (same visual idea as passenger-confirm’s route row,
without city lines):

```
[ 05:45 ]            →            [ 10:00 ]
[ Sekka Club ]                    [ Moharam Bek ]
```

- Station name only (no city under the name).
- Missing `arrivalAt` → `--:--`.
- No `date_time` row in this section.
- Each side is tappable (≥48dp). Tap runs
  `confirmAndOpenStopInGoogleMaps` (existing confirm → Maps pin via
  lat/lng, else name search). Empty name → not tappable.
- Small location affordance (`AppIcons.locationTo`) so the tap target is
  discoverable; reuse existing trip-detail Maps l10n strings for the
  dialog.

## Data model

Add to `BusOrder`:

| Field | Type | Source |
|---|---|---|
| `pickupStop` | `BusStop?` | `station_from` via existing `stopFromJson` |
| `dropoffStop` | `BusStop?` | `station_to` via existing `stopFromJson` |

Reuse `BusStop` — do not invent a parallel type. City / coords stay on
the entity for Maps query fallback; UI does not render city.

Keep `pickupStopLabel` / `dropoffStopLabel` / `dateTimeLabel` for the
**card** (unchanged this pass). Mapper sets labels from stop names when
stops parse successfully (same strings the card already shows).

Null station JSON → null stop (and null label, as today).

## Mapper

In `orderFromJson`:

1. Parse `station_from` / `station_to` with a thin helper that returns
   `null` for non-maps or empty names; otherwise `stopFromJson`.
2. Set `pickupStop` / `dropoffStop` from that helper.
3. Set `pickupStopLabel` / `dropoffStopLabel` from `stop?.name` (replace
   `_stationName`-only path so one parse feeds both).

`stopFromJson` already handles `arrival_at`, lat/lng, `city_id`,
`city_name`, and string/num ids.

## Presentation

`_RouteSection` in `bus_order_detail_sheet.dart`:

- Visible when either stop is non-null.
- Header: existing `orderDetailRouteSection`.
- Body: side-by-side times + names; RTL-aware alignments; mirror the
  forward chevron in RTL (`Transform.flip` / directional icon pattern).
- Time formatting: compact `HH:mm` (match passenger confirm) for
  consistency inside the bus feature.

Card continues to use labels only — no card UI change.

## Fallbacks

| Case | Behavior |
|---|---|
| Both stops null | Hide route section |
| Stop present, no `arrivalAt` | Show `--:--` for that side |
| Stop present, no coords | Still tappable; Maps uses name (+ city in query) |
| Maps launch fails | Existing snackbar from helper |

## Testing

- Mapper: fixture with full stations asserts name, `arrivalAt`, lat/lng
  on `pickupStop` / `dropoffStop`; labels still set.
- Sheet: seed with stops shows both times + names; does **not** show
  `dateTimeLabel` as a route date row; tapping a station opens the Maps
  confirm dialog title.
- Existing sheet/card tests updated so `BusOrder` seeds compile (optional
  stop fields default null).

## Self-review notes

- No invoice/status/card scope creep.
- No new architecture layers.
- Maps path is shared (`confirmAndOpenStopInGoogleMaps`), not duplicated.
