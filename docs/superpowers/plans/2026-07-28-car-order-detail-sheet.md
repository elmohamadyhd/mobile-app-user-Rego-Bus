# Private Car Order Detail Sheet Implementation Plan

> **For agentic workers:** Inline execution on current branch (`feat/car-booking-payment`). Steps use checkbox syntax.

**Goal:** Bottom sheet for private order details with side-by-side Maps-tappable route, seeded from the tickets list and refreshed by id.

**Architecture:** Lift `MapLocation` into core; shared Maps confirm widget; car detail sheet + `carOrderDetailProvider`; wire card `onTap`.

**Tech Stack:** Flutter, Riverpod, existing car repository `getOrder`.

## Global Constraints

- Same branch — do not create a new branch
- Car feature must not import `features/bus`
- Reuse existing l10n where possible; add AR+EN keys for new vehicle/trip labels
- TDD for mapper + sheet; design tokens only; RTL-safe route row

---

### Task 1: MapLocation + shared Maps open

**Files:**
- Create: `lib/core/utils/map_location.dart`
- Modify: `lib/core/utils/google_maps_url.dart`
- Create: `lib/shared/widgets/open_location_in_google_maps.dart`
- Modify: bus callers + `open_stop_in_google_maps.dart` (thin adapter or replace)
- Modify: `test/core/utils/google_maps_url_test.dart`

- [ ] MapLocation + URL builders on MapLocation
- [ ] Shared confirm dialog
- [ ] Update bus call sites / tests — PASS

### Task 2: CarOrder payment fields + fixture

**Files:**
- Modify: `lib/features/car/domain/entities/car_order.dart`
- Modify: `lib/features/car/data/car_dto_mapper.dart`
- Modify: `test/features/car/data/car_fixtures.dart`
- Modify: `test/features/car/data/car_dto_mapper_test.dart`

- [ ] Failing mapper test for gateway + invoice id
- [ ] Implement mapping — PASS

### Task 3: Detail sheet + provider + card wire

**Files:**
- Modify: `lib/features/car/presentation/providers/car_orders_provider.dart`
- Create: `lib/features/car/presentation/widgets/car_order_detail_sheet.dart`
- Modify: `lib/features/car/presentation/widgets/car_order_card.dart`
- Modify: `lib/features/car/presentation/widgets/car_orders_section.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` (+ gen-l10n)
- Create: `test/features/car/presentation/widgets/car_order_detail_sheet_test.dart`
- Update card tests if present

- [ ] Failing sheet tests
- [ ] Implement sheet + provider + onTap
- [ ] Analyze + tests PASS

---

## Spec coverage

| Requirement | Task |
|---|---|
| MapLocation lift / no car→bus import | 1 |
| paymentGateway / paymentInvoiceId | 2 |
| Full sheet sections | 3 |
| Side-by-side Maps route | 3 |
| Seed + refresh provider | 3 |
| Card onTap without button bubble | 3 |
