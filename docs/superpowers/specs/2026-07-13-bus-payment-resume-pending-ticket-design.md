# Bus payment — resume without duplicating, warn on back, pending ticket

> Design spec · 2026-07-13
> Feature slice: `lib/features/bus`
> Builds on the existing pending-payment path in
> `2026-06-30-booking-flow-design.md` and the redirect classifier in
> `payment_webview_screen.dart`.

## Problem

`confirmBooking()` already creates a temporary (`pending`) order on the
backend and stores its gateway `payment_url` + `orderId` on
`BusBookingState.ticket`. Three gaps around that flow:

1. If the rider backs out of the payment WebView without finishing, nothing
   tells them a seat is still held — the back button just pops silently.
2. If they then tap **Confirm & pay** again from the Confirm screen,
   `confirmBooking()` unconditionally calls `createTicket` again, creating a
   **second** temporary booking/order for the same trip+seats instead of
   reusing the saved `payment_url`.
3. `PaymentPendingScreen` (reached today only from a failed/cancelled gateway
   redirect) doesn't read as "your booking, on hold" — it's a generic notice,
   not a ticket. The abandoned-back path (new) and the failed-payment path
   (existing) should land on the same screen.

## Scope

Bus booking flow only. No new backend endpoints, no bookings-list/"my
tickets" screen (that tab stays `ComingSoonScreen` — out of scope, confirmed
with the user). The pending booking lives only in the in-memory
`BusBookingState` for the session; killing the app or tapping **Back to
home** abandons it, which is safe because the backend auto-cancels unpaid
orders after ~15 minutes.

## Behavior

### 1. Resume instead of recreate — `BusBookingNotifier.confirmBooking()`

Before calling `_repo.createTicket`, check whether `state.ticket` already
holds a reusable pending order for the *same* selection:

- `ticket.paymentUrl` is non-empty, **and**
- `ticket.trip.id == trip.id`, **and**
- `ticket.fromStop.locationId == from.locationId` and
  `ticket.toStop.locationId == to.locationId`, **and**
- `Set.of(ticket.seats) == Set.of(state.selectedSeats)`

If all hold, skip the API call and set `status = BusBookingStatus.awaitingPayment`
directly (existing ticket stays as-is) — the Confirm screen's `ref.listen`
already pushes `/booking/pay` on that status, so the WebView opens with the
same `payment_url`, no duplicate order. If any check fails (different trip,
different stops, or the rider changed seats since the held order), fall
through to the existing create-a-new-order path.

This covers the case where the rider ends up back on the Confirm screen
(e.g. hardware-backing twice from the pending screen) and taps **Confirm &
pay** again — the exact scenario in the request.

### 2. Back-warning inside the payment WebView — `payment_webview_screen.dart`

Intercept both the hardware back gesture and the app-bar back arrow (must
catch both, so a `PopScope` alone on the route is not enough — the arrow is
a separate `IconButton` inside `BookingAppBar`):

- Add an optional `VoidCallback? onBack` to `BookingAppBar` (defaults to the
  existing `context.pop()` when omitted, so every other call site is
  unaffected).
- Wrap `PaymentWebViewScreen`'s `Scaffold` in `PopScope(canPop: false, ...)`
  and pass the same handler as `BookingAppBar.onBack`.
- The handler shows a confirmation dialog: title "Leave payment?", body
  "Your seat is held, but payment isn't finished yet. You can complete it
  later from your booking.", actions **Stay** (dismiss, no-op) and **Leave**.
- **Leave** does *not* unconditionally jump to the pending screen — it calls
  the existing `_verify()` (→ `verifyPayment()`), same as the **Done**
  button today. The screen's existing `ref.listen` then routes on the
  authoritative result: `confirmed` → e-ticket, `paymentPending` → the
  pending screen. (If the rider actually finished paying right before
  backing out, they still land on their e-ticket, not a false "pending".)
- Guard against double-invocation (e.g. rapid double back-press) with the
  same `_verifyTriggered` flag the screen already uses.

### 3. Pending screen becomes a pending *ticket* — `payment_pending_screen.dart`

Same route (`/booking/pending`), same triggers (failed/cancelled gateway
redirect **and** the new back-warning "Leave" path), restyled to read as a
ticket rather than a generic notice:

- Add an amber "Pending payment" badge/pill above the existing heading,
  visually distinct from the confirmed e-ticket's green "Booking confirmed"
  hero (reuses the boarding-pass card treatment from `eticket_screen.dart`
  for the recap card, not a full redesign).
- Buttons unchanged in behavior: **Complete payment** → `context.push('/booking/pay')`
  (WebView re-reads `state.ticket.paymentUrl` — already the same saved URL,
  no new logic needed here); **Back to home** → `reset()` + `context.go('/')`.

### 4. Navigation stack

WebView → pending screen keeps using `pushReplacement` (already the case).
No stack-deduplication logic needed: the only way back to the WebView is via
**Complete payment**, which always pushes a fresh WebView route on top of
the pending screen — acceptable, matches today's failed-payment path.

## Data

No entity changes. Reuses `BusTicket { paymentUrl, orderId, trip, fromStop,
toStop, seats }` and `BusBookingStatus` as-is (`awaitingPayment`,
`paymentPending`, `confirmed`).

## Files

**Modified**
- `lib/features/bus/presentation/providers/bus_booking_providers.dart` —
  reuse guard in `confirmBooking()`.
- `lib/features/bus/presentation/payment_webview_screen.dart` — `PopScope`,
  back-warning dialog, wire to `_verify()`.
- `lib/features/bus/presentation/widgets/booking_app_bar.dart` — optional
  `onBack` callback.
- `lib/features/bus/presentation/payment_pending_screen.dart` — pending
  badge / boarding-pass-style recap card.
- `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` (+ generated) — new keys:
  `paymentLeaveTitle`, `paymentLeaveBody`, `paymentLeaveStay`,
  `paymentLeaveConfirm`, `paymentPendingBadge`.

**New**
- `test/features/bus/presentation/providers/bus_booking_providers_test.dart`
  (notifier has no test file yet — created here).

**Modified tests**
- `test/features/bus/presentation/payment_pending_screen_test.dart` —
  updated for the badge.
- `test/features/bus/presentation/payment_webview_screen_test.dart` — new
  file covering the back-warning dialog (today only
  `payment_nav_classify_test.dart` exists, and it only tests the pure
  `classifyPaymentNav` function, not the screen widget).

## Edge cases

- Rider changes seat selection after abandoning a payment (goes back to
  seat selection, picks different seats, returns to Confirm): the reuse
  guard's seat-set comparison fails → a fresh order is created, old pending
  order is simply left to auto-expire on the backend.
- Back-press before the WebView controller/URL has finished loading: the
  dialog still shows; **Leave** still calls `verifyPayment()` (safe even
  with no page loaded, since it checks order status server-side, not page
  state).
- Rider actually completed payment, then immediately hits back before the
  redirect fires: `verifyPayment()` (triggered by **Leave**) reads the
  authoritative order status, so they still land on the confirmed e-ticket.
- App killed / process death while a pending order is held: session state is
  lost; on relaunch the rider has no in-app trace of the held seat (accepted
  — no persistence in scope; backend auto-cancel handles cleanup).

## Testing

- Notifier unit test: `confirmBooking()` skips `createTicket` and reuses the
  existing ticket/URL when trip+stops+seats match a held pending ticket;
  creates a new order when seats differ.
- Widget test: triggering back in `PaymentWebViewScreen` shows the
  Stay/Leave dialog; **Stay** leaves the WebView in place; **Leave** invokes
  verification and (with a mocked `paymentPending` result) navigates to
  `/booking/pending`.
- `payment_pending_screen_test.dart`: pending badge renders; existing recap
  and button assertions still pass.
- `flutter analyze && flutter test` clean.

## Verification

Run on a mobile emulator (REGO is mobile-only). Confirm a booking → in the
payment WebView, press hardware back → see the Stay/Leave dialog → **Stay**
keeps the WebView open → back again → **Leave** → land on the pending
ticket screen with the pending badge and correct booking recap → **Complete
payment** reopens the same WebView (same gateway session, not a new order)
→ pay → confirmed e-ticket. Separately, verify the existing failed-payment
gateway redirect still lands on the same pending screen. Repeat once in
Arabic (RTL) for the dialog and badge.
