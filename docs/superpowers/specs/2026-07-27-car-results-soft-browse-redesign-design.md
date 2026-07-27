# Car results soft-browse redesign

**Date:** 2026-07-27  
**Status:** Approved for planning  
**Feature:** `lib/features/car` — results screen only  
**Visual reference:** Soft browse cards (layout A) + clean list composition (S1)

## Goal

Redesign the private-car quote results screen so cards feel like **browse → open details** (bus-style), not radio selection + sticky Continue. Details and booking stay out of scope for this slice; tap shows a localized SnackBar.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Scope | Results screen + `CarTierCard` only |
| Visual approach | Soft browse cards (Approach 2) |
| Card layout | **A** — vehicle image left; company/category/refund; spec chips; price + chevron footer |
| Screen composition | **S1** — clean list (title + count + scrollable cards); no hint banner; no trip-summary chip |
| Selection | Remove selected state UI and sticky Continue bar |
| Tap | SnackBar “details coming soon” (new l10n key; do not reuse `carBookingComingSoon`) |
| Details / contact / payment | Explicitly out of scope |

## Current problems

- Selection checkmark sits near the price and reads as “price selected,” not “card selected.”
- Sticky Continue forces a two-step select-then-confirm model that will not match the future details flow.
- Small vehicle tile + sparse whitespace with one quote feels unfinished.
- No clear affordance that the card opens something next.

## Target UX

### Screen (`CarTierResultsScreen`)

1. Keep `BookingAppBar` (route title + date subtitle) unchanged.
2. Body: scrollable list with:
   - Header row: `carChooseVehicle` + count pill (`carQuotesCount`)
   - One `CarTierCard` per quote (stable `ValueKey(quote.id)`)
3. Remove `bottomNavigationBar` / `_ContinueBar` entirely.
4. Keep: pull-to-refresh, loading skeleton, empty view, error + retry, guest auth-retry sheet on search 401.
5. On card tap: show SnackBar with new string (e.g. `carDetailsComingSoon` / Arabic equivalent). Do **not** call `selectQuote` from the results UI in this slice (notifier method may remain for a later details screen).
6. Continue to honor `AppBreakpoints.maxContentWidth` centering and scrollable body (portrait + landscape).

### Card (`CarTierCard`)

**Layout A (RTL-aware via directional APIs):**

```
┌─────────────────────────────────────────────┐
│ [image 64]  Company                    │
│             Category · Model           │
│             [Refundable badge?]        │
│─────────────────────────────────────────────│
│ [seats] [bags] [gear]  chips               │
│─────────────────────────────────────────────│
│ Price + currency          (chevron circle) │
└─────────────────────────────────────────────┘
```

- Elevated white surface (`AppColors.bgElevated`), soft shadow, `AppRadius.card`.
- No selected border / tint / checkmark; remove `selected` parameter from the widget API.
- Footer: primary price + currency; trailing chevron in `primaryTint` circle using `AppIcons.forward`, mirrored in RTL with `Transform.flip` (same pattern as `auth_back_button`).
- Spec chips unchanged in meaning (seats, bags, gear); keep `AppIcons` facade.
- Vehicle image: keep network `featuredUrl` with gradient fallback icon; size ~64 (fixed avatar size OK per responsive rules).
- Press: `InkWell` ripple; 150–300ms feel; no layout-shifting scale.

### Empty / error / loading

- Unchanged behavior; skeleton height may be adjusted slightly to match the new card proportions if tests/visuals need it.

## Localization

Add to both `app_en.arb` and `app_ar.arb`:

- `carDetailsComingSoon` — SnackBar when a quote card is tapped before the details screen ships.
- `@carDetailsComingSoon` description on the English template.

Remove or stop using UI that depends on `carSelectVehicleHint` on this screen (key may remain unused until cleaned later — prefer stop referencing; do not delete unrelated keys unless unused project-wide and safe).

## Architecture / files

| Path | Change |
|------|--------|
| `lib/features/car/presentation/widgets/car_tier_card.dart` | Soft-browse layout A; drop `selected`; chevron footer |
| `lib/features/car/presentation/car_tier_results_screen.dart` | Drop Continue bar; wire SnackBar on tap |
| `lib/l10n/app_en.arb` / `app_ar.arb` | Add `carDetailsComingSoon` |
| `test/features/car/presentation/widgets/car_tier_card_test.dart` | Assert no checkmark; assert chevron; drop `selected` |
| Screen tests (if any cover Continue / selection) | Update to new interaction |

No new routes. No API / domain entity changes. `CarBookingNotifier.selectQuote` may stay unused by UI until details.

## Out of scope

- Car details screen and navigation to it
- Contact capture, `POST /private/orders`, payment, voucher
- Changing place picker, search form, or app bar route truncation
- Bus ticket-style perforated cards
- Auto-select when a single quote exists
- New design tokens unless a gap is discovered (prefer existing `AppColors` / `AppSpacing` / `AppRadius`)

## Success criteria

- Results list matches Soft browse A + S1; no selection chrome; no bottom Continue.
- Tap shows localized details-coming-soon SnackBar.
- RTL + large text + landscape remain scrollable without overflow.
- `flutter analyze` clean for touched files; widget tests updated and green.

## Follow-up (not this plan)

Replace SnackBar with `context.push(CarRoutes.detail)` once a details screen exists; then wire `selectQuote` again at navigation time.
