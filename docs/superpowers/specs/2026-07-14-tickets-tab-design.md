# My Tickets Tab (تذاكري) — Design Spec
_Date: 2026-07-14 | Status: approved_

## Scope

Build out the **Tickets** bottom-nav tab (label `navTickets` = "تذاكري" / "My
Tickets"), which is currently a `ComingSoonScreen`. The tab shows the signed-in
rider's **booked bus trips** from `GET /profile/buses/orders`, with four
capabilities: a status-badged list, resume-payment for pending orders, open
e-ticket/invoice, and cancel a cancellable order.

Out of scope for v1:
- A separate order-detail screen (`GET /profile/buses/orders/:id`). The list
  item carries everything the card and its actions need.
- Flight and private-car order sections. The tab is structured to accept them
  later (see Architecture) but only bus exists today.
- Status filtering / search within the list.
- The support-ticket helpdesk (`/profile/tickets` + replies) — a different
  system, explicitly not what this tab is.

---

## Terminology note (why this tab, not `/profile/tickets`)

`docs/wadeny-apis.md` uses "tickets" for two unrelated things:

| Concept | Endpoint | What it is |
|---|---|---|
| **Booked trips** (this tab) | `/profile/buses/orders`, `/flights/orders`, `/private/orders` | The rider's purchased travel. Each order carries a `tickets` array of seats. |
| Support helpdesk | `/profile/tickets` (+ `/replies`) | Issues with title/description/section/status and threaded replies. |

The nav label "تذاكري" ("my tickets") and a primary-nav placement both point at
booked trips, which the user confirmed. This spec is booked trips only.

---

## Architecture — thin composition shell (Approach B)

A bottom-nav tab is cross-cutting, but per the multi-vehicle rule
(`2026-07-08-multi-vehicle-architecture-design.md`) each mode stays a fully
independent slice. Reconciled as a **composition root that owns no mode data**:

```
lib/features/
├── tickets/                         # NEW — thin shell, zero mode-specific parsing
│   └── presentation/
│       └── tickets_screen.dart      # Skyline hero + tab scaffold; composes sections
└── bus/                             # owns everything bus, as today
    ├── domain/entities/bus_order.dart
    ├── data/       (bus_api, bus_dto_mapper, bus_repository_impl)
    ├── domain/repositories/bus_repository.dart
    └── presentation/
        ├── providers/bus_orders_provider.dart
        └── widgets/bus_orders_section.dart   # the section the shell drops in
        └── widgets/bus_order_card.dart
```

`TicketsScreen` renders the hero and a `BusOrdersSection`. It imports the bus
slice's section widget but holds **no** `BusOrder`, no parsing, no endpoints —
so it is not a shared core. When flight/car arrive, each adds its own
`XOrdersSection`; the shell composes them with **no refactor** of existing code.

The router's `/tickets` branch swaps `ComingSoonScreen` → `TicketsScreen`.

---

## Data model — `BusOrder` (owned by `features/bus/`)

New Freezed entity, mapped in `bus_dto_mapper.dart` from each item of
`GET /profile/buses/orders` → `data[]`.

| Field | Source JSON | Notes |
|---|---|---|
| `orderId` | `id` | string |
| `bookingNumber` | `number` | e.g. `"000001475"` |
| `operatorName` | `company_name` / `company_data.name` | |
| `operatorLogoUrl` | `company_data.avatar` | nullable (empty → null) |
| `category` | `category` | e.g. "VIP", "Five stars" |
| `statusText` | `status` | display fallback |
| `statusCode` | `status_code` | drives `BusOrderStatusKind` |
| `isConfirmed` | `is_confirmed` | int 0/1 |
| `dateTimeLabel` | `date_time` / `date` | reuse mapper date parsing |
| `seats` | `tickets[].seat_number` | `List<String>` |
| `total` | `total` | preformatted "EGP 219.35" |
| `currency` | `currency` | |
| `canCancel` | `can_be_cancel` | |
| `gatewayCheckoutUrl` | `payment_data.invoice_url` | resume-payment target |
| `invoiceUrl` | `invoice_url` | e-ticket PDF |
| `cancelUrl` | `cancel_url` | |

Derived status kind:

```
enum BusOrderStatusKind { pending, confirmed, cancelled, unknown }
```

Mapping reuses the existing documented-uncertainty pattern (`isPaidStatus`):
`is_confirmed == 1` or codes in `{confirmed,paid,success,completed,succeeded}` →
`confirmed`; `{cancelled,canceled,expired,failed,refunded}` → `cancelled`;
`{pending}` → `pending`; else `unknown`. Only `pending` appears in the sample —
comment the assumption so it's a one-line fix when the backend vocabulary is
confirmed.

`BusOrder` is intentionally distinct from the existing `BusTicket` (the
post-booking confirmation entity) and `BusOrderStatus` (payment-verify result);
it is the historical list-item shape.

---

## Data layer additions (`features/bus/`)

**`BusApi`** (`/profile/buses/orders` needs the bearer token — attached
automatically by the existing `_AuthInterceptor`):
- `Future<dynamic> listOrders()` → `GET /profile/buses/orders`
- `Future<dynamic> cancelOrder(String orderId)` → `POST /buses/orders/{id}/cancel`
  (path from the sample `cancel_url`; method POST assumed — flag like the
  existing `orderStatusPath` caveat).

**`BusDtoMapper`**: `ordersFromEnvelope(body)` → `List<BusOrder>` and
`orderFromJson(json)`. Tolerate `null` `station_from`/`station_to`.

**`BusRepository`** (+impl): `Future<List<BusOrder>> listOrders()` and
`Future<void> cancelOrder(String orderId)`.

---

## Presentation — states & widgets

Design skills (`mobile-app-designer`, `flutter-engineering`) applied at build
time. Every string localized in `app_ar.arb` / `app_en.arb`.

**`TicketsScreen`** (shell): `SkylineTabHero` ("تذاكري" + order count) over the
composed section, inside a `RefreshIndicator` for pull-to-refresh. Follows the
Home/Profile shell-tab layout (`SkylineTabHero` + floated content), using
`AlwaysScrollableScrollPhysics` so refresh works when the list is short.

**`BusOrdersSection`** (`features/bus/`) renders one of five states:

| State | Condition | UI |
|---|---|---|
| Guest | `guestMode == true` | Sign-in card (profile pattern) → `login` with `AuthGateArgs(returnTo: '/tickets')` |
| Loading | provider loading | skeleton cards |
| Error | provider error | message + **Retry** (`ref.invalidate`) |
| Empty | signed-in, `[]` | icon + "No tickets yet" + **Book a trip** CTA → `/` (home) |
| Orders | signed-in, non-empty | column of `BusOrderCard` |

Guard: the guest branch never watches `busOrdersProvider`, so no protected call
fires for guests.

**`BusOrderCard`**: operator avatar (reuse `OperatorAvatar`) + name + category ·
`OrderStatusBadge` (amber `secondary` = pending, green `success` = confirmed,
grey `textMuted` = cancelled, neutral = unknown) · date-time · seats · total ·
contextual actions row. Card styling mirrors `trip_card.dart` / `eticket_screen`
(bgCard, `AppRadius.card`, soft shadow).

---

## The four actions

| Action | Shown when | Behavior |
|---|---|---|
| Status badge | always | `OrderStatusBadge` from `BusOrderStatusKind` |
| **Complete payment** | `pending` | Resume-payment flow (below) |
| **Open e-ticket** | `invoiceUrl` non-empty | `launchUrl(invoiceUrl, externalApplication)`; snackbar on failure — same as `eticket_screen.dart` |
| **Cancel** | `canCancel` | Confirm dialog (profile-logout dialog style) → `busOrdersProvider.cancel(orderId)` → refresh list + toast; snackbar on failure |

### Resume-payment integration (main risk)

Reuse the existing `PaymentWebViewScreen` (careful gateway-redirect logic) once,
by making it accept an optional argument rather than duplicating it:

- Add `PaymentFlowArgs { String checkoutUrl; String orderId; PaymentFlowMode mode }`
  where `mode ∈ { booking, resume }`, passed via `GoRoute` `extra` on
  `BusRoutes.pay`.
- **Booking flow (unchanged):** no args → the screen reads `busBookingProvider`
  exactly as today; post-verify routes to `BusRoutes.ticket` / `BusRoutes.pending`.
- **Resume flow:** `BusOrderCard` navigates to `BusRoutes.pay` with args
  `{ checkoutUrl: order.gatewayCheckoutUrl, orderId, mode: resume }`. The screen
  loads `checkoutUrl` **without** mutating booking state; on the gateway
  success/failure redirect it verifies via
  `ref.read(busRepositoryProvider).orderStatus(orderId, currency: BusCurrency.defaultCode)`,
  then pops back to the tab and `ref.invalidate(busOrdersProvider)` so the card reflects the new
  status. Toast differs for paid vs still-pending.

Resume deliberately skips the standalone e-ticket screen (it needs rich
trip/stop data the order list lacks); the refreshed card shows the new status
and its **Open e-ticket** action covers the PDF.

---

## Providers

`busOrdersProvider` — `AutoDisposeAsyncNotifier<List<BusOrder>>`:
- `build()` → `repo.listOrders()`
- `cancel(orderId)` → `repo.cancelOrder`, then refresh (or optimistic → cancelled)
- refresh via `ref.invalidateSelf()` / `RefreshIndicator`

Registered alongside `busApiProvider` / `busRepositoryProvider` in
`bus_orders_provider.dart` (reusing the existing `busRepositoryProvider`).

---

## Localization keys (new)

`ticketsHeroCaption`, `ticketsCountLabel`, `ticketsEmptyTitle`,
`ticketsEmptyBody`, `ticketsBookCta`, `ticketsGuestTitle`, `ticketsGuestBody`,
`ticketsSignInCta`, `ticketsErrorTitle`, `ticketsRetry`,
`ticketStatusPending`, `ticketStatusConfirmed`, `ticketStatusCancelled`,
`ticketStatusUnknown`, `ticketSeatsLabel`, `ticketActionPay`,
`ticketActionEticket`, `ticketActionCancel`, `ticketCancelTitle`,
`ticketCancelBody`, `ticketCancelConfirm`, `ticketCancelKeep`,
`ticketCancelSuccess`, `ticketCancelFailed`, `ticketEticketUnavailable`,
`ticketResumePaidToast`, `ticketResumePendingToast`. (Final names settle in the
plan.)

---

## Files

**New:**
`features/tickets/presentation/tickets_screen.dart`,
`features/bus/domain/entities/bus_order.dart` (+`.freezed.dart`),
`features/bus/presentation/providers/bus_orders_provider.dart`,
`features/bus/presentation/widgets/bus_orders_section.dart`,
`features/bus/presentation/widgets/bus_order_card.dart`,
`features/bus/presentation/widgets/order_status_badge.dart`.

**Modified:**
`features/bus/data/bus_api.dart`,
`features/bus/data/bus_dto_mapper.dart`,
`features/bus/data/bus_repository_impl.dart`,
`features/bus/domain/repositories/bus_repository.dart`,
`features/bus/presentation/payment_webview_screen.dart` (accept `PaymentFlowArgs`),
`features/bus/presentation/bus_routes.dart` (pass `extra` to `pay`),
`core/router/app_router.dart` (`/tickets` → `TicketsScreen`),
`l10n/app_ar.arb`, `l10n/app_en.arb`.

---

## Backend assumptions to verify (flagged in code, degrade safely)

1. `POST /buses/orders/{id}/cancel` — method/path inferred from `cancel_url`;
   treat HTTP 200 envelope as success.
2. Non-`pending` `status_code` vocabulary is assumed (`confirmed`/`cancelled`
   families); unknown codes render as neutral, no destructive behavior.
3. `orderStatus` for resume-verify already carries the documented caveat that
   its GET path and paid-code set are assumed (see `bus_api.dart`).
