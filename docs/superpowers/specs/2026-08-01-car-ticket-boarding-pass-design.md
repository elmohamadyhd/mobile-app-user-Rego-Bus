# Private Car Boarding-Pass Ticket Cards — Design

**Date:** 2026-08-01  
**Status:** Approved for implementation  
**Scope:** Private car search results + My Tickets order cards

## Goal

Give private-car list cards the same boarding-pass visual language as bus
(`TripCard` / `BusOrderCard`) — side notches + dashed tear + fare/actions stub —
without reusing bus widgets or touching the bus feature.

## Decisions

| Decision | Choice |
|----------|--------|
| Surfaces | Both `/car/results` and My Tickets car orders |
| Bus feature | Untouched (no import of `TicketBorder` / `TripCard`) |
| Structure | Independent `CarTicketShell` + two content widgets |
| Shell location | `lib/features/car/presentation/widgets/` |
| Search card content | Same sections as bus: header → route row → fare stub + Select |
| Select action | Opens trip details (`/car/details`) — same as current card tap |
| Order card content | Keep current `CarOrderCard` content/layout; wrap in shell only |
| Soft-browse `CarTierCard` | Removed from results screen; delete if unused |

## Architecture

```
car/presentation/widgets/
├── car_ticket_shell.dart      # CarTicketBorder (OutlinedBorder) — shape only
├── car_trip_ticket_card.dart  # Search results card (replaces CarTierCard)
└── car_order_card.dart        # Existing content wrapped in CarTicketBorder
```

- No cross-feature imports from `bus/`.
- No domain / provider / route changes.
- Entities already expose what the search card needs (`fromLocation`,
  `toLocation`, vehicle image, company, price).

## Components

### `CarTicketBorder` (`car_ticket_shell.dart`)

Independent `OutlinedBorder` mirroring the bus boarding-pass geometry:

- Corner radius (use `AppRadius.xl` / `AppRadius.card` as callers need)
- Left/right semicircle notches
- Dashed perforation along the tear line
- `notchOffsetFromBottom` = stub height
- Used as `Material.shape` so shadow and ink follow the notched outline

Name is car-scoped (`CarTicketBorder`) so it never collides with bus
`TicketBorder`.

### `CarTripTicketCard` (search results)

Props:

```dart
CarTripTicketCard({
  required CarTripQuote quote,
  required bool rounded,
  required VoidCallback onTap,
})
```

Layout:

```
┌─ CarTicketBorder ──────────────────────────┐
│ Header: vehicle image | company            │
│         category · model | refundable?     │
│ Route:  from ── seats/bags/gear chips ── to│
│         (location names; no clock times)   │
├─ tear (stub ≈ 60) ─────────────────────────┤
│ Fare label + price/currency | [Select]     │
└────────────────────────────────────────────┘
```

- Price from `quote.priceFor(rounded: rounded)`.
- Select uses `l10n.bookingSelect`; body tap and Select both call `onTap`.
- Empty location names → `—`.
- Image URL missing/failed → car icon fallback (same as current tier card).
- No stops picker (bus-only).

### `CarOrderCard` (My Tickets)

- Keep existing body: company + status badge → route → departure date → price.
- Keep existing actions: Pay / Voucher / Cancel by status.
- Replace rounded `Container` chrome with `Material` + `CarTicketBorder`.
- Tear separates info body (above) from action buttons (below), matching
  `BusOrderCard` stub-height calculation pattern (compute stub from visible
  actions; if no actions, use a minimal offset so the border still paints).

## Screen wiring

- `CarTierResultsScreen`: swap `CarTierCard` → `CarTripTicketCard` (same
  `selectQuote` + `context.push(CarRoutes.details)`).
- Tickets tab / `CarOrdersSection`: continue using `CarOrderCard` (visual only).

## i18n / RTL / design tokens

- Reuse existing keys: `bookingSelect`, `tripResultsFareLabel`, `carRefundable`,
  `carSeats`, `carBags`, `carGearManual` / `carGearAutomatic`, ticket action
  strings. No new ARB keys required unless a gap appears during build.
- `EdgeInsetsDirectional`; Phosphor Light icons; `AppColors` / `AppSpacing` /
  `AppRadius` / `AppTypography` only.
- Notch path is left/right symmetric — RTL needs no special flip for the shell.

## Out of scope

- Bus / flight widgets
- Car trip details `_ExpandedQuoteCard`
- Booking / payment flow changes
- Lifting shell to `shared/` (may happen later if bus migrates)

## Testing

- Widget tests for `CarTripTicketCard`: company, locations, seats chip, Select,
  `onTap`, Arabic locale.
- Update `car_tier_results_screen_test` to find `CarTripTicketCard`.
- Widget test for `CarOrderCard`: company/route/actions still present under shell.
- Delete or rewrite `car_tier_card_test` when `CarTierCard` is removed.

## Success criteria

1. Car search results look like boarding-pass tickets (not soft rounded cards).
2. My Tickets car orders use the same shell, content unchanged in spirit.
3. Bus feature has zero file changes.
4. Select / card tap still opens car trip details.
5. Relevant car widget/screen tests pass.
