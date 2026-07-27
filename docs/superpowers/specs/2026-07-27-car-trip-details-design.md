# Car trip details screen

**Date:** 2026-07-27  
**Status:** Approved for planning  
**Feature:** `lib/features/car` — trip details after soft-browse results  
**API:** `GET /private/trips/:id` (`docs/wadeny-apis.md` → Private → Show Trip Details)  
**Visual:** Layout **C** — expanded soft-browse card as the page body

## Goal

Replace the results-card “details coming soon” SnackBar with a real **trip
details** screen: show the selected private-transfer quote in an expanded soft
card, optionally refresh from `GET /private/trips/:id` when the user is signed
in, and expose a Continue CTA that gates guests into login while deferring
actual booking (`POST /private/orders`) to a later slice.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Scope | Details UI + CTA stub; **no** order/contact/payment |
| Data | **C** — show search quote immediately; refresh via details API when logged in |
| Guest refresh | **A** — skip `GET /private/trips/:id` entirely when `guestMode` is true |
| Refresh errors | **C′** — **404** → hard error; other logged-in failures → keep quote + soft message; guest never hits 401 on this call |
| CTA | **B** — guest → `showGuestGate(returnTo: details)`; signed-in → `carBookingComingSoon` SnackBar |
| Layout | **C** — one expanded soft card (continuation of soft-browse results) |
| State approach | **1** — extend `CarBookingNotifier` (`selectQuote` + `loadTripDetails`) |
| Entity | Reuse `CarTripQuote` (details payload ≈ search item) |

## Current state

- Soft-browse results (`CarTierResultsScreen` / `CarTierCard`) tap shows
  `carDetailsComingSoon` SnackBar; no details route.
- `CarBookingNotifier.selectQuote` exists but is unused by results UI.
- `CarRepository` / `CarApi` only implement `GET /private/search`.
- Follow-up noted in soft-browse redesign:
  replace SnackBar with `context.push(CarRoutes.detail)` and wire `selectQuote`
  at navigation time.

## Backend API

### `GET /private/trips/:id`

| | |
|---|---|
| Auth | Bearer required |
| Headers | `Accept`, `Accept-Language` (existing Dio interceptors) |

**200 `data`** — same shape as one search quote item:

- `id`, `rounded`, `go_price`, `round_price`, `currency`, …
- `company` (name, refundability, refund_policy, logo_url, …)
- `from_location` / `to_location`
- `vehicle` (category, seats, bags, gear, featured_url, …)

**404** — record not found (`"This record can't be found"`).

App behavior: **do not call** this endpoint while `guestModeProvider` is true
(no token → expected 401). Call only when the user is signed in.

## Non-goals

- `POST /private/orders`, contact capture, payment, voucher
- Map / distance-duration estimate
- Address book
- Bus-style coachmarks or stop selection
- New shared widgets lifted from bus unless already identical and needed twice
- Deleting unused `carDetailsComingSoon` is optional cleanup only if nothing
  references it after navigation lands

## Architecture

```
lib/features/car/
├── data/
│   ├── car_api.dart                 # + getTrip(id)
│   ├── car_dto_mapper.dart          # + quoteFromDetailsEnvelope
│   └── car_repository_impl.dart     # + getTrip
├── domain/
│   ├── entities/car_trip_quote.dart # unchanged (reuse)
│   └── repositories/car_repository.dart  # + getTrip
└── presentation/
    ├── car_routes.dart              # + details = '/car/details'
    ├── car_tier_results_screen.dart # tap → selectQuote + push
    ├── car_trip_details_screen.dart # NEW
    └── providers/car_booking_providers.dart  # + loadTripDetails + error flags
```

### Data flow

```
Results card tap
  → notifier.selectQuote(quote)
  → context.push(CarRoutes.details)

CarTripDetailsScreen
  → watch selectedQuote (instant UI)
  → on first frame / init:
       if guestMode → skip fetch
       else → notifier.loadTripDetails(quote.id)
            GET /private/trips/:id
            200 → replace selectedQuote with mapped quote
            404 → set hard details error (block body)
            other ApiException/network → soft error; keep quote

CTA
  → if guest → showGuestGate(returnTo: CarRoutes.details)
  → else → SnackBar(carBookingComingSoon)
```

### Notifier state additions

Extend `CarBookingState` (names may vary; intent is fixed):

- `isLoadingTripDetails` — subtle in-page indicator only (not full-screen
  skeleton while quote is already shown)
- `tripDetailsHardError` — non-null on 404 (or equivalent “gone”); drives hard
  error body
- `tripDetailsSoftError` — non-null on other logged-in failures; drives banner /
  SnackBar over usable UI

`loadTripDetails` clears prior details errors at start. Leaving the screen may
clear soft/hard details errors (implementation detail in plan); do not clear
`selectedQuote` on soft failure.

### Auth / guest detection

Use existing `guestModeProvider` (async). Treat `value == true` as guest; when
still resolving (`value == null`), prefer **skip fetch** until known logged-in
(avoid speculative 401). Signed-in = `guestMode.value == false` (and session
present as elsewhere in the app).

## Target UX

### Screen (`CarTripDetailsScreen`)

1. **App bar** — reuse `BookingAppBar`:
   - Title: new l10n key (e.g. `carTripDetailsTitle`)
   - Subtitle: route label from `searchParams` places when available, else
     `fromLocation.name → toLocation.name` on the quote
2. **Body** — centered to `AppBreakpoints.maxContentWidth`, scrollable
   `SafeArea`:
   - One expanded soft card (`AppColors.bgElevated`, soft shadow,
     `AppRadius.card`):
     - Large vehicle image (`featuredUrl` + gradient / icon fallback)
     - Category · vehicle name/model · year (omit empty parts)
     - Company name; logo if `logoUrl` present
     - Spec chips: seats, bags, gear (same semantics as `CarTierCard`)
     - Refundable badge when `company.refundability`; show
       `refundPolicy` text when non-empty
     - Route block: pickup / drop-off (prefer search place labels when present)
     - Price + currency via `quote.priceFor(rounded: searchParams?.rounded ??
       quote.rounded)`
   - Soft error: persistent non-blocking banner above the card (not a one-shot
     SnackBar — user must still read the quote)
   - Hard error (404): replace card with message + back + Retry that re-calls
     `loadTripDetails`
   - Missing `selectedQuote` (deep link / cold open): empty message + back
3. **Sticky footer** — price summary + primary Continue (**reuse `carContinue`**):
   - Guest → `showGuestGate(returnTo: CarRoutes.details)`
   - Signed-in → `carBookingComingSoon`
4. **Responsive** — portrait + landscape; honor text scaling; no fixed layout
   widths; footer accounts for safe insets.

### Results navigation

On `CarTierCard` tap:

1. `ref.read(carBookingProvider.notifier).selectQuote(quote)`
2. `context.push(CarRoutes.details)`
3. Remove `carDetailsComingSoon` SnackBar from this path

## Localization

Add to both `app_en.arb` (with `@key` descriptions) and `app_ar.arb`:

| Key | Purpose |
|-----|---------|
| `carTripDetailsTitle` | App bar title |
| `carTripDetailsNotFound` | Hard error when trip 404 |
| `carTripDetailsRefreshFailed` | Soft banner when signed-in refresh fails for non-404 reasons |

Reuse existing: `carContinue`, `carBookingComingSoon`, `carRefundable`, seat/bag/gear
labels used by results chips where applicable.

Stop using `carDetailsComingSoon` on results tap; key may remain until a later
cleanup if unused.

## Error matrix

| Condition | UI |
|-----------|-----|
| Guest | Show search quote; no details request |
| Signed-in, 200 | Update `selectedQuote` |
| Signed-in, 404 | Hard error body |
| Signed-in, network / other | Keep quote + soft message |
| No `selectedQuote` | Empty + navigate back affordance |

## Testing

- Mapper: details envelope → `CarTripQuote`; 404 envelope → `ApiException`
- Repository / API wiring for `getTrip`
- Notifier: guest skips fetch; success merges; 404 sets hard error; other sets
  soft error without clearing quote
- Widget: expanded card shows vehicle/company/price; CTA guest vs signed-in;
  results navigates to details with `selectQuote`
- Pump under `Locale('ar')` at minimum for new UI

## Success criteria

- Results card opens details with immediate content from the search quote
- Signed-in users refresh from `GET /private/trips/:id`; guests never call it
- Layout matches expanded soft card (C); sticky CTA behaves per locked decision
- Booking APIs remain untouched
- `flutter analyze` clean on touched paths; car feature tests green

## Follow-up (not this plan)

- Contact / `POST /private/orders` / pay / voucher
- Replace `carBookingComingSoon` CTA with real booking navigation
- Optional: re-fetch details after returning from login on the same screen
