# Bus Order Detail Route Timeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline on current branch). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show real departure/arrival stops side-by-side on the bus order detail sheet, and open Google Maps when a station is tapped.

**Architecture:** Map full `station_from` / `station_to` into optional `BusStop`s on `BusOrder`; replace the sheet’s flat route rows with a side-by-side read-only row that calls `confirmAndOpenStopInGoogleMaps`.

**Tech Stack:** Flutter, Freezed `BusOrder` / `BusStop`, existing Maps helpers, `flutter_test`.

## Global Constraints

- Stay on current branch (`feat/car-booking-payment`) — do not create a new branch.
- Station name only in UI — no city captions.
- Reuse `BusStop` and `confirmAndOpenStopInGoogleMaps` — no duplicate Maps logic.
- No card / invoice / status-kind changes.
- Package imports (`package:safaria/...`); design tokens only; RTL-safe alignments.
- TDD for mapper + sheet behavior; run `dart run build_runner` after Freezed entity changes.

---

### Task 1: Entity + mapper — full order stations

**Files:**
- Modify: `lib/features/bus/domain/entities/bus_order.dart`
- Modify: `lib/features/bus/data/bus_dto_mapper.dart`
- Modify: `test/features/bus/data/bus_fixtures.dart`
- Modify: `test/features/bus/data/bus_dto_mapper_test.dart`
- Modify: test `BusOrder(` constructors that break (add optional stops only if required — Freezed optionals with no default need named args only when set)

**Interfaces:**
- Produces: `BusOrder.pickupStop` / `BusOrder.dropoffStop` as `BusStop?`
- Produces: labels still populated from stop names for the card

- [x] **Step 1: Write the failing mapper test**
- [x] **Step 2: Run test to verify it fails**
- [x] **Step 3: Implement entity + mapper**
- [x] **Step 4: Run mapper tests**

---

### Task 2: Sheet route UI + Maps tap

**Files:**
- Modify: `lib/features/bus/presentation/widgets/bus_order_detail_sheet.dart`
- Modify: `test/features/bus/presentation/widgets/bus_order_detail_sheet_test.dart`

**Interfaces:**
- Consumes: `order.pickupStop` / `order.dropoffStop`
- Consumes: `confirmAndOpenStopInGoogleMaps(context, stop: stop)`

- [x] **Step 1: Write failing sheet tests**
- [x] **Step 2: Run tests — expect FAIL**
- [x] **Step 3: Implement `_RouteSection`**
- [x] **Step 4: Run sheet + related bus tests**
- [x] **Step 5: Analyze**

---

## Spec coverage checklist

| Spec requirement | Task |
|---|---|
| `pickupStop` / `dropoffStop` on `BusOrder` | Task 1 |
| Mapper via `stopFromJson` | Task 1 |
| Labels still set for card | Task 1 |
| Side-by-side times + names, no city | Task 2 |
| No `date_time` as trip time row | Task 2 |
| Tap → Maps confirm helper | Task 2 |
| Fallbacks `--:--` / hide when null | Task 2 |
| Out-of-scope items untouched | Both |
