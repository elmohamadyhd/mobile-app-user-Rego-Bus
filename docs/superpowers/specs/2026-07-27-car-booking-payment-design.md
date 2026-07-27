# Private car booking, payment & tickets

**Date:** 2026-07-27  
**Status:** Approved for planning  
**Feature:** `lib/features/car` — complete booking cycle after trip details  
**APIs:** `POST /private/orders`, `POST /private/orders/:id/pay`,
`PUT /private/orders/:id/cancel`, `GET /profile/private/orders`,
`GET /profile/private/orders/:id` (`docs/wadeny-apis.md`)  
**Visual:** Mirror bus confirm / payment / pending / e-ticket / tickets-card
patterns with Skyline tokens — no passenger fields, no wallet/visa picker

## Goal

Finish the private-transfer booking loop so a signed-in rider can: confirm a
quoted trip, pay via MyFatoorah WebView, see a voucher, and manage private
orders in the My Tickets tab (list, resume payment, cancel) — parity with the
bus cycle, adapted to the private-order contract.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Scope | **A** — confirm → pay → voucher → tickets section (list / resume / cancel) |
| Confirm screen | **A** — trip summary + Pay only (no passenger name/phone, no payment method) |
| Payment | Always gateway WebView (`transaction.invoice_url`) |
| After success | **A** — car voucher screen; back/CTA → **Home only** (no pop to prior booking steps) |
| Abandoned pay | **A** — pending screen + resume from tickets; no duplicate order for same selection |
| Architecture | **1** — extend `CarBookingNotifier` + separate `carOrdersProvider` (mirror bus) |

## Current state

- Search → results → trip details are live.
- Details Continue: guest → `showGuestGate`; signed-in → `carBookingComingSoon` SnackBar.
- `CarRepository` only has `searchQuotes` + `getTrip`.
- Tickets tab composes `BusOrdersSection` only; car section deferred in
  `2026-07-14-tickets-tab-design.md`.

## Backend API

### `POST /private/orders` (create)

Auth: Bearer required.

**Body:**

```json
{
  "trip_id": 1,
  "rounded": false,
  "departure": {
    "latitude": "30.0314696",
    "longitude": "31.2612288",
    "date": "2026-12-20 22:00"
  },
  "destination": {
    "latitude": "31.182972882989525",
    "longitude": "29.894801258559188",
    "date": "2026-12-21 01:00"
  }
}
```

App mapping from `selectedQuote` + `searchParams`:

| Field | Source |
|-------|--------|
| `trip_id` | `selectedQuote.id` |
| `rounded` | `searchParams.rounded` (fallback quote) |
| `departure.latitude/longitude` | `searchParams.from` coords (fallback quote `fromLocation`) |
| `departure.date` | `searchParams.departDate` formatted `yyyy-MM-dd HH:mm` |
| `destination.latitude/longitude` | `searchParams.to` coords (fallback quote `toLocation`) |
| `destination.date` | one-way: same as departDate; round-trip: `returnDate` (required when rounded) |

**200 `data`:** order with `status: pending`, `price`, nested `trip`, and
`transaction.invoice_url` (MyFatoorah) — open WebView on this URL.

### `POST /private/orders/:id/pay`

Re-issue / refresh payment when list/show has no usable `invoice_url`. Body
shape matches create (trip + coords + dates). Prefer reusing an existing
non-empty `transaction.invoice_url` before calling pay.

### `GET /profile/private/orders` / `:id`

List and show — same item shape as create response (status, price, trip,
transaction, `can_be_cancel`). Used for tickets tab and post-WebView verify.

### `PUT /private/orders/:id/cancel`

When `can_be_cancel` is true. Success → status `cancelled`.

## Non-goals

- Wallet / payment-method picker
- Passenger / contact name & phone capture
- Address book
- Changing dates after quote selection
- Separate order-detail screen beyond voucher + tickets card actions
- Flight orders
- Sharing bus providers/data layer (feature isolation stays)

## Architecture

```
lib/features/car/
├── data/
│   ├── car_api.dart              # + createOrder, payOrder, cancelOrder,
│   │                             #   listOrders, getOrder
│   ├── car_dto_mapper.dart       # + order / create-body mapping
│   └── car_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── car_order.dart        # NEW Freezed
│   │   └── car_create_order_request.dart  # NEW (or plain class)
│   └── repositories/car_repository.dart
└── presentation/
    ├── car_routes.dart           # + confirm, pay, pending, voucher
    ├── car_confirm_screen.dart
    ├── car_payment_webview_screen.dart
    ├── car_payment_pending_screen.dart
    ├── car_voucher_screen.dart
    ├── providers/
    │   ├── car_booking_providers.dart  # extend for order/pay/verify
    │   └── car_orders_provider.dart    # NEW list for tickets
    └── widgets/
        ├── car_orders_section.dart
        └── car_order_card.dart

lib/features/tickets/presentation/tickets_screen.dart
  # compose CarOrdersSection under BusOrdersSection
```

### End-to-end flow

```
Details Continue (signed-in)
  → push /car/confirm

Confirm Pay
  → if resumable pending order for same selection → reuse invoice_url
  → else POST /private/orders
  → go /car/pay (WebView)

WebView
  → success-payment URL → verify GET /profile/private/orders/:id
       → paid/confirmed → go /car/voucher (clears booking stack via go)
       → still pending → go /car/pending
  → failed-payment / leave-after-warn → verify → pending (or voucher if paid)

Voucher
  → back / primary CTA → go Home; reset booking flow state

Tickets
  → CarOrdersSection loads GET /profile/private/orders
  → pending: Pay (invoice_url or POST .../pay) → /car/pay with order args
  → confirmed: open voucher (hydrate order into booking state or pass extra)
  → can_be_cancel: confirm dialog → PUT cancel → refresh list
```

### Notifier / status

Extend `CarBookingState` with (names may vary; intent fixed):

- `CarBookingStatus`: existing search/details flags plus
  `idle | creatingOrder | awaitingPayment | verifying | confirmed | error`
- `CarOrder? order` — held pending/confirmed order for this session
- create/pay/verify error message fields as needed

`createOrder` resume rule: reuse when existing `order` is pending, has
non-empty `invoiceUrl`, and matches current selection (`trip.id`, `rounded`,
departure/destination coords + dates). Otherwise create a new order.

`verifyPayment`: `GET /profile/private/orders/:id` → map status; update
`order` and status (`confirmed` vs stay pending).

Do **not** import `busBookingProvider` or bus repositories from car.

### Navigation / stack rules

| From | Action | Navigation |
|------|--------|------------|
| Details → Confirm | Continue | `push` |
| Confirm → Pay | after create/resume | `go` or `push` to pay (prefer same pattern as bus) |
| Pay → Voucher | success | `context.go(CarRoutes.voucher)` |
| Pay → Pending | abandon/fail still unpaid | `go` pending |
| Voucher → Home | back or CTA | `context.go` home/shell; **no** pop to confirm/details |
| Pending → Home | CTA | `go` home |
| Pending → Pay | resume | `go`/`push` pay with same order |

Voucher and successful completion must not leave confirm/pay in the back stack
in a way that restores prior booking steps.

### Payment WebView

Mirror bus classifier: path contains `success-payment` / `failed-payment`.
Back (system + app bar) shows leave-payment confirmation; Leave runs verify
(same as bus) so a completed payment still lands on voucher.

Copy the WebView screen into `car/` (independent feature). Shared atoms already
in `shared/` or `BookingAppBar` may be reused; do not lift bus-specific verify
wiring into `shared/`.

### Tickets section UX

- Section header localized (e.g. private / car orders).
- Card: company, route labels (`trip.from_location` / `to_location`), dates,
  price + currency, status badge.
- Actions: Pay (pending), Open voucher (confirmed), Cancel (when allowed).
- Empty: section-local empty copy (not whole-tab empty if bus has items).
- Error: section-local error + retry.
- Guest: tickets tab already gated / empty elsewhere — follow existing tickets
  auth behavior; do not invent a new guest path for car orders.

### UX constraints (ui-ux-pro-max + project rules)

- SafeArea + scrollable bodies; sticky CTAs clear of system insets.
- Touch targets ≥ 48dp; clear pressed feedback on Pay / Cancel / card actions.
- Predictable back: voucher/pending success path uses `go` Home, not broken
  history into the wizard.
- RTL via directional insets; all strings in ARB `ar` + `en`.
- Skyline tokens only (`AppColors` / `AppSpacing` / `AppRadius` / `AppIcons`).
- Portrait + landscape; honor text scaling.

## Error handling

| Case | Behavior |
|------|----------|
| Create/pay `401` | Surface message; auth recovery consistent with app |
| Create network / 5xx | Stay on Confirm; show error; no navigation |
| Verify still pending | Pending screen |
| Cancel failure | SnackBar on card; list unchanged until refresh succeeds |
| List empty | Section empty state |
| List failure | Section error + retry |
| Missing quote on Confirm | Empty + back (cold open) |

## Localization

New keys (both ARBs), including at least:

- Confirm / pay / pending / voucher titles and body copy
- Pay CTA, leave-payment dialog, resume / cancel dialogs
- Tickets section title, empty, error, card actions
- Status labels if not reusable from bus keys (prefer reuse only if wording
  fits private transfers; otherwise car-specific keys)

Remove or stop using `carBookingComingSoon` once Confirm is wired from Details.

## Testing

- Unit: DTO mapper for order + create body date/coord mapping
- Unit: notifier resume-vs-create, verify status branching
- Widget (light): Confirm Pay triggers create path; Voucher back goes Home

## Out of scope follow-ups

- Wallet payment for private orders (if backend adds it later)
- Contact fields if API starts accepting them
- Address-book shortcuts on confirm
