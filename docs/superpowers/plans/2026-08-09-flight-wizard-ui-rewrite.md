# Flight Wizard UI Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) or superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the offer-details preview path and visually rewrite the flight booking wizard (card entry, step bar, review, bundles) to match the approved mock.

**Architecture:** Keep confirm-on-review and bundles-after-confirm. Fold trip summary + fare rules into Review. Shared sticky total/CTA footer pattern on Review and Bundles. Token-driven restyle only — no API changes.

**Tech Stack:** Flutter, Riverpod, go_router, Phosphor Light, ARB/`AppLocalizations`, existing `AppColors` / `AppSpacing` / `AppRadius` / `AppTypography`.

**Spec:** [`../specs/2026-08-09-flight-wizard-ui-rewrite-design.md`](../specs/2026-08-09-flight-wizard-ui-rewrite-design.md)

## Global Constraints

- Package imports (`package:safaria/...`); no hardcoded user strings/colors.
- RTL: `EdgeInsetsDirectional`, mirrored chevrons if any.
- Phosphor Light only for UI icons.
- Do not commit unless the user asks.
- Run `flutter gen-l10n` after ARB edits; never hand-edit generated l10n.

---

## File Structure

**Create:**

| File | Responsibility |
|------|----------------|
| `lib/features/flight/presentation/widgets/flight_wizard_footer.dart` | Sticky total + primary CTA used by Review and Bundles |
| `lib/features/flight/presentation/widgets/flight_trip_summary_card.dart` | Compact journey summary for Review |

**Modify:**

| File | Change |
|------|--------|
| `lib/features/flight/presentation/widgets/flight_offer_card.dart` | Drop Details; card tap = select |
| `lib/features/flight/presentation/flight_results_screen.dart` | Wire Select only; remove offer-details push |
| `lib/features/flight/presentation/flight_routes.dart` | Remove offer-details route |
| `lib/features/flight/presentation/flight_offer_details_screen.dart` | Delete file |
| `lib/features/flight/presentation/widgets/flight_booking_step_bar.dart` | Mock-aligned nodes / targets |
| `lib/features/flight/presentation/flight_review_screen.dart` | Merged content + footer + restyle |
| `lib/features/flight/presentation/flight_bundles_screen.dart` | Sticky footer + section chrome |
| `lib/features/flight/presentation/widgets/flight_bundle_card.dart` | Stronger selected hierarchy if needed |
| `lib/features/flight/presentation/widgets/flight_segment_row.dart` | Update doc comment (no details screen) |
| `test/features/flight/presentation/flight_offer_card_test.dart` | Expect no Details; card/select behavior |
| `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` | Only if new strings needed |

**Delete:**

| File |
|------|
| `lib/features/flight/presentation/flight_offer_details_screen.dart` |

---

### Task 1: Remove Details from result card

**Files:**
- Modify: `lib/features/flight/presentation/widgets/flight_offer_card.dart`
- Modify: `lib/features/flight/presentation/flight_results_screen.dart`
- Test: `test/features/flight/presentation/flight_offer_card_test.dart`

**Interfaces:**
- Consumes: existing `onSelect`
- Produces: `FlightOfferCard({ required onSelect, … })` — remove `onTap` (or make it optional unused); `_FareStub` without Details

- [x] **Step 1: Update failing expectations in the card test**

Remove `expect(find.text('Details'), …)`. Add: tapping the card body calls `onSelect`. Keep Select button test.

- [x] **Step 2: Run test — expect FAIL** (Details still present / API mismatch)

Run: `flutter test test/features/flight/presentation/flight_offer_card_test.dart`

- [x] **Step 3: Implement card + results wiring**

- Remove Details `TextButton`, `detailsLabel`, `onDetails`.
- Remove `onTap`; `InkWell.onTap` → `onSelect`.
- Results: only `onSelect: selectOffer + push(review)`; drop `offerDetails` push.

- [x] **Step 4: Run card test — expect PASS**

Run: `flutter test test/features/flight/presentation/flight_offer_card_test.dart`

---

### Task 2: Delete offer-details route and screen

**Files:**
- Delete: `lib/features/flight/presentation/flight_offer_details_screen.dart`
- Modify: `lib/features/flight/presentation/flight_routes.dart`
- Modify: `lib/features/flight/presentation/widgets/flight_segment_row.dart` (doc comment)
- Grep: remove any remaining `offerDetails` / `FlightOfferDetailsScreen` refs

- [x] **Step 1: Remove route constant + `GoRoute`**
- [x] **Step 2: Delete the screen file**
- [x] **Step 3: Fix imports / comments**
- [x] **Step 4: Verify**

Run: `rg "offerDetails|FlightOfferDetailsScreen|flightViewDetails" lib test`  
Expected: no code refs (ARB key may remain unused — remove key from both ARBs if unused).

---

### Task 3: Shared wizard footer

**Files:**
- Create: `lib/features/flight/presentation/widgets/flight_wizard_footer.dart`

**Interfaces:**
- Produces: `FlightWizardFooter({ required String totalLabel, required String totalText, required String ctaLabel, required VoidCallback? onCta, … })`

- [x] **Step 1: Implement sticky SafeArea footer** — total row + full-width `PrimaryButton`
- [x] **Step 2: Use tokens only; directional padding**

---

### Task 4: Trip summary card + Review rewrite

**Files:**
- Create: `lib/features/flight/presentation/widgets/flight_trip_summary_card.dart`
- Modify: `lib/features/flight/presentation/flight_review_screen.dart`
- Modify: `lib/features/flight/presentation/widgets/flight_wizard_footer.dart` (consume)

**Interfaces:**
- Consumes: `FlightOffer` / confirmed order journeys, fare rules from offer, `FlightWizardFooter`
- Produces: Review UI matching spec Section 2

- [x] **Step 1: Build `FlightTripSummaryCard`** for one journey (route, date, times, stops label)
- [x] **Step 2: Rewrite Review body** — banner, summaries, fare rules, breakdown
- [x] **Step 3: Wire sticky footer** with total + continue / accept CTA
- [x] **Step 4: Keep confirm-on-entry / error / loading behavior**

---

### Task 5: Step bar polish

**Files:**
- Modify: `lib/features/flight/presentation/widgets/flight_booking_step_bar.dart`
- Test: `test/features/flight/domain/flight_wizard_step_test.dart` (logic unchanged — smoke only if needed)

- [x] **Step 1: Enlarge hit targets (≥44), filled current node, connector tint**
- [x] **Step 2: Preserve completed → pop, upcoming inert**

---

### Task 6: Bundles screen chrome + footer

**Files:**
- Modify: `lib/features/flight/presentation/flight_bundles_screen.dart`
- Modify: `lib/features/flight/presentation/widgets/flight_bundle_card.dart` (if hierarchy weak)

- [x] **Step 1: Section headers (leg + route) match mock hierarchy**
- [x] **Step 2: Replace bottom-only button with `FlightWizardFooter`**
- [x] **Step 3: Keep selection / Next-enable rules**

---

### Task 7: l10n cleanup + analyze

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` as needed
- Any new labels for taxes row / date formatting already covered by existing keys preferred

- [x] **Step 1: Remove unused `flightViewDetails` if nothing references it**
- [x] **Step 2: `flutter gen-l10n` if ARB changed**
- [x] **Step 3: `flutter analyze` on touched paths**
- [x] **Step 4: Re-run offer card test + wizard step test**

Run:
```bash
flutter test test/features/flight/presentation/flight_offer_card_test.dart test/features/flight/domain/flight_wizard_step_test.dart
flutter analyze lib/features/flight
```
