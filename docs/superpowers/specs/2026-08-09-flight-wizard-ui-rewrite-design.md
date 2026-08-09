# Flight wizard UI rewrite — design

**Date:** 2026-08-09  
**Status:** Approved in brainstorming — ready for implementation  
**Extends:** [`2026-08-08-flight-booking-screens-design.md`](2026-08-08-flight-booking-screens-design.md)  
**Visual reference:** Product mock (Arabic RTL) — Step 1 Review + Step 2 Bundles

## Goal

Remove the separate offer-details preview path. Selecting a flight enters the
booking wizard. Visually rewrite the wizard chrome (step bar, review, bundles)
to match the mock’s hierarchy and sticky total/CTA, while merging useful
offer-details content (trip summary, fare rules) into Review.

## Decisions (brainstorming 2026-08-09)

| Question | Decision |
|----------|----------|
| How to open booking | **A** — only **Select this flight** (no Details CTA) |
| Details vs wizard | **C** — enhance existing wizard UI (not Material tabs) |
| Offer-details screen | **C** — merge segments/fare rules into Review; delete route |
| Scope depth | **3** — full visual rewrite of step bar + review + bundles |

## Scope

| In | Out |
|----|-----|
| Remove Details from `FlightOfferCard` | Passengers / pay screen redesign |
| Delete `/flight/offer-details` + screen | Backend / confirm / bundles API changes |
| Merge trip summary + fare rules into Review | New Material `TabBar` |
| Restyle Review, Bundles, `FlightBookingStepBar` | Changing wizard step order |
| Sticky total + CTA footers on Review & Bundles | Card-tap preview of other offers |
| Update card / results tests + l10n as needed | Hold / refund flows |

## Navigation

```
Results
  └─ Select this flight → selectOffer → /flight/review
         → (if haveBundles) /flight/bundles
         → /flight/passengers → …
```

- Card `InkWell`: same as Select (`onSelect`) — no preview route.
- `FlightRoutes.offerDetails` and `FlightOfferDetailsScreen` removed.
- Wizard order unchanged: Review → Bundles? → Passengers → Pay.
- Confirm still runs on Review entry; bundles still need confirmed offer id.

## Visual system

- Use existing Skyline tokens (`AppColors`, `AppSpacing`, `AppRadius`,
  `AppTypography`). Mock is dark-reference for **structure**, not a new palette.
- Light remains primary; dark mode gets the same layout.
- Phosphor Light icons only; directional APIs; all copy via ARB.
- Scrollable bodies; content capped to `AppBreakpoints.maxContentWidth`.
- Sticky footers respect `SafeArea` and keyboard insets.

## Screen: Review (step 1)

**Chrome:** `BookingAppBar` + `FlightBookingStepBar` (current = review).

**Body (when confirmed), top → bottom:**

1. Price-change banner (if searched ≠ confirmed) — secondary/amber surface,
   icon + localized was → now.
2. Trip summary card(s) — one per journey: route, date, times, Direct/stops
   (compact; derived from offer/confirmed journeys).
3. Fare rules section when rules exist (from offer `priceClasses`).
4. Price breakdown rows (passengers + taxes/fees when available) with
   localized labels where practical.

**Footer (sticky):** Total label + amount/currency; CTA Continue or
Accept-and-continue when price changed.

**States:** confirming spinner; error + back to results; confirmed content.

## Screen: Bundles (step 2)

**Chrome:** app bar + step bar (current = bundles).

**Body:** Per-journey section header (leg + route). Full list of selectable
`FlightBundleCard`s (selected = primary tint + border; included vs `+ delta`;
service bullets with checks). Prefer always-visible cards over a single
collapsed dropdown.

**Footer (sticky):** Running total (existing pricing utils); Next enabled only
when every journey has a selection.

**States:** loading / error / empty — keep behavior, restyle chrome.

## Step bar

- Current: filled primary circle.
- Completed: check; tappable → `Navigator.pop`.
- Upcoming: muted ring; inert.
- Connectors tint with progress.
- Touch targets ≥ 44 logical px without changing wizard logic.

## Results card

- Remove Details `TextButton` and `detailsLabel` / `onDetails` from `_FareStub`.
- Remove or repurpose `onTap` — card tap = `onSelect`.
- Keep Select primary button.

## Out of scope / non-goals

- No new booking API calls or step reordering.
- No passengers/pay visual rewrite in this change.
- No inventing passenger-type display names beyond existing l10n helpers if
  already present; improve only when a key already exists or is added with AR/EN.

## Success criteria

- No “Details” control on result cards; Select enters Review.
- Offer-details route/screen gone; no dangling references.
- Review shows trip summary + optional fare rules + breakdown + sticky total.
- Bundles match mock hierarchy (per-leg cards + sticky total).
- Step bar matches mock states; RTL + landscape scroll OK.
- `flutter analyze` clean on touched files; offer-card (and related) tests updated.
