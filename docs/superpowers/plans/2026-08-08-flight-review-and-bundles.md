# Flight Review and Bundles Implementation Plan (Phase 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Take a rider from a selected offer to a precisely priced trip — confirming the fare, then choosing a bundle per leg.

**Architecture:** A four-step wizard whose step list is derived, not fixed: `haveBundles` decides whether the bundle step exists at all. Each step asserts its predecessor's state and bounces to results otherwise. The offer id changes at confirm, and every later call must use the new one — that relay is the single highest-risk thing in this phase, so it is enforced in the notifier rather than left to each screen.

**Tech Stack:** Flutter, Riverpod (`Notifier`), Freezed, Dio, go_router, ARB codegen.

**Scope:** Phase 2 of [`2026-08-08-flight-booking-screens-design.md`](../specs/2026-08-08-flight-booking-screens-design.md). Ends when a rider can price a trip exactly. Passenger entry is Phase 3; payment is Phase 4.

**Depends on:** Phase 1, merged — commits `9e7ee88` through `753ba5e`.

---

## Task 1 gates this plan

`lib/features/flight/data/flight_api.dart` records that `GET /flights/{offer_id}/bundles` has **never** returned a success payload against the demo backend — every attempt gave `400 "offer id is not valid or expired"`, and the saved Postman example is that same error.

Read alongside the flow spec, this is the relay bug rather than a broken endpoint: those attempts ran straight after a **search**, so they sent offer id **A**. Bundles needs offer id **B**, the one confirm returns.

Task 1 proves or disproves that with one real call sequence, and captures the payload the mapper is written against. **Tasks 6–9 are blocked until it produces a success body.** Tasks 2–5 build the review step and are not blocked either way.

If Task 1 still returns `400` using offer id B, stop and take it to the backend team — do not build bundle UI against a guessed shape.

---

## File Structure

**Create:**

| File | Responsibility |
|------|----------------|
| `test/features/flight/data/flight_bundles_fixture.dart` | The real bundles payload captured in Task 1 |
| `lib/features/flight/domain/entities/flight_bundle.dart` | Bundle, its prices, and the per-journey grouping |
| `lib/features/flight/domain/entities/flight_wizard_step.dart` | The derived step list |
| `lib/features/flight/domain/utils/flight_bundle_pricing.dart` | Bundle deltas and the running total — pure |
| `lib/features/flight/domain/utils/flight_price_change.dart` | Searched vs confirmed price comparison — pure |
| `lib/features/flight/presentation/flight_review_screen.dart` | Step 1 |
| `lib/features/flight/presentation/flight_bundles_screen.dart` | Step 2 |
| `lib/features/flight/presentation/widgets/flight_booking_step_bar.dart` | Progress header, flight's own |
| `lib/features/flight/presentation/widgets/flight_bundle_card.dart` | One selectable bundle |

**Modify:**

| File | Change |
|------|--------|
| `lib/features/flight/data/flight_dto_mapper.dart` | Bundle mapping |
| `lib/features/flight/data/flight_api.dart` | Replace the stale "do not build a mapper" note |
| `lib/features/flight/domain/entities/flight_confirmed_order.dart` | Replace the stale "stubbed/mocked" note |
| `lib/features/flight/domain/repositories/flight_repository.dart` | Add `bundles` |
| `lib/features/flight/data/flight_repository_impl.dart` | Implement `bundles` |
| `lib/features/flight/presentation/providers/flight_booking_providers.dart` | Wizard state and the offer id relay |
| `lib/features/flight/presentation/flight_routes.dart` | Two new routes |
| `lib/features/flight/presentation/flight_offer_details_screen.dart` | Replace the coming-soon snackbar |
| `lib/features/flight/presentation/widgets/flight_offer_card.dart` | Second action on the card |
| `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` | New strings |

---

## Task 1: Prove the offer id relay against the live backend

A spike, not a feature. It produces a fixture file and a yes/no answer.

**Files:**
- Create: `test/features/flight/data/flight_bundles_fixture.dart`

- [x] **Step 1: Capture a search offer id**

Run the app against the demo backend, search `CAI` → `RUH` for a date about three weeks out, and copy the `offerId` of any result whose `haveBundles` is true. Add a temporary `debugPrint` in `FlightDtoMapper.offersFromEnvelope` if that is easier than reading the network log.

- [x] **Step 2: Confirm it, and capture the new offer id**

```bash
curl -s -X POST "https://demo.safaria.travel/api/v1/flights/$(python -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" 'PASTE_SEARCH_OFFER_ID')/confirm" \
  -H "Accept: application/json" \
  -H "Accept-Language: en" \
  -H "Authorization: Bearer PASTE_TOKEN"
```

Expected: `200` with `data.offerId`. **That value is offer id B.** It will differ from the one you pasted — if it does not, stop and report that, because the whole relay premise depends on it changing.

- [x] **Step 3: Call bundles with offer id B**

```bash
curl -s "https://demo.safaria.travel/api/v1/flights/$(python -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" 'PASTE_OFFER_ID_B')/bundles" \
  -H "Accept: application/json" \
  -H "Accept-Language: en" \
  -H "Authorization: Bearer PASTE_TOKEN"
```

Two outcomes:

- **`200` with a `data` array** — the relay theory holds. Continue to step 4.
- **`400 "not valid or expired"`** — stop here. Tasks 6–9 are blocked. Report the exact request and response to the backend team, and note that offer id B was used, not A. Tasks 2–5 can still proceed and ship a working review step.

- [x] **Step 4: Also settle bundle pricing for mixed passenger types**

Repeat steps 1–3 with a search for **2 adults and 1 child**. Inspect `data[].bundles[].bundle_prices` in the response and record which shape it takes:

- a single object → one price for the whole party, or per passenger
- an array of objects, one per `passenger_type_code` → priced per type

This is open question 2 in the spec. Task 7's mapper handles both shapes, so this does not block, but the answer decides whether Task 8's total is right.

- [x] **Step 5: Save the payload as a fixture**

Create `test/features/flight/data/flight_bundles_fixture.dart` with the captured body, trimmed to two journeys and two bundles each, following the style of `test/features/flight/data/flight_fixtures.dart`:

```dart
/// Captured from a live GET /flights/{offer_id}/bundles (200), using the
/// offer id returned by confirm — not the one from search.
const bundlesEnvelope = {
  'status': 200,
  'message': 'Available bundles',
  'errors': <String, dynamic>{},
  'data': [
    // paste the trimmed data array here
  ],
};
```

- [x] **Step 6: Record the outcome in the spec**

In `docs/superpowers/specs/2026-08-08-flight-booking-flow-design.md`, move item 2 out of "Still open" into the resolved table with what you observed, and note whether offer id B differed from A.

- [x] **Step 7: Commit**

```bash
git add test/features/flight/data/flight_bundles_fixture.dart docs/superpowers/specs/2026-08-08-flight-booking-flow-design.md
git commit -m "Capture Live Flight Bundles Payload"
```

---

## Task 2: Derive the wizard steps

The step list is data, not a constant — an offer without bundles has three steps, not four with one greyed out.

**Files:**
- Create: `lib/features/flight/domain/entities/flight_wizard_step.dart`
- Test: `test/features/flight/domain/flight_wizard_step_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_wizard_step.dart';

void main() {
  test('an offer with bundles has four steps', () {
    expect(flightWizardSteps(haveBundles: true), [
      FlightWizardStep.review,
      FlightWizardStep.bundles,
      FlightWizardStep.passengers,
      FlightWizardStep.pay,
    ]);
  });

  test('an offer without bundles omits the bundle step entirely', () {
    final steps = flightWizardSteps(haveBundles: false);
    expect(steps, [
      FlightWizardStep.review,
      FlightWizardStep.passengers,
      FlightWizardStep.pay,
    ]);
    expect(steps.contains(FlightWizardStep.bundles), isFalse);
  });

  test('index reflects position in the derived list, not the enum', () {
    expect(
      flightWizardStepIndex(FlightWizardStep.passengers, haveBundles: false),
      1,
    );
    expect(
      flightWizardStepIndex(FlightWizardStep.passengers, haveBundles: true),
      2,
    );
  });

  test('a step absent from the list has no index', () {
    expect(
      flightWizardStepIndex(FlightWizardStep.bundles, haveBundles: false),
      isNull,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight/domain/flight_wizard_step_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Write the implementation**

Create `lib/features/flight/domain/entities/flight_wizard_step.dart`:

```dart
/// Steps of the flight booking wizard, in flow order.
enum FlightWizardStep { review, bundles, passengers, pay }

/// The steps this booking actually has. Offers without bundles skip that
/// step rather than showing it disabled — a step a rider can never reach is
/// noise, not progress.
List<FlightWizardStep> flightWizardSteps({required bool haveBundles}) {
  return [
    FlightWizardStep.review,
    if (haveBundles) FlightWizardStep.bundles,
    FlightWizardStep.passengers,
    FlightWizardStep.pay,
  ];
}

/// Position of [step] in the derived list, or null when this booking has no
/// such step.
int? flightWizardStepIndex(
  FlightWizardStep step, {
  required bool haveBundles,
}) {
  final index = flightWizardSteps(haveBundles: haveBundles).indexOf(step);
  return index == -1 ? null : index;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/flight/domain/flight_wizard_step_test.dart`
Expected: PASS — 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/flight/domain/entities/flight_wizard_step.dart test/features/flight/domain/flight_wizard_step_test.dart
git commit -m "Derive Flight Wizard Steps From Offer"
```

---

## Task 3: Detect a price change at confirm

**Files:**
- Create: `lib/features/flight/domain/utils/flight_price_change.dart`
- Test: `test/features/flight/domain/flight_price_change_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/utils/flight_price_change.dart';

void main() {
  test('an unchanged price reports no change', () {
    expect(flightPriceChange(searched: 15825.55, confirmed: 15825.55), isNull);
  });

  test('sub-piastre drift is not a price change', () {
    expect(flightPriceChange(searched: 15825.55, confirmed: 15825.554), isNull);
  });

  test('an increase is reported with both amounts', () {
    final change = flightPriceChange(searched: 15825.55, confirmed: 16200);
    expect(change, isNotNull);
    expect(change!.wasSearched, 15825.55);
    expect(change.nowConfirmed, 16200);
    expect(change.isIncrease, isTrue);
  });

  test('a decrease is still reported — the rider should see it', () {
    final change = flightPriceChange(searched: 16200, confirmed: 15825.55);
    expect(change!.isIncrease, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight/domain/flight_price_change_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Write the implementation**

Create `lib/features/flight/domain/utils/flight_price_change.dart`:

```dart
/// A re-price between the searched offer and the confirmed one.
class FlightPriceChange {
  const FlightPriceChange({
    required this.wasSearched,
    required this.nowConfirmed,
  });

  final double wasSearched;
  final double nowConfirmed;

  bool get isIncrease => nowConfirmed > wasSearched;
}

/// Providers re-price between search and confirm. Returns null when the fare
/// held.
///
/// Differences below one piastre are float noise from the round-trip through
/// JSON, not a re-price, and must not trigger the acceptance banner.
FlightPriceChange? flightPriceChange({
  required double searched,
  required double confirmed,
}) {
  if ((confirmed - searched).abs() < 0.01) return null;
  return FlightPriceChange(wasSearched: searched, nowConfirmed: confirmed);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/flight/domain/flight_price_change_test.dart`
Expected: PASS — 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/flight/domain/utils/flight_price_change.dart test/features/flight/domain/flight_price_change_test.dart
git commit -m "Detect Flight Price Changes At Confirm"
```

---

## Task 4: Wizard state and the offer id relay

The relay is the highest-risk mechanic in the booking flow, so it lives in one place with a name, rather than each screen reaching for whichever id it happens to hold.

**Files:**
- Modify: `lib/features/flight/presentation/providers/flight_booking_providers.dart`

- [ ] **Step 1: Extend the state**

Add to `FlightBookingState`:

```dart
    FlightOffer? selectedOffer,
    FlightConfirmedOrder? confirmedOrder,
    @Default(<String, String>{}) Map<String, String> selectedBundleCodes,
    @Default([]) List<FlightJourneyBundles> journeyBundles,
```

`selectedBundleCodes` maps `offer_journey_id` to `bundle_code` — one entry per leg the rider has chosen for.

Add a getter on the state, using the private-constructor form already in the class:

```dart
  /// The offer id later steps must send. Confirm mints a new one and every
  /// call after it — bundles, passengers, order creation — must use that,
  /// never the id from search. Sending the searched id is what produces
  /// `400 "offer id is not valid or expired"`.
  String? get activeOfferId =>
      confirmedOrder?.offerId ?? selectedOffer?.offerId;
```

Add the imports:

```dart
import 'package:safaria/features/flight/domain/entities/flight_bundle.dart';
import 'package:safaria/features/flight/domain/entities/flight_confirmed_order.dart';
```

- [ ] **Step 2: Add the confirm action**

Add to `FlightBookingNotifier`:

```dart
  /// Enters the wizard. Clears any state from a previous booking attempt so
  /// a second run cannot inherit the first one's confirmed order.
  void selectOffer(FlightOffer offer) {
    state = state.copyWith(
      selectedOffer: offer,
      confirmedOrder: null,
      journeyBundles: [],
      selectedBundleCodes: {},
      error: null,
    );
  }

  Future<void> confirmSelectedOffer() async {
    final offer = state.selectedOffer;
    if (offer == null) return;
    state = state.copyWith(
      status: FlightBookingStatus.confirming,
      error: null,
    );
    try {
      final confirmed = await _repo.confirmOrder(offer.offerId);
      state = state.copyWith(
        status: FlightBookingStatus.idle,
        confirmedOrder: confirmed,
      );
    } catch (e) {
      state = state.copyWith(
        status: FlightBookingStatus.error,
        error: e.toString(),
      );
    }
  }
```

Extend the status enum:

```dart
enum FlightBookingStatus { idle, searching, confirming, loadingBundles, error }
```

- [ ] **Step 3: Regenerate and analyze**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter analyze lib/features/flight`
Expected: errors only where `FlightJourneyBundles` is not yet defined — that lands in Task 6. If Task 1 was blocked, temporarily omit the `journeyBundles` field and its import so this task still compiles.

- [ ] **Step 4: Commit**

```bash
git add lib/features/flight/presentation/providers/flight_booking_providers.dart
git commit -m "Hold Confirmed Flight Order And Relay Offer Id"
```

---

## Task 5: Step bar and the review screen

**Files:**
- Create: `lib/features/flight/presentation/widgets/flight_booking_step_bar.dart`
- Create: `lib/features/flight/presentation/flight_review_screen.dart`
- Modify: `lib/features/flight/presentation/flight_routes.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`

- [ ] **Step 1: Add the strings**

In `lib/l10n/app_en.arb`:

```json
  "flightStepReview": "Review",
  "flightStepBundles": "Bundle",
  "flightStepPassengers": "Passengers",
  "flightStepPay": "Pay",
  "flightReviewTitle": "Review your flight",
  "flightPriceChanged": "The airline changed this fare",
  "flightPriceWas": "Was {old}",
  "flightPriceNow": "Now {new}",
  "flightAcceptAndContinue": "Accept and continue",
  "flightContinue": "Continue",
  "flightBackToResults": "Back to results",
  "@flightPriceWas": { "placeholders": { "old": {"type": "String"} } },
  "@flightPriceNow": { "placeholders": { "new": {"type": "String"} } },
```

In `lib/l10n/app_ar.arb`:

```json
  "flightStepReview": "مراجعة",
  "flightStepBundles": "الحزمة",
  "flightStepPassengers": "الركاب",
  "flightStepPay": "الدفع",
  "flightReviewTitle": "مراجعة الرحلة",
  "flightPriceChanged": "السعر اتغيّر من شركة الطيران",
  "flightPriceWas": "كان {old}",
  "flightPriceNow": "بقى {new}",
  "flightAcceptAndContinue": "موافق، كمّل",
  "flightContinue": "التالي",
  "flightBackToResults": "رجوع للنتايج",
```

- [ ] **Step 2: Write the step bar**

Create `lib/features/flight/presentation/widgets/flight_booking_step_bar.dart`. It is flight's own — the bus bar in `lib/features/bus/presentation/widgets/booking_step_bar.dart` is coupled to `BusBookingStep` and bus routes, and this project keeps transport features fully isolated.

```dart
import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_wizard_step.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Progress header for the flight booking wizard. The step list is derived
/// from the offer, so an offer without bundles shows three nodes rather than
/// four with one unreachable.
///
/// Completed steps pop back to their screen; upcoming steps are inert —
/// forward movement is gated by each screen's own call to action.
class FlightBookingStepBar extends StatelessWidget {
  const FlightBookingStepBar({
    super.key,
    required this.current,
    required this.haveBundles,
  });

  final FlightWizardStep current;
  final bool haveBundles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = flightWizardSteps(haveBundles: haveBundles);
    final currentIndex =
        flightWizardStepIndex(current, haveBundles: haveBundles) ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 20),
                  color: i <= currentIndex
                      ? AppColors.primary
                      : AppColors.hairline,
                ),
              ),
            _StepNode(
              label: _labelFor(l10n, steps[i]),
              isCompleted: i < currentIndex,
              isCurrent: i == currentIndex,
              onTap: i < currentIndex ? () => Navigator.of(context).pop() : null,
            ),
          ],
        ],
      ),
    );
  }

  static String _labelFor(AppLocalizations l10n, FlightWizardStep step) {
    return switch (step) {
      FlightWizardStep.review => l10n.flightStepReview,
      FlightWizardStep.bundles => l10n.flightStepBundles,
      FlightWizardStep.passengers => l10n.flightStepPassengers,
      FlightWizardStep.pay => l10n.flightStepPay,
    };
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
    this.onTap,
  });

  final String label;
  final bool isCompleted;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = isCompleted || isCurrent;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrent ? AppColors.primary : Colors.transparent,
              border: Border.all(
                color: active ? AppColors.primary : AppColors.hairline,
              ),
            ),
            child: isCompleted
                ? const Icon(Icons.check, size: 12, color: AppColors.primary)
                : null,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: active ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Write the review screen**

Create `lib/features/flight/presentation/flight_review_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_wizard_step.dart';
import 'package:safaria/features/flight/domain/utils/flight_price_change.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_booking_step_bar.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Wizard step 1. Calls confirm on entry — the searched fare is an estimate
/// until the provider re-prices it.
class FlightReviewScreen extends ConsumerStatefulWidget {
  const FlightReviewScreen({super.key});

  @override
  ConsumerState<FlightReviewScreen> createState() => _FlightReviewScreenState();
}

class _FlightReviewScreenState extends ConsumerState<FlightReviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(flightBookingProvider.notifier).confirmSelectedOffer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(flightBookingProvider);
    final offer = state.selectedOffer;

    // Guard: a restored route or an odd back-stack must not open a mid-flow
    // step against empty state.
    if (offer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(FlightRoutes.results);
      });
      return const SizedBox.shrink();
    }

    final confirmed = state.confirmedOrder;
    final change = confirmed == null
        ? null
        : flightPriceChange(
            searched: offer.totalAmount,
            confirmed: confirmed.priceDetails.totalAmount,
          );

    return Scaffold(
      appBar: BookingAppBar(title: l10n.flightReviewTitle),
      body: Column(
        children: [
          FlightBookingStepBar(
            current: FlightWizardStep.review,
            haveBundles: offer.haveBundles,
          ),
          if (state.status == FlightBookingStatus.confirming)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (state.status == FlightBookingStatus.error)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.error ?? '',
                        textAlign: TextAlign.center,
                        style: AppTypography.body
                            .copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        label: l10n.flightBackToResults,
                        variant: PrimaryButtonVariant.ghost,
                        onPressed: () => context.go(FlightRoutes.results),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (confirmed != null)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (change != null) _PriceChangeBanner(change: change),
                  for (final breakdown in confirmed.passengerFareBreakdown)
                    _FareRow(
                      label:
                          '${breakdown.numberOfPassengers} × ${breakdown.passengerTypeCode}',
                      amount: breakdown.passengerTotalAmount,
                      currency: confirmed.priceDetails.currency,
                    ),
                  const Divider(),
                  _FareRow(
                    label: l10n.flightPriceTotal,
                    amount: confirmed.priceDetails.totalAmount,
                    currency: confirmed.priceDetails.currency,
                    emphasized: true,
                  ),
                ],
              ),
            ),
          if (confirmed != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: PrimaryButton(
                // Wording carries the weight here: when the fare moved, this
                // must read as an explicit acceptance, not a habitual next.
                label: change == null
                    ? l10n.flightContinue
                    : l10n.flightAcceptAndContinue,
                onPressed: () => context.push(
                  offer.haveBundles
                      ? FlightRoutes.bundles
                      : FlightRoutes.passengers,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PriceChangeBanner extends StatelessWidget {
  const _PriceChangeBanner({required this.change});

  final FlightPriceChange change;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.secondaryTint,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.flightPriceChanged,
            style: AppTypography.body.copyWith(color: AppColors.secondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.flightPriceWas(change.wasSearched.toStringAsFixed(0)),
            style: AppTypography.caption.copyWith(color: AppColors.secondary),
          ),
          Text(
            l10n.flightPriceNow(change.nowConfirmed.toStringAsFixed(0)),
            style: AppTypography.caption.copyWith(color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}

class _FareRow extends StatelessWidget {
  const _FareRow({
    required this.label,
    required this.amount,
    required this.currency,
    this.emphasized = false,
  });

  final String label;
  final double amount;
  final String currency;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized ? AppTypography.h2 : AppTypography.body;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('${amount.toStringAsFixed(0)} $currency', style: style),
        ],
      ),
    );
  }
}
```

`FlightRoutes.passengers` does not exist until Phase 3. Until then, point that branch at `FlightRoutes.results` and leave a note; Task 9 of the Phase 3 plan replaces it.

- [ ] **Step 4: Register the routes**

In `lib/features/flight/presentation/flight_routes.dart`, add:

```dart
  static const review = '/flight/review';
  static const bundles = '/flight/bundles';
```

```dart
      GoRoute(
        path: FlightRoutes.review,
        builder: (context, state) => const FlightReviewScreen(),
      ),
      GoRoute(
        path: FlightRoutes.bundles,
        builder: (context, state) => const FlightBundlesScreen(),
      ),
```

Add the bundles route only after Task 8 creates that screen.

- [ ] **Step 5: Analyze and commit**

Run: `flutter gen-l10n && flutter analyze lib/features/flight`
Expected: no issues, other than the bundles screen if Task 8 has not landed.

```bash
git add lib/features/flight/presentation lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "Add Flight Review Step With Price Change Acceptance"
```

---

## Task 6: Bundle entities and mapper

**Blocked on Task 1 producing a success payload.**

**Files:**
- Create: `lib/features/flight/domain/entities/flight_bundle.dart`
- Modify: `lib/features/flight/data/flight_dto_mapper.dart`
- Test: `test/features/flight/data/flight_bundle_mapper_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/data/flight_dto_mapper.dart';

import 'flight_bundles_fixture.dart';

void main() {
  test('maps the captured payload into journeys and bundles', () {
    final result = FlightDtoMapper.journeyBundlesFromEnvelope(bundlesEnvelope);
    expect(result, isNotEmpty);
    expect(result.first.offerJourneyId, isNotEmpty);
    expect(result.first.bundles, isNotEmpty);
    expect(result.first.bundles.first.code, isNotEmpty);
  });

  test('a single bundle_prices object becomes a one-entry list', () {
    final envelope = {
      'data': [
        {
          'offer_journey_id': 'j1',
          'bundles': [
            {
              'bundle_code': 'RCAI',
              'bundle_name': 'Light',
              'bundle_prices': {
                'passenger_type_code': 'ADT',
                'total_amount': 250,
                'taxes_amount': 0,
                'fee_mount': 0,
                'currency': 'EGP',
              },
              'included_services': ['15KG Check-in Baggage'],
            },
          ],
        },
      ],
    };
    final result = FlightDtoMapper.journeyBundlesFromEnvelope(envelope);
    final prices = result.first.bundles.first.prices;
    expect(prices, hasLength(1));
    expect(prices.first.passengerTypeCode, 'ADT');
    expect(prices.first.totalAmount, 250);
  });

  test('an array of bundle_prices maps one entry per passenger type', () {
    final envelope = {
      'data': [
        {
          'offer_journey_id': 'j1',
          'bundles': [
            {
              'bundle_code': 'RCAI',
              'bundle_name': 'Light',
              'bundle_prices': [
                {'passenger_type_code': 'ADT', 'total_amount': 250},
                {'passenger_type_code': 'CHD', 'total_amount': 125},
              ],
              'included_services': <String>[],
            },
          ],
        },
      ],
    };
    final result = FlightDtoMapper.journeyBundlesFromEnvelope(envelope);
    expect(
      result.first.bundles.first.prices
          .map((p) => p.passengerTypeCode)
          .toList(),
      ['ADT', 'CHD'],
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight/data/flight_bundle_mapper_test.dart`
Expected: FAIL — `journeyBundlesFromEnvelope` is not defined.

- [ ] **Step 3: Write the entities**

Create `lib/features/flight/domain/entities/flight_bundle.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'flight_bundle.freezed.dart';

/// A bundle's price for one passenger type.
///
/// The wire field is `fee_mount` — a backend typo for fee amount, mapped to
/// [feeAmount] here rather than propagated.
@freezed
abstract class FlightBundlePrice with _$FlightBundlePrice {
  const factory FlightBundlePrice({
    required String passengerTypeCode,
    required double totalAmount,
    @Default(0) double taxesAmount,
    @Default(0) double feeAmount,
    String? currency,
    String? bundleReferences,
  }) = _FlightBundlePrice;
}

@freezed
abstract class FlightBundle with _$FlightBundle {
  const factory FlightBundle({
    required String code,
    required String name,
    required List<FlightBundlePrice> prices,
    @Default(<String>[]) List<String> includedServices,
  }) = _FlightBundle;
}

/// The bundles offered for one leg. [offerJourneyId] is the `journeyKey` sent
/// back when creating the order.
@freezed
abstract class FlightJourneyBundles with _$FlightJourneyBundles {
  const factory FlightJourneyBundles({
    required String offerJourneyId,
    required List<FlightBundle> bundles,
  }) = _FlightJourneyBundles;
}
```

- [ ] **Step 4: Write the mapper**

Add to `lib/features/flight/data/flight_dto_mapper.dart`:

```dart
  static List<FlightJourneyBundles> journeyBundlesFromEnvelope(dynamic body) {
    final data = body is Map ? body['data'] : null;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(_journeyBundlesFromJson)
        .toList(growable: false);
  }

  static FlightJourneyBundles _journeyBundlesFromJson(Map json) {
    final bundles = json['bundles'];
    return FlightJourneyBundles(
      offerJourneyId: _string(json['offer_journey_id']) ?? '',
      bundles: bundles is List
          ? bundles.whereType<Map>().map(_bundleFromJson).toList()
          : const [],
    );
  }

  static FlightBundle _bundleFromJson(Map json) {
    final services = json['included_services'];
    return FlightBundle(
      code: _string(json['bundle_code']) ?? '',
      name: _string(json['bundle_name']) ?? '',
      prices: _bundlePrices(json['bundle_prices']),
      includedServices: services is List
          ? services.map((s) => s.toString()).toList()
          : const [],
    );
  }

  /// `bundle_prices` arrives as a single object on some providers and an
  /// array on others. Normalizing to a list here means the pricing rules
  /// downstream only handle one shape.
  static List<FlightBundlePrice> _bundlePrices(dynamic raw) {
    if (raw is Map) return [_bundlePriceFromJson(raw)];
    if (raw is List) {
      return raw.whereType<Map>().map(_bundlePriceFromJson).toList();
    }
    return const [];
  }

  static FlightBundlePrice _bundlePriceFromJson(Map json) {
    return FlightBundlePrice(
      passengerTypeCode: _string(json['passenger_type_code']) ?? 'ADT',
      totalAmount: _double(json['total_amount']) ?? 0,
      taxesAmount: _double(json['taxes_amount']) ?? 0,
      feeAmount: _double(json['fee_mount']) ?? 0,
      currency: _string(json['currency']),
      bundleReferences: _string(json['bundle_references']),
    );
  }
```

Add the import at the top of the mapper:

```dart
import 'package:safaria/features/flight/domain/entities/flight_bundle.dart';
```

- [ ] **Step 5: Run codegen and the test**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/features/flight/data/flight_bundle_mapper_test.dart`
Expected: PASS — 3 tests.

- [ ] **Step 6: Replace the stale note in the API layer**

In `lib/features/flight/data/flight_api.dart`, replace the `bundles` doc comment with:

```dart
  /// `GET /flights/{offer_id}/bundles`.
  ///
  /// Must be called with the offer id returned by **confirm**, not the one
  /// from search. Passing the searched id is what produces
  /// `400 "offer id is not valid or expired"` — the errors recorded here
  /// previously were that mistake, not a broken endpoint.
```

- [ ] **Step 7: Commit**

```bash
git add lib/features/flight/domain/entities/flight_bundle.dart lib/features/flight/data test/features/flight/data/flight_bundle_mapper_test.dart
git commit -m "Map Flight Bundles From Both Price Shapes"
```

---

## Task 7: Bundle pricing rules

**Blocked on Task 1 step 4 confirming the price shape.**

**Files:**
- Create: `lib/features/flight/domain/utils/flight_bundle_pricing.dart`
- Test: `test/features/flight/domain/flight_bundle_pricing_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_bundle.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/utils/flight_bundle_pricing.dart';

const _adultOnly = FlightBundle(
  code: 'RCAI',
  name: 'Light',
  prices: [FlightBundlePrice(passengerTypeCode: 'ADT', totalAmount: 250)],
);

const _perType = FlightBundle(
  code: 'VCAI',
  name: 'Flex',
  prices: [
    FlightBundlePrice(passengerTypeCode: 'ADT', totalAmount: 250),
    FlightBundlePrice(passengerTypeCode: 'CHD', totalAmount: 125),
  ],
);

void main() {
  test('a per-type bundle charges each type its own rate', () {
    const counts = FlightPassengerCounts(adults: 2, children: 1);
    expect(flightBundleDelta(_perType, counts), 625);
  });

  test('infants are free unless priced explicitly', () {
    const counts = FlightPassengerCounts(adults: 1, infants: 1);
    expect(flightBundleDelta(_perType, counts), 250);
  });

  test('an adult-only price applies to children too', () {
    const counts = FlightPassengerCounts(adults: 2, children: 1);
    expect(flightBundleDelta(_adultOnly, counts), 750);
  });

  test('a bundle with no prices is free', () {
    const bundle = FlightBundle(code: 'X', name: 'Basic', prices: []);
    expect(flightBundleDelta(bundle, const FlightPassengerCounts()), 0);
  });

  test('the running total adds every selected leg to the confirmed fare', () {
    final total = flightBundlesTotal(
      baseAmount: 10000,
      selected: [_perType, _adultOnly],
      counts: const FlightPassengerCounts(adults: 2, children: 1),
    );
    expect(total, 10000 + 625 + 750);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight/domain/flight_bundle_pricing_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Write the implementation**

Create `lib/features/flight/domain/utils/flight_bundle_pricing.dart`:

```dart
import 'package:safaria/features/flight/domain/entities/flight_bundle.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';

/// What adding [bundle] costs for the whole party.
///
/// Prices are treated as **per passenger** and multiplied by the head count
/// of their type. When a type in the party has no price of its own, the adult
/// price applies — providers that quote a single `ADT` figure mean it for
/// everyone travelling on a seat. Infants get nothing unless priced
/// explicitly, since they occupy no seat and carry no baggage allowance.
double flightBundleDelta(FlightBundle bundle, FlightPassengerCounts counts) {
  if (bundle.prices.isEmpty) return 0;

  double rateFor(String code) {
    for (final price in bundle.prices) {
      if (price.passengerTypeCode == code) return price.totalAmount;
    }
    return 0;
  }

  final adultRate = rateFor('ADT');
  final childRate = _hasPriceFor(bundle, 'CHD') ? rateFor('CHD') : adultRate;
  final infantRate = _hasPriceFor(bundle, 'INF') ? rateFor('INF') : 0.0;

  return adultRate * counts.adults +
      childRate * counts.children +
      infantRate * counts.infants;
}

bool _hasPriceFor(FlightBundle bundle, String code) =>
    bundle.prices.any((price) => price.passengerTypeCode == code);

/// Confirmed fare plus every chosen bundle, one per leg.
double flightBundlesTotal({
  required double baseAmount,
  required List<FlightBundle> selected,
  required FlightPassengerCounts counts,
}) {
  return selected.fold<double>(
    baseAmount,
    (sum, bundle) => sum + flightBundleDelta(bundle, counts),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/flight/domain/flight_bundle_pricing_test.dart`
Expected: PASS — 5 tests.

- [ ] **Step 5: Reconcile with what Task 1 observed**

If Task 1 step 4 showed a single `bundle_prices` object that is a **party total** rather than a per-passenger rate, change `flightBundleDelta` to return the raw amount once, and update the doc comment and the third test. Do not leave the two readings in the code at once.

- [ ] **Step 6: Commit**

```bash
git add lib/features/flight/domain/utils/flight_bundle_pricing.dart test/features/flight/domain/flight_bundle_pricing_test.dart
git commit -m "Price Flight Bundles Across Passenger Types"
```

---

## Task 8: The bundles screen

**Blocked on Tasks 6 and 7.**

**Files:**
- Create: `lib/features/flight/presentation/widgets/flight_bundle_card.dart`
- Create: `lib/features/flight/presentation/flight_bundles_screen.dart`
- Modify: `lib/features/flight/domain/repositories/flight_repository.dart`
- Modify: `lib/features/flight/data/flight_repository_impl.dart`
- Modify: `lib/features/flight/presentation/providers/flight_booking_providers.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`

- [ ] **Step 1: Add the repository method**

In `lib/features/flight/domain/repositories/flight_repository.dart`:

```dart
  /// Fare bundles for a confirmed offer.
  ///
  /// [offerId] must be the id returned by [confirmOrder], not the one from
  /// [search].
  Future<List<FlightJourneyBundles>> bundles(String offerId);
```

In `lib/features/flight/data/flight_repository_impl.dart`:

```dart
  @override
  Future<List<FlightJourneyBundles>> bundles(String offerId) {
    return _guard(() async {
      final body = await _api.bundles(offerId);
      return FlightDtoMapper.journeyBundlesFromEnvelope(body);
    });
  }
```

Also replace the stale warning above `confirmOrder` in the repository interface. Confirm is what secures the trip; the previous note called it possibly stubbed, which the flow spec has since settled:

```dart
  /// Re-prices and secures a searched offer, returning a **new offer id**
  /// that every later call must use. See the offer id relay in
  /// `docs/superpowers/specs/2026-08-08-flight-booking-flow-design.md`.
  Future<FlightConfirmedOrder> confirmOrder(String offerId);
```

Make the same correction to the `FlightConfirmedOrder` doc comment in `lib/features/flight/domain/entities/flight_confirmed_order.dart`.

- [ ] **Step 2: Add the notifier action**

```dart
  Future<void> loadBundles() async {
    final offerId = state.activeOfferId;
    if (offerId == null || state.confirmedOrder == null) return;
    state = state.copyWith(
      status: FlightBookingStatus.loadingBundles,
      error: null,
    );
    try {
      final bundles = await _repo.bundles(offerId);
      state = state.copyWith(
        status: FlightBookingStatus.idle,
        journeyBundles: bundles,
      );
    } catch (e) {
      state = state.copyWith(
        status: FlightBookingStatus.error,
        error: e.toString(),
      );
    }
  }

  void selectBundle({required String journeyId, required String bundleCode}) {
    state = state.copyWith(
      selectedBundleCodes: {
        ...state.selectedBundleCodes,
        journeyId: bundleCode,
      },
    );
  }
```

- [ ] **Step 3: Add the strings**

In `lib/l10n/app_en.arb`:

```json
  "flightBundlesTitle": "Choose your bundle",
  "flightBundleIncluded": "Included",
  "flightBundleLeg": "Leg {number}",
  "flightBundleChooseAll": "Choose a bundle for every leg",
  "@flightBundleLeg": { "placeholders": { "number": {"type": "int"} } },
```

In `lib/l10n/app_ar.arb`:

```json
  "flightBundlesTitle": "اختر الحزمة",
  "flightBundleIncluded": "مشمولة",
  "flightBundleLeg": "المسار {number}",
  "flightBundleChooseAll": "اختر حزمة لكل مسار",
```

- [ ] **Step 4: Write the bundle card**

Create `lib/features/flight/presentation/widgets/flight_bundle_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_bundle.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// One selectable bundle. A zero delta reads as "included" rather than
/// "+ 0" — the rider is picking what they get, not paying nothing.
class FlightBundleCard extends StatelessWidget {
  const FlightBundleCard({
    super.key,
    required this.bundle,
    required this.delta,
    required this.currency,
    required this.isSelected,
    required this.onTap,
  });

  final FlightBundle bundle;
  final double delta;
  final String currency;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryTint : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.hairline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(bundle.name, style: AppTypography.body),
                Text(
                  delta == 0
                      ? l10n.flightBundleIncluded
                      : '+ ${delta.toStringAsFixed(0)} $currency',
                  style: AppTypography.body.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            for (final service in bundle.includedServices) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    PhosphorIconsLight.check,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      service,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

`AppColors.primaryTint` is the existing filled-state tint (`0xFFE8F0FE`) — the same one the OTP boxes use.

- [ ] **Step 5: Write the bundles screen**

Create `lib/features/flight/presentation/flight_bundles_screen.dart`. One section per leg; a leg collapses to a summary row once chosen, which is what keeps a five-leg itinerary readable.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/domain/entities/flight_bundle.dart';
import 'package:safaria/features/flight/domain/entities/flight_wizard_step.dart';
import 'package:safaria/features/flight/domain/utils/flight_bundle_pricing.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_booking_step_bar.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_bundle_card.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Wizard step 2, shown only when the offer has bundles.
class FlightBundlesScreen extends ConsumerStatefulWidget {
  const FlightBundlesScreen({super.key});

  @override
  ConsumerState<FlightBundlesScreen> createState() =>
      _FlightBundlesScreenState();
}

class _FlightBundlesScreenState extends ConsumerState<FlightBundlesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(flightBookingProvider.notifier).loadBundles();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(flightBookingProvider);
    final confirmed = state.confirmedOrder;

    if (confirmed == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(FlightRoutes.results);
      });
      return const SizedBox.shrink();
    }

    final counts = flightPassengerCountsOf(state.searchParams);
    final selected = <FlightBundle>[];
    for (final journey in state.journeyBundles) {
      final code = state.selectedBundleCodes[journey.offerJourneyId];
      for (final bundle in journey.bundles) {
        if (bundle.code == code) selected.add(bundle);
      }
    }
    final allChosen = state.journeyBundles.isNotEmpty &&
        selected.length == state.journeyBundles.length;

    final total = flightBundlesTotal(
      baseAmount: confirmed.priceDetails.totalAmount,
      selected: selected,
      counts: counts,
    );

    return Scaffold(
      appBar: BookingAppBar(title: l10n.flightBundlesTitle),
      body: Column(
        children: [
          const FlightBookingStepBar(
            current: FlightWizardStep.bundles,
            haveBundles: true,
          ),
          if (state.status == FlightBookingStatus.loadingBundles)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  for (var i = 0; i < state.journeyBundles.length; i++)
                    _JourneySection(
                      index: i,
                      journey: state.journeyBundles[i],
                      counts: counts,
                      currency: confirmed.priceDetails.currency,
                      selectedCode: state
                          .selectedBundleCodes[
                              state.journeyBundles[i].offerJourneyId],
                      onSelect: (code) => ref
                          .read(flightBookingProvider.notifier)
                          .selectBundle(
                            journeyId: state.journeyBundles[i].offerJourneyId,
                            bundleCode: code,
                          ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.flightPriceTotal, style: AppTypography.body),
                    Text(
                      '${total.toStringAsFixed(0)} '
                      '${confirmed.priceDetails.currency}',
                      style: AppTypography.h2,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: allChosen
                      ? l10n.flightContinue
                      : l10n.flightBundleChooseAll,
                  onPressed: allChosen
                      ? () => context.push(FlightRoutes.results)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

The continue action points at results until Phase 3 adds the passengers route.

Add `_JourneySection` to the same file. Collapsing a chosen leg to one line is what keeps a five-leg itinerary readable — and it collapses without discarding the choice, so reopening it shows the current selection rather than a blank list:

```dart
class _JourneySection extends StatefulWidget {
  const _JourneySection({
    required this.index,
    required this.journey,
    required this.counts,
    required this.currency,
    required this.selectedCode,
    required this.onSelect,
  });

  final int index;
  final FlightJourneyBundles journey;
  final FlightPassengerCounts counts;
  final String currency;
  final String? selectedCode;
  final ValueChanged<String> onSelect;

  @override
  State<_JourneySection> createState() => _JourneySectionState();
}

class _JourneySectionState extends State<_JourneySection> {
  bool _expanded = false;

  bool get _isCollapsed => widget.selectedCode != null && !_expanded;

  FlightBundle? get _selected {
    for (final bundle in widget.journey.bundles) {
      if (bundle.code == widget.selectedCode) return bundle;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = _selected;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              l10n.flightBundleLeg(widget.index + 1),
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          if (_isCollapsed && selected != null)
            InkWell(
              onTap: () => setState(() => _expanded = true),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    const Icon(
                      PhosphorIconsLight.checkCircle,
                      size: 18,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(selected.name, style: AppTypography.body),
                    ),
                    const Icon(
                      PhosphorIconsLight.caretDown,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            )
          else
            for (final bundle in widget.journey.bundles)
              FlightBundleCard(
                bundle: bundle,
                delta: flightBundleDelta(bundle, widget.counts),
                currency: widget.currency,
                isSelected: bundle.code == widget.selectedCode,
                onTap: () {
                  widget.onSelect(bundle.code);
                  setState(() => _expanded = false);
                },
              ),
        ],
      ),
    );
  }
}
```

Add the icon import to the screen file:

```dart
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
```

Add `flightPassengerCountsOf` to `lib/features/flight/domain/utils/flight_passenger_rules.dart` — the inverse of `toWirePassengers`:

```dart
/// Rebuilds the UI-side counts from the wire list held in search params.
FlightPassengerCounts flightPassengerCountsOf(FlightSearchParams? params) {
  if (params == null) return const FlightPassengerCounts();
  var counts = const FlightPassengerCounts(adults: 0);
  for (final passenger in params.passengers) {
    counts = switch (passenger.passengerTypeCode) {
      'CHD' => counts.copyWith(children: passenger.count),
      'INF' => counts.copyWith(infants: passenger.count),
      _ => counts.copyWith(adults: passenger.count),
    };
  }
  return counts;
}
```

- [ ] **Step 6: Register the bundles route**

Add the `GoRoute` from Task 5 step 4 now that the screen exists.

- [ ] **Step 7: Analyze and commit**

Run: `flutter gen-l10n && flutter analyze lib/features/flight && flutter test`
Expected: no analyzer issues; all tests pass.

```bash
git add lib/features/flight lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "Add Flight Bundle Selection Step"
```

---

## Task 9: Enter the wizard from results

**Files:**
- Modify: `lib/features/flight/presentation/widgets/flight_offer_card.dart`
- Modify: `lib/features/flight/presentation/flight_offer_details_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`

- [ ] **Step 1: Add the details action string**

In `lib/l10n/app_en.arb`: `"flightViewDetails": "Details",`
In `lib/l10n/app_ar.arb`: `"flightViewDetails": "التفاصيل",`

- [ ] **Step 2: Give the card two actions**

`FlightOfferCard` currently takes a single `onTap` that opens the details preview. Add a second callback so the card can also enter the wizard directly:

```dart
  /// Opens the read-only preview. No network call, no commitment — a rider
  /// can compare several offers in detail without burning confirm calls.
  final VoidCallback onTap;

  /// Enters the booking wizard, which confirms the offer.
  final VoidCallback onSelect;
```

Keep `onTap` on the card body. In the fare stub — the section below the tear line that already shows the price — put the two actions side by side:

```dart
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onTap,
                  child: Text(
                    l10n.flightViewDetails,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                PrimaryButton(
                  label: l10n.flightSelectThisFlight,
                  compact: true,
                  onPressed: onSelect,
                ),
              ],
            ),
```

`PrimaryButton` already takes `compact` — it is the shorter in-card size used elsewhere in the app.

- [ ] **Step 3: Wire both from the results screen**

In `flight_results_screen.dart`'s `itemBuilder`:

```dart
            onTap: () => context.push(FlightRoutes.offerDetails, extra: offer),
            onSelect: () {
              ref.read(flightBookingProvider.notifier).selectOffer(offer);
              context.push(FlightRoutes.review);
            },
```

- [ ] **Step 4: Replace the coming-soon snackbar**

In `flight_offer_details_screen.dart`, the `flightSelectThisFlight` button currently shows `l10n.flightBookingComingSoon`. Convert the screen to a `ConsumerWidget` and replace the handler with the same two lines as step 3. Remove the now-unused `flightBookingComingSoon` key from both ARB files.

- [ ] **Step 5: Verify the whole flow**

Run: `flutter gen-l10n && flutter analyze && flutter test`
Expected: no analyzer issues; all tests pass.

Run: `flutter run`. Search, tap Details on an offer and confirm nothing loads. Go back, tap Select, and confirm the review screen shows a spinner then the confirmed fare. For an offer with `haveBundles` true, confirm the step bar shows four nodes and Continue reaches the bundle step; for one without, confirm it shows three.

- [ ] **Step 6: Commit**

```bash
git add lib/features/flight lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "Enter Flight Booking Wizard From Results"
```

---

## Done when

- [ ] `flutter analyze` is clean and `flutter test` passes
- [ ] Bundles returns a real payload using the confirmed offer id, and the fixture is committed
- [ ] The step bar shows three nodes for an offer without bundles and four with
- [ ] A re-priced offer shows both amounts and an acceptance-worded button
- [ ] Opening `/flight/review` with no selected offer bounces to results
- [ ] The stale notes on `confirmOrder`, `FlightConfirmedOrder`, and `bundles` are replaced
