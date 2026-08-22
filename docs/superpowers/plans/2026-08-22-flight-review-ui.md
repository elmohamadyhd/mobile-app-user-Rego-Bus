# Flight Review Page UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the flight Review wizard step match the results ticket’s language: full airport names, Outbound/Return/Flight-n pills, readable contrast, unique fare rules, and a fare-breakdown card instead of a second Total.

**Architecture:** Reuse `flightJourneyAirportLabels` (already on results). Lift the private `_LegBadge` / `_LegKind` out of `FlightOfferCard` into a public `FlightLegBadge` so Review can share it. Deduplicate fare-rule strings in a pure helper. Keep Review cards compact — do not clone the notched boarding-pass.

**Tech Stack:** Flutter, Riverpod, ARB/`flutter gen-l10n`, `flutter_test`.

## Global Constraints

- Package imports (`package:safaria/...`), never relative across directories.
- User-facing strings in both `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb`; then `flutter gen-l10n`.
- Colors/spacing/type from `AppColors` / `AppSpacing` / `AppTypography` / `AppRadius` — no hex in widgets.
- Directional insets (`EdgeInsetsDirectional`); Phosphor Light icons; wrap non-directional Phosphor glyphs in `LtrIcon`.
- No notched `FlightTicketBorder` on Review. No stepper/footer redesign. Do not change `flightAddLeg` copy in this plan.
- Line length 80; trailing commas; `dart format` on touched files.
- Do not edit `*.g.dart` / generated `app_localizations*.dart`.

---

## File Structure

**Create:**

| File | Responsibility |
|------|----------------|
| `lib/features/flight/domain/utils/flight_fare_rules.dart` | Deduplicate fare-rule strings |
| `lib/features/flight/presentation/widgets/flight_leg_badge.dart` | Shared Outbound/Return/Flight-n pill + kind/label helpers |
| `test/features/flight/domain/utils/flight_fare_rules_test.dart` | Unique-rules unit tests |
| `test/features/flight/presentation/flight_trip_summary_card_test.dart` | Review card widget tests |

**Modify:**

| File | Change |
|------|--------|
| `lib/l10n/app_en.arb` | `flightLegLabel` → `Flight {number}`; `flightBundleLeg`; add `flightFareBreakdown` |
| `lib/l10n/app_ar.arb` | `flightLegLabel` → `رحلة {number}`; `flightBundleLeg`; add `flightFareBreakdown` |
| `lib/features/flight/presentation/widgets/flight_offer_card.dart` | Use public `FlightLegBadge` / `FlightLegKind` |
| `lib/features/flight/presentation/widgets/flight_trip_summary_card.dart` | Names, pill, `RouteArrowLabel`, contrast |
| `lib/features/flight/presentation/flight_review_screen.dart` | Pass labels; unique rules; breakdown card; banner padding |
| `test/features/flight/presentation/flight_offer_card_test.dart` | Multi-city still finds numbered pill text (`Flight 2` after gen-l10n) |

---

### Task 1: Unique fare-rule helper

**Files:**
- Create: `lib/features/flight/domain/utils/flight_fare_rules.dart`
- Test: `test/features/flight/domain/utils/flight_fare_rules_test.dart`

**Interfaces:**
- Consumes: `FlightPriceClass.rulesAndPenalties`
- Produces: `List<String> uniqueFlightFareRules(Iterable<FlightPriceClass> priceClasses)`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/utils/flight_fare_rules.dart';

void main() {
  test('drops duplicate and blank fare rules, keeps first order', () {
    const classes = [
      FlightPriceClass(
        classId: 'a',
        priceClassName: 'Optima',
        fareType: 'PUBLIC',
        rulesAndPenalties: ['Optima', 'Optima', '  '],
      ),
      FlightPriceClass(
        classId: 'b',
        priceClassName: 'Optima',
        fareType: 'PUBLIC',
        rulesAndPenalties: ['Optima', 'Non-refundable'],
      ),
    ];

    expect(uniqueFlightFareRules(classes), ['Optima', 'Non-refundable']);
  });

  test('returns empty when every class has no rules', () {
    const classes = [
      FlightPriceClass(
        classId: 'a',
        priceClassName: 'Optima',
        fareType: 'PUBLIC',
      ),
    ];
    expect(uniqueFlightFareRules(classes), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight/domain/utils/flight_fare_rules_test.dart`

Expected: FAIL — `flight_fare_rules.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';

/// First-seen unique fare-rule lines from [priceClasses].
///
/// Search payloads often repeat the class name (e.g. three "Optima"
/// bullets). Review should not look like a broken list.
List<String> uniqueFlightFareRules(
  Iterable<FlightPriceClass> priceClasses,
) {
  final seen = <String>{};
  final out = <String>[];
  for (final priceClass in priceClasses) {
    for (final rule in priceClass.rulesAndPenalties ?? const <String>[]) {
      final trimmed = rule.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) continue;
      out.add(trimmed);
    }
  }
  return out;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/flight/domain/utils/flight_fare_rules_test.dart`

Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/flight/domain/utils/flight_fare_rules.dart test/features/flight/domain/utils/flight_fare_rules_test.dart
git commit -m "$(cat <<'EOF'
Add unique fare-rule helper for the flight Review list.

EOF
)"
```

On Windows PowerShell, pass the message as a single `-m` string instead of a heredoc.

---

### Task 2: Copy — Flight n / رحلة n and fare-breakdown heading

**Files:**
- Modify: `lib/l10n/app_en.arb` (`flightLegLabel`, `flightBundleLeg`, add `flightFareBreakdown`)
- Modify: `lib/l10n/app_ar.arb` (same keys)

**Interfaces:**
- Consumes: existing `flightLegLabel(int number)` callers
- Produces: new strings after `flutter gen-l10n` — `flightFareBreakdown`

- [ ] **Step 1: Change English ARB**

In `lib/l10n/app_en.arb`, replace the `flightLegLabel` block with:

```json
  "flightLegLabel": "Flight {number}",
  "@flightLegLabel": {
    "description": "Numbered hop on a multi-city itinerary (results, review, search form).",
    "placeholders": {
      "number": {"type": "int"}
    }
  },
```

Replace `"flightBundleLeg": "Leg {number}"` with `"flightBundleLeg": "Flight {number}"`.

Immediately after the `flightFareRules` `@` block, add:

```json
  "flightFareBreakdown": "Fare breakdown",
  "@flightFareBreakdown": {
    "description": "Heading on the Review fare card. The sticky footer still shows Total."
  },
```

Keep valid JSON commas.

- [ ] **Step 2: Change Arabic ARB**

In `lib/l10n/app_ar.arb`:

- `"flightLegLabel": "رحلة {number}"`
- `"flightBundleLeg": "رحلة {number}"`
- `"flightFareBreakdown": "تفاصيل السعر"`

- [ ] **Step 3: Generate localizations**

Run: `flutter gen-l10n`

Expected: succeeds; `AppLocalizations` gains `flightFareBreakdown`.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "$(cat <<'EOF'
Rename multi-city hop copy from Leg to Flight.

EOF
)"
```

---

### Task 3: Lift `FlightLegBadge` out of the offer card

**Files:**
- Create: `lib/features/flight/presentation/widgets/flight_leg_badge.dart`
- Modify: `lib/features/flight/presentation/widgets/flight_offer_card.dart` (delete private enum/badge; call the public API)
- Test: existing `test/features/flight/presentation/flight_offer_card_test.dart` (must still pass; round-trip still finds Outbound/Return + takeoff/landing icons)

**Interfaces:**
- Consumes: `AppLocalizations.flightLegOutbound` / `flightLegReturn` / `flightLegLabel`
- Produces:
  - `enum FlightLegKind { outbound, returning, numbered }`
  - `FlightLegKind? flightJourneyBadgeKind({required int index, required int total})`
  - `String? flightJourneyBadgeLabel(AppLocalizations l10n, {required int index, required int total})`
  - `class FlightLegBadge extends StatelessWidget` with `label` + `kind`

- [ ] **Step 1: Add the public widget file**

```dart
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/ltr_icon.dart';

enum FlightLegKind { outbound, returning, numbered }

/// Null for a one-way offer (a pill would be noise).
FlightLegKind? flightJourneyBadgeKind({
  required int index,
  required int total,
}) {
  if (total < 2) return null;
  if (total == 2) {
    return index == 0 ? FlightLegKind.outbound : FlightLegKind.returning;
  }
  return FlightLegKind.numbered;
}

String? flightJourneyBadgeLabel(
  AppLocalizations l10n, {
  required int index,
  required int total,
}) {
  if (total < 2) return null;
  if (total == 2) {
    return index == 0 ? l10n.flightLegOutbound : l10n.flightLegReturn;
  }
  return l10n.flightLegLabel(index + 1);
}

/// Compact section mark. Blue outbound, amber return, neutral numbered.
class FlightLegBadge extends StatelessWidget {
  const FlightLegBadge({
    super.key,
    required this.label,
    required this.kind,
  });

  final String label;
  final FlightLegKind kind;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon) = switch (kind) {
      FlightLegKind.outbound => (
          AppColors.primaryTint,
          AppColors.primary,
          PhosphorIconsLight.airplaneTakeoff,
        ),
      FlightLegKind.returning => (
          AppColors.secondaryTint,
          AppColors.secondaryDeep,
          PhosphorIconsLight.airplaneLanding,
        ),
      FlightLegKind.numbered => (
          AppColors.inputFill,
          AppColors.textSecondary,
          PhosphorIconsLight.airplane,
        ),
    };

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LtrIcon(icon, size: 12, color: fg),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Point the offer card at the public API**

In `flight_offer_card.dart`:

- Add `import 'package:safaria/features/flight/presentation/widgets/flight_leg_badge.dart';`
- Delete `_legLabel`, `_legKind`, `enum _LegKind`, and `class _LegBadge`.
- In `_journeyBlocks`, pass:

```dart
label: flightJourneyBadgeLabel(
  l10n,
  index: i,
  total: offer.journeys.length,
),
kind: flightJourneyBadgeKind(
  index: i,
  total: offer.journeys.length,
),
```

- Change `_JourneyBlock.kind` type from `_LegKind?` to `FlightLegKind?`.
- Replace `_LegBadge(...)` with `FlightLegBadge(label: label!, kind: kind!)`.

- [ ] **Step 3: Run offer-card tests**

Run: `flutter test test/features/flight/presentation/flight_offer_card_test.dart`

Expected: PASS. Round-trip still finds `Outbound` / `Return` and takeoff/landing icons.

- [ ] **Step 4: Commit**

```bash
git add lib/features/flight/presentation/widgets/flight_leg_badge.dart lib/features/flight/presentation/widgets/flight_offer_card.dart
git commit -m "$(cat <<'EOF'
Share the flight hop pill between results and Review.

EOF
)"
```

---

### Task 4: Review journey card — names, pill, route arrow

**Files:**
- Modify: `lib/features/flight/presentation/widgets/flight_trip_summary_card.dart`
- Test: `test/features/flight/presentation/flight_trip_summary_card_test.dart`

**Interfaces:**
- Consumes: `FlightLegBadge`, `FlightLegKind`, `RouteArrowLabel`
- Produces: `FlightTripSummaryCard({ required FlightJourney journey, String? originLabel, String? destinationLabel, String? legLabel, FlightLegKind? legKind })`

- [ ] **Step 1: Write the failing widget tests**

Create `test/features/flight/presentation/flight_trip_summary_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_leg_badge.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_trip_summary_card.dart';
import 'package:safaria/l10n/app_localizations.dart';

FlightJourney _journey() {
  return FlightJourney(
    id: 'j1',
    origin: 'CDG',
    destination: 'CAI',
    numberOfStops: 1,
    segments: [
      FlightSegment(
        id: 's1',
        origin: 'CDG',
        destination: 'CAI',
        departureDateTime: DateTime(2026, 9, 3, 9),
        arrivalDateTime: DateTime(2026, 9, 3, 23, 45),
        flightTimeInMinutes: 315,
        operatingCarrierCode: 'OS',
        operatingFlightNumber: '1',
        marketingCarrierCode: 'OS',
        marketingFlightNumber: '1',
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: FlightTripSummaryCard(
          journey: _journey(),
          originLabel: 'All Airport',
          destinationLabel: 'Cairo Intl Airport',
          legLabel: 'Return',
          legKind: FlightLegKind.returning,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows airport names instead of raw IATA', (tester) async {
    await _pump(tester);
    expect(find.text('All Airport'), findsOneWidget);
    expect(find.text('Cairo Intl Airport'), findsOneWidget);
    expect(find.text('CDG'), findsNothing);
    expect(find.text('CAI'), findsNothing);
    expect(find.text('09:00 – 23:45'), findsOneWidget);
    expect(find.textContaining('1 stop'), findsOneWidget);
  });

  testWidgets('return pill uses landing icon and amber treatment',
      (tester) async {
    await _pump(tester);
    expect(find.text('Return'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.airplaneLanding), findsOneWidget);
  });

  testWidgets('airport names use primary text', (tester) async {
    await _pump(tester);
    final origin = tester.widget<Text>(find.text('All Airport'));
    expect(origin.style?.color, AppColors.textPrimary);
  });
}
```

Time string must match the card’s formatter (`09:00` not `9:00`). If the card uses an en-dash `–` (U+2013) keep it consistent in the test.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/flight/presentation/flight_trip_summary_card_test.dart`

Expected: FAIL — card still renders `CDG → CAI` and has no `legKind`.

- [ ] **Step 3: Implement the card**

Replace `flight_trip_summary_card.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_leg_badge.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/ltr_text.dart';
import 'package:safaria/shared/widgets/route_arrow_label.dart';

/// Compact one-journey summary for the Review step.
class FlightTripSummaryCard extends StatelessWidget {
  const FlightTripSummaryCard({
    super.key,
    required this.journey,
    this.originLabel,
    this.destinationLabel,
    this.legLabel,
    this.legKind,
  });

  final FlightJourney journey;
  final String? originLabel;
  final String? destinationLabel;
  final String? legLabel;
  final FlightLegKind? legKind;

  static String _time(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _place(String? name, String iataCode) {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return iataCode;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final first = journey.segments.first;
    final last = journey.segments.last;
    final dateText = DateFormat.MMMd(locale).format(first.departureDateTime);
    final stopsText = journey.numberOfStops == 0
        ? l10n.flightDirect
        : journey.numberOfStops == 1
            ? l10n.flightOneStop
            : l10n.flightStopsCount(journey.numberOfStops);
    final origin = _place(originLabel, journey.origin);
    final destination = _place(destinationLabel, journey.destination);
    final placeStyle = AppTypography.caption.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (legLabel != null && legKind != null) ...[
            FlightLegBadge(label: legLabel!, kind: legKind!),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RouteArrowLabel(
                  from: origin,
                  to: destination,
                  maxLines: 2,
                  style: placeStyle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                dateText,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              LtrText(
                '${_time(first.departureDateTime)} – '
                '${_time(last.arrivalDateTime)}',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '· $stopsText',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

`RouteArrowLabel` uses `Flexible` inside a `Row` with `mainAxisSize: min`. Nested in an `Expanded`, that can throw. If tests overflow, wrap the label in `Align(alignment: AlignmentDirectional.centerStart, child: RouteArrowLabel(...))` **or** drop `RouteArrowLabel` and use a full-width `Row` of two `Expanded` `Text`s plus a mirrored `PhosphorIconsLight.caretRight` (same pattern as `RouteArrowLabel`, but `Expanded` not `Flexible`). Prefer the overflow-safe `Expanded` row if `RouteArrowLabel` overflows.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/flight/presentation/flight_trip_summary_card_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/flight/presentation/widgets/flight_trip_summary_card.dart test/features/flight/presentation/flight_trip_summary_card_test.dart
git commit -m "$(cat <<'EOF'
Show full airport names on the flight Review hop card.

EOF
)"
```

---

### Task 5: Wire Review screen — labels, unique rules, breakdown card, banner

**Files:**
- Modify: `lib/features/flight/presentation/flight_review_screen.dart`

**Interfaces:**
- Consumes: `flightJourneyAirportLabels`, `uniqueFlightFareRules`, `flightJourneyBadgeKind` / `flightJourneyBadgeLabel`, `state.searchFromLabel` / `searchToLabel` / `searchAirportNames` / `searchParams`
- Produces: Review list with named hops, unique rules, fare-breakdown card (no second Total heading)

- [ ] **Step 1: Update imports**

Add:

```dart
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
import 'package:safaria/features/flight/domain/utils/flight_airport_labels.dart';
import 'package:safaria/features/flight/domain/utils/flight_fare_rules.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_leg_badge.dart';
```

Remove the local `_legLabel` method.

- [ ] **Step 2: Pass names and pill into each summary card**

Replace the journey loop with:

```dart
for (var i = 0; i < offer.journeys.length; i++) ...[
  Builder(
    builder: (context) {
      final labels = flightJourneyAirportLabels(
        index: i,
        journey: offer.journeys[i],
        tripType:
            state.searchParams?.tripType ?? FlightTripType.oneWay,
        searchLegs: state.searchParams?.legs ?? const [],
        namesByIata: state.searchAirportNames,
        searchFromLabel: state.searchFromLabel,
        searchToLabel: state.searchToLabel,
      );
      return FlightTripSummaryCard(
        key: ValueKey(offer.journeys[i].id),
        journey: offer.journeys[i],
        originLabel: labels.origin,
        destinationLabel: labels.destination,
        legLabel: flightJourneyBadgeLabel(
          l10n,
          index: i,
          total: offer.journeys.length,
        ),
        legKind: flightJourneyBadgeKind(
          index: i,
          total: offer.journeys.length,
        ),
      );
    },
  ),
],
```

Do **not** leave a `Builder` if you can compute `labels` in the loop without it — `itemBuilder`-style is fine inside the existing `ListView` `children:` using a local function on the State class:

```dart
List<Widget> _journeyCards(
  AppLocalizations l10n,
  FlightBookingState state,
  FlightOffer offer,
) {
  return [
    for (var i = 0; i < offer.journeys.length; i++)
      FlightTripSummaryCard(
        key: ValueKey(offer.journeys[i].id),
        journey: offer.journeys[i],
        originLabel: flightJourneyAirportLabels(
          index: i,
          journey: offer.journeys[i],
          tripType: state.searchParams?.tripType ?? FlightTripType.oneWay,
          searchLegs: state.searchParams?.legs ?? const [],
          namesByIata: state.searchAirportNames,
          searchFromLabel: state.searchFromLabel,
          searchToLabel: state.searchToLabel,
        ).origin,
        destinationLabel: flightJourneyAirportLabels(
          index: i,
          journey: offer.journeys[i],
          tripType: state.searchParams?.tripType ?? FlightTripType.oneWay,
          searchLegs: state.searchParams?.legs ?? const [],
          namesByIata: state.searchAirportNames,
          searchFromLabel: state.searchFromLabel,
          searchToLabel: state.searchToLabel,
        ).destination,
        legLabel: flightJourneyBadgeLabel(
          l10n,
          index: i,
          total: offer.journeys.length,
        ),
        legKind: flightJourneyBadgeKind(
          index: i,
          total: offer.journeys.length,
        ),
      ),
  ];
}
```

Call `flightJourneyAirportLabels` **once** per index (store in a local `final labels`).

- [ ] **Step 3: Unique fare rules + directional padding**

Replace `_fareRules` with:

```dart
  List<Widget> _fareRules(AppLocalizations l10n, FlightOffer offer) {
    final rules = uniqueFlightFareRules(offer.priceClasses);
    if (rules.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpacing.sm),
      Text(
        l10n.flightFareRules,
        style: AppTypography.title.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: AppSpacing.sm),
      for (final rule in rules)
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
          child: Text(
            '•  $rule',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
    ];
  }
```

- [ ] **Step 4: Fare breakdown card; drop duplicate Total heading**

Replace the block that starts with `Text(l10n.flightPriceTotal, ...)` through the discount `_FareRow` with:

```dart
const SizedBox(height: AppSpacing.sm),
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(AppSpacing.md),
  decoration: BoxDecoration(
    color: AppColors.bgElevated,
    borderRadius: BorderRadius.circular(AppRadius.card),
    border: Border.all(color: AppColors.hairline),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        l10n.flightFareBreakdown,
        style: AppTypography.title.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      for (final breakdown in confirmed.passengerFareBreakdown)
        _FareRow(
          label: _passengerLabel(l10n, breakdown),
          amount: breakdown.passengerTotalAmount,
          currency: confirmed.priceDetails.currency,
        ),
      _FareRow(
        label: l10n.flightPriceTaxes,
        amount: confirmed.priceDetails.taxesAmount,
        currency: confirmed.priceDetails.currency,
      ),
      if (confirmed.priceDetails.discountAmount > 0)
        _FareRow(
          label: l10n.flightPriceDiscount,
          amount: -confirmed.priceDetails.discountAmount,
          currency: confirmed.priceDetails.currency,
        ),
    ],
  ),
),
```

Leave `FlightWizardFooter` as the only Total + CTA.

- [ ] **Step 5: Banner — directional padding, keep amber**

In `_PriceChangeBanner`, change `margin` / `padding` to:

```dart
margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
padding: const EdgeInsets.all(AppSpacing.md),
```

Wrap the warning icon:

```dart
LtrIcon(
  PhosphorIconsLight.warning,
  size: 20,
  color: AppColors.secondaryDeep,
),
```

Add `import 'package:safaria/shared/widgets/ltr_icon.dart';`

Keep title `flightPriceChanged` at `w700` / `secondaryDeep`. Was→now line stays caption / `secondaryDeep` (a few EGP must not out-shout the flights).

- [ ] **Step 6: Format and analyze**

Run:

```bash
dart format lib/features/flight/presentation/flight_review_screen.dart lib/features/flight/presentation/widgets/flight_trip_summary_card.dart lib/features/flight/presentation/widgets/flight_leg_badge.dart lib/features/flight/presentation/widgets/flight_offer_card.dart lib/features/flight/domain/utils/flight_fare_rules.dart
flutter analyze lib/features/flight/presentation/flight_review_screen.dart lib/features/flight/presentation/widgets/flight_trip_summary_card.dart lib/features/flight/presentation/widgets/flight_leg_badge.dart lib/features/flight/presentation/widgets/flight_offer_card.dart
flutter test test/features/flight/domain/utils/flight_fare_rules_test.dart test/features/flight/presentation/flight_trip_summary_card_test.dart test/features/flight/presentation/flight_offer_card_test.dart
```

Expected: format clean, analyze **No issues found**, all listed tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/flight/presentation/flight_review_screen.dart
git commit -m "$(cat <<'EOF'
Align flight Review with named hops and a fare breakdown card.

EOF
)"
```

---

### Task 6: Manual check (no extra code)

- [ ] **Step 1: Round-trip Review**

Search a round trip, select an offer. Review must show Outbound (blue takeoff) and Return (amber landing) pills, full airport names on both hops, and Total only in the footer.

- [ ] **Step 2: Multi-city Review**

Three-city search. Pills read **Flight 1 / Flight 2 / Flight 3** (English) or **رحلة 1 / رحلة 2 / رحلة 3** (Arabic). No IATA-only route row when search names exist.

- [ ] **Step 3: Fare rules**

If the airline sent `Optima` three times, Review shows one bullet. If `rulesAndPenalties` is empty, the Fare rules heading is absent.

- [ ] **Step 4: RTL**

Pump or run under `ar`. Caret between airport names still means from→to. No `EdgeInsets.only(left/right)` on this screen.

---

## Self-review

- Journey names, pills, Flight-n copy, unique rules, breakdown card, banner padding, no second Total: Tasks 1–5.
- No boarding-pass clone, no stepper change: stated in Global Constraints.
- `flightJourneyAirportLabels` called once per hop in the implementer’s local helper (Task 5).
- `RouteArrowLabel` overflow fallback documented in Task 4.
