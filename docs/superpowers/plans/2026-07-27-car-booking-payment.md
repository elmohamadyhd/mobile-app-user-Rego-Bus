# Private Car Booking & Payment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete private-car confirm → MyFatoorah pay → voucher → tickets section, matching bus behavior per `docs/superpowers/specs/2026-07-27-car-booking-payment-design.md`.

**Architecture:** Extend `CarBookingNotifier` for create/verify/resume; add `carOrdersProvider` for tickets list; all screens live in `features/car`. Plain domain classes (match existing car style, not Freezed).

**Tech Stack:** Flutter, Riverpod, Dio, go_router, webview_flutter, intl/l10n, Skyline tokens.

## Global Constraints

- Feature isolation: no `bus` data/providers imports from car (BookingAppBar already reused — OK).
- No passenger fields / wallet picker.
- Voucher/pending back → `AppRoutes.home` + `reset()`.
- Dates in create body: `yyyy-MM-dd HH:mm`; one-way destination.date = departDate; round-trip = returnDate.
- All user strings in `app_en.arb` + `app_ar.arb`.
- Run `flutter gen-l10n` after ARB changes; `dart format` before commit.

## File map

| Path | Role |
|------|------|
| `domain/entities/car_order.dart` | `CarOrder`, `CarOrderStatusKind`, coords helper |
| `domain/entities/car_create_order_request.dart` | Create/pay body |
| `domain/repositories/car_repository.dart` | + create/pay/cancel/list/get |
| `data/car_api.dart` | HTTP |
| `data/car_dto_mapper.dart` | order + body mapping |
| `data/car_repository_impl.dart` | wire |
| `presentation/providers/car_booking_providers.dart` | status + create/verify/reset |
| `presentation/providers/car_orders_provider.dart` | list + cancel |
| `presentation/car_confirm_screen.dart` | summary + Pay |
| `presentation/car_payment_webview_screen.dart` | gateway + verify |
| `presentation/car_payment_pending_screen.dart` | resume / home |
| `presentation/car_voucher_screen.dart` | success + home only |
| `presentation/widgets/car_order_card.dart` | tickets card |
| `presentation/widgets/car_orders_section.dart` | tickets section |
| `presentation/car_routes.dart` | + confirm/pay/pending/voucher |
| `car_trip_details_screen.dart` | Continue → confirm |
| `tickets_screen.dart` | private tab → CarOrdersSection |
| `test/features/car/...` | mapper + notifier tests |

---

### Task 1: Domain + data layer

**Files:** create/modify entities, repo, api, mapper; update `fake_car_repository.dart`

- [ ] **Step 1:** Add `CarOrderStatusKind { pending, confirmed, cancelled, unknown }` and `CarOrder` with: `id`, `statusText`, `statusKind`, `price`, `currency`, `rounded`, `departureDate`, `returnDate`, `fromLat/Lng`, `toLat/Lng`, `trip` (`CarTripQuote?`), `invoiceUrl`, `transactionStatus`, `canBeCancel`, `createdAt`.
- [ ] **Step 2:** Add `CarCreateOrderRequest` (`tripId`, `rounded`, departure/destination lat/lng/date strings).
- [ ] **Step 3:** Extend `CarRepository` + `CarApi` + `CarRepositoryImpl` for `createOrder`, `payOrder`, `cancelOrder`, `listOrders`, `getOrder`.
- [ ] **Step 4:** Mapper: `createOrderBody`, `orderFromJson` / envelope helpers; status from `status` string (`pending`/`cancelled` + paid set like bus).
- [ ] **Step 5:** Unit test mapper create-body + order status; update fake repo stubs.
- [ ] **Step 6:** Commit `feat(car): add private order domain and API`

### Task 2: Booking notifier

- [ ] **Step 1:** Add `CarBookingStatus` enum: `idle`, `creatingOrder`, `awaitingPayment`, `verifyingPayment`, `paymentPending`, `confirmed`, `error`.
- [ ] **Step 2:** Extend state with `status`, `order`, `bookingError`; implement `createOrder`, `verifyPayment`, `hydrateOrder`, `reset`; resume when pending order matches trip+rounded+coords+dates and has invoice URL.
- [ ] **Step 3:** Unit tests for resume vs create and verify branching.
- [ ] **Step 4:** Commit `feat(car): create/verify private order in booking notifier`

### Task 3: Confirm / pay / pending / voucher UI + routes + l10n

- [ ] **Step 1:** ARB keys (en+ar): confirm/pay/pending/voucher titles, pay CTA, create error, voucher fields, tickets car section empty/error/actions; gen-l10n.
- [ ] **Step 2:** Implement four screens mirroring bus patterns (car-owned WebView with classify + leave dialog copy).
- [ ] **Step 3:** Wire routes; Details Continue → `push(CarRoutes.confirm)`.
- [ ] **Step 4:** Confirm listens for `awaitingPayment` → `push(pay)`.
- [ ] **Step 5:** Commit `feat(car): private confirm payment voucher screens`

### Task 4: Tickets section

- [ ] **Step 1:** `carOrdersProvider` + section + card (pay / voucher / cancel).
- [ ] **Step 2:** TicketsScreen: private tab shows `CarOrdersSection`; refresh both providers; hero count = bus+car when signed in (or active tab).
- [ ] **Step 3:** Commit `feat(car): private orders on tickets tab`

### Task 5: Verify

- [ ] **Step 1:** `flutter analyze` on touched paths; `flutter test test/features/car`
- [ ] **Step 2:** Fix failures; final commit if needed

## Self-review

- Spec coverage: create/pay/cancel/list/show, confirm, webview, pending, voucher→home, tickets resume/cancel — all tasked.
- No TBD placeholders.
- Types: `CarOrder.id` as `int` (API) stringified for routes/args where needed like bus `orderId` string — use `String` id from `id.toString()` for WebView args consistency.
