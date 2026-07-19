# Driver Seat Normalization — Design

**Date:** 2026-07-19  
**Status:** Approved  
**Scope:** Bus seat selection (`SeatMap` → `SeatGrid`)

## Problem

The Wadeny seats API returns inconsistent driver-cell data across bus companies:

- Some responses include one or more `"class": "driver"` cells at varying positions.
- Some responses omit driver cells entirely; the first passenger seat occupies top-left.

The client rendered `seats_map` verbatim, producing duplicate steering-wheel icons or no driver icon at all.

## Root cause

`BusDtoMapper.seatMapFromEnvelope` maps JSON cells directly to `SeatMapCell` with no post-processing. `SeatGrid` chunks the flat list by `salon.columns` and renders each cell's `kind` as-is.

## Solution

Add `SeatMapNormalizer` in the domain layer. Call it from the DTO mapper immediately after parsing.

### Rule 1 — API includes at least one driver cell

1. Convert every existing `driver` cell to `space`.
2. Force `cells[0]` to `SeatMapCell(kind: driver)`.
3. Do not change cell count or `salon.rows`.

### Rule 2 — API includes zero driver cells

1. Prepend one row: `[driver, space, …, space]` (length = `columns`).
2. Increment `salon.rows` by 1.
3. All existing cells shift down; seat IDs and `seat_no` labels are unchanged.

## Out of scope

- `salon.direction` mirroring / RTL grid flipping
- Multi-level salons (`levels > 1`)
- Backend API normalization
- Changing seat selection or booking logic

## Files

| File | Change |
|------|--------|
| `lib/features/bus/domain/seat_map_normalizer.dart` | New normalizer |
| `lib/features/bus/data/bus_dto_mapper.dart` | Call normalizer after parse |
| `test/features/bus/domain/seat_map_normalizer_test.dart` | Unit tests with fixture JSON |

## Verification

- `seatsResponse.json`: exactly one driver at index 0; seats 1–4 positions unchanged.
- `seatsRespons_2.json`: prepended driver row; seat 1 shifts to index `columns`.
- Normalizer is idempotent (second pass produces same result).
