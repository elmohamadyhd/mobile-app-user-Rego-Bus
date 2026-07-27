# Car Results Soft-Browse Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign private-car quote results into Soft browse cards (layout A) on a clean list (S1): no selection chrome, no sticky Continue; card tap shows a localized “details coming soon” SnackBar.

**Architecture:** Presentation-only change in `features/car`. `CarTierCard` drops `selected` and gains a price + RTL-mirrored chevron footer. `CarTierResultsScreen` removes `_ContinueBar` and wires SnackBar on tap. Domain/API/notifier stay as-is (`selectQuote` unused by UI until a later details screen).

**Tech Stack:** Flutter, Riverpod, `flutter_test`, `intl` NumberFormat, ARB → `flutter gen-l10n`, Skyline tokens (`AppColors` / `AppSpacing` / `AppRadius` / `AppIcons` / `AppTypography`).

**Spec:** `docs/superpowers/specs/2026-07-27-car-results-soft-browse-redesign-design.md`

## Global Constraints

- Package imports only (`package:safaria/...`); never relative across directories.
- All user-visible strings via `AppLocalizations` — no hardcoded English/Arabic in widgets.
- Icons only through `AppIcons` — never raw `Icons.*`.
- Directional layout: `EdgeInsetsDirectional` / `AlignmentDirectional`; chevron RTL via `Transform.flip` like `auth_back_button.dart`.
- No new routes, no details screen, no booking API.
- Do **not** reuse `carBookingComingSoon` for card tap — add `carDetailsComingSoon`.
- Do **not** call `selectQuote` from results UI in this slice.
- Keep pull-to-refresh, loading skeleton, empty/error, guest 401 retry, `AppBreakpoints.maxContentWidth`.
- Run `dart format` on touched Dart files; `flutter gen-l10n` after ARB edits; `flutter analyze` on touched paths before each commit.

---

## Notes for the implementing engineer

- Package name is **`safaria`** (not `rego`).
- After ARB changes: `flutter gen-l10n` (codegen is gitignored).
- Prefer targeted tests per task; end with `flutter test test/features/car/`.
- `CarBookingNotifier.searchQuotes` currently auto-selects `quotes.first` — leave that notifier behavior alone; only remove selection from the UI.
- `carContinue` / `carSelectVehicleHint` may become unused on this screen — leave ARB keys in place (do not delete).

## File map

| File | Responsibility |
|------|----------------|
| `lib/l10n/app_en.arb` | Add `carDetailsComingSoon` + `@` metadata |
| `lib/l10n/app_ar.arb` | Arabic string for the same key |
| `lib/features/car/presentation/widgets/car_tier_card.dart` | Soft browse layout A; drop `selected` |
| `lib/features/car/presentation/car_tier_results_screen.dart` | Drop Continue bar; SnackBar on tap |
| `test/features/car/presentation/widgets/car_tier_card_test.dart` | Card assertions without selection mark |
| `test/features/car/presentation/car_tier_results_screen_test.dart` | No Continue; SnackBar on tap |

---

### Task 1: Localization — `carDetailsComingSoon`

**Files:**
- Modify: `lib/l10n/app_en.arb` (near other `car*` keys, after `carBookingComingSoon`)
- Modify: `lib/l10n/app_ar.arb` (near other `car*` keys)
- Produces: `AppLocalizations.carDetailsComingSoon` after `flutter gen-l10n`

**Interfaces:**
- Consumes: existing ARB / gen-l10n pipeline
- Produces: getter `String get carDetailsComingSoon` on `AppLocalizations`

- [ ] **Step 1: Add English key**

In `lib/l10n/app_en.arb`, immediately after the `carBookingComingSoon` / `@carBookingComingSoon` block, insert:

```json
  "carDetailsComingSoon": "Details coming soon",
  "@carDetailsComingSoon": {
    "description": "Snackbar when user taps a private-car quote card before the details screen ships."
  },
```

Keep valid JSON commas relative to the next key (`carSearchSelectBothPlaces`).

- [ ] **Step 2: Add Arabic key**

In `lib/l10n/app_ar.arb`, immediately after `"carBookingComingSoon": "الحجز قريباً",`, insert:

```json
  "carDetailsComingSoon": "التفاصيل قريباً",
```

- [ ] **Step 3: Generate localizations**

Run: `flutter gen-l10n`  
Expected: succeeds; generated `AppLocalizations` includes `carDetailsComingSoon`.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "feat(l10n): add carDetailsComingSoon for quote card tap"
```

---

### Task 2: Soft-browse `CarTierCard` (drop selection)

**Files:**
- Modify: `lib/features/car/presentation/widgets/car_tier_card.dart`
- Modify: `test/features/car/presentation/widgets/car_tier_card_test.dart`
- Test: `test/features/car/presentation/widgets/car_tier_card_test.dart`

**Interfaces:**
- Consumes: `CarTripQuote`, `AppLocalizations`, `AppIcons.forward`, Skyline tokens
- Produces:

```dart
class CarTierCard extends StatelessWidget {
  const CarTierCard({
    super.key,
    required this.quote,
    required this.rounded,
    required this.onTap,
  });

  final CarTripQuote quote;
  final bool rounded;
  final VoidCallback onTap;
}
```

(`selected` removed.)

- [ ] **Step 1: Write the failing tests**

Replace `test/features/car/presentation/widgets/car_tier_card_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/core/theme/app_icons.dart';
import 'package:safaria/features/car/presentation/widgets/car_tier_card.dart';
import 'package:safaria/l10n/app_localizations.dart';

import '../../fake_car_repository.dart';

void main() {
  testWidgets('shows company, price, seats chip, and forward chevron',
      (tester) async {
    const quote = FakeCarRepository.sampleQuote;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: CarTierCard(
            quote: quote,
            rounded: false,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Sky Travel'), findsOneWidget);
    expect(find.textContaining('69.87'), findsOneWidget);
    expect(find.text('Refundable'), findsOneWidget);
    expect(find.byIcon(AppIcons.check), findsNothing);
    expect(find.byIcon(AppIcons.forward), findsOneWidget);
    expect(find.byIcon(AppIcons.seats), findsOneWidget);
    expect(find.byIcon(AppIcons.luggage), findsOneWidget);
    expect(find.byIcon(AppIcons.gear), findsOneWidget);
  });

  testWidgets('tapping the card invokes onTap', (tester) async {
    var taps = 0;
    const quote = FakeCarRepository.sampleQuote;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: CarTierCard(
            quote: quote,
            rounded: false,
            onTap: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CarTierCard));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('renders under Arabic locale', (tester) async {
    const quote = FakeCarRepository.sampleQuote;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        home: Scaffold(
          body: CarTierCard(
            quote: quote,
            rounded: false,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Sky Travel'), findsOneWidget);
    expect(find.text('قابل للاسترداد'), findsOneWidget);
    expect(find.byIcon(AppIcons.forward), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/car/presentation/widgets/car_tier_card_test.dart`  
Expected: FAIL — `selected` still required and/or `AppIcons.check` still present / compile error on removed named arg.

- [ ] **Step 3: Implement Soft browse layout A**

Replace the contents of `lib/features/car/presentation/widgets/car_tier_card.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_icons.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/car/domain/entities/car_trip_quote.dart';
import 'package:safaria/l10n/app_localizations.dart';

class CarTierCard extends StatelessWidget {
  const CarTierCard({
    super.key,
    required this.quote,
    required this.rounded,
    required this.onTap,
  });

  final CarTripQuote quote;
  final bool rounded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final price = quote.priceFor(rounded: rounded);
    final priceText = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    ).format(price);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Material(
      color: AppColors.bgElevated,
      borderRadius: BorderRadius.circular(AppRadius.card),
      elevation: 6,
      shadowColor: AppColors.primary.withValues(alpha: 0.14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _VehicleImage(quote: quote),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quote.company.name,
                          style: AppTypography.title.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _vehicleSubtitle(quote),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (quote.company.refundability) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: _RefundableBadge(
                              label: l10n.carRefundable,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _SpecChip(
                    icon: AppIcons.seats,
                    label: l10n.carSeats(quote.vehicle.seatsNumber),
                  ),
                  _SpecChip(
                    icon: AppIcons.luggage,
                    label: l10n.carBags(
                      quote.vehicle.bigBagsCount ?? 0,
                      quote.vehicle.smallBagsCount ?? 0,
                    ),
                  ),
                  _SpecChip(
                    icon: AppIcons.gear,
                    label: _gearLabel(l10n, quote.vehicle.gearType),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1, color: AppColors.hairline),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: priceText,
                            style: AppTypography.h2.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: quote.currency,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryTint,
                      shape: BoxShape.circle,
                    ),
                    child: Transform.flip(
                      flipX: isRtl,
                      child: const Icon(
                        AppIcons.forward,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _vehicleSubtitle(CarTripQuote quote) {
    final model = quote.vehicle.model;
    if (model != null && model.isNotEmpty) {
      return '${quote.vehicle.categoryName} · $model';
    }
    return quote.vehicle.categoryName;
  }

  String _gearLabel(AppLocalizations l10n, String? gearType) {
    if (gearType == 'manual') return l10n.carGearManual;
    return l10n.carGearAutomatic;
  }
}

class _RefundableBadge extends StatelessWidget {
  const _RefundableBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTypography.overline.copyWith(
          color: AppColors.success,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleImage extends StatelessWidget {
  const _VehicleImage({required this.quote});

  final CarTripQuote quote;

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    final url = quote.vehicle.featuredUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: _size,
        height: _size,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [AppColors.primaryTint, AppColors.inputFill],
          ),
        ),
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  AppIcons.transfer,
                  color: AppColors.primary,
                  size: 28,
                ),
              )
            : const Icon(
                AppIcons.transfer,
                color: AppColors.primary,
                size: 28,
              ),
      ),
    );
  }
}
```

Delete `_SelectionMark` and any `selected` / `AnimatedContainer` selection styling.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/car/presentation/widgets/car_tier_card_test.dart`  
Expected: PASS (all three tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/car/presentation/widgets/car_tier_card.dart \
  test/features/car/presentation/widgets/car_tier_card_test.dart
git commit -m "feat(car): soft-browse CarTierCard without selection chrome"
```

---

### Task 3: Results screen — drop Continue, SnackBar on tap

**Files:**
- Modify: `lib/features/car/presentation/car_tier_results_screen.dart`
- Create: `test/features/car/presentation/car_tier_results_screen_test.dart`
- Consumes: Task 1 `carDetailsComingSoon`, Task 2 `CarTierCard` API (no `selected`)

**Interfaces:**
- Consumes: `CarTierCard({quote, rounded, onTap})`, `l10n.carDetailsComingSoon`
- Produces: results UI with no `bottomNavigationBar`; tap → SnackBar

- [ ] **Step 1: Write the failing screen tests**

Create `test/features/car/presentation/car_tier_results_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/car/domain/entities/car_place.dart';
import 'package:safaria/features/car/domain/entities/car_search_params.dart';
import 'package:safaria/features/car/presentation/car_tier_results_screen.dart';
import 'package:safaria/features/car/presentation/providers/car_booking_providers.dart';
import 'package:safaria/features/car/presentation/widgets/car_tier_card.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

import '../fake_car_repository.dart';

void main() {
  const cairo = CarPlace(
    latitude: 30.03,
    longitude: 31.26,
    label: 'Cairo',
  );
  const alex = CarPlace(
    latitude: 31.18,
    longitude: 29.89,
    label: 'Alexandria',
  );

  final params = CarSearchParams(
    from: cairo,
    to: alex,
    rounded: false,
    departDate: DateTime(2026, 7, 31),
  );

  Future<void> pumpResults(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carRepositoryProvider.overrideWithValue(
            FakeCarRepository(quotesResult: [FakeCarRepository.sampleQuote]),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: CarTierResultsScreen(),
        ),
      ),
    );

    final ctx = tester.element(find.byType(CarTierResultsScreen));
    await ProviderScope.containerOf(ctx)
        .read(carBookingProvider.notifier)
        .searchQuotes(params);
    await tester.pumpAndSettle();
  }

  testWidgets('shows quote card and no Continue button', (tester) async {
    await pumpResults(tester);

    expect(find.byType(CarTierCard), findsOneWidget);
    expect(find.text('Sky Travel'), findsOneWidget);
    expect(find.byType(PrimaryButton), findsNothing);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('tapping a card shows details coming soon snackbar',
      (tester) async {
    await pumpResults(tester);

    await tester.tap(find.byType(CarTierCard));
    await tester.pump();

    expect(find.text('Details coming soon'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/car/presentation/car_tier_results_screen_test.dart`  
Expected: FAIL — Continue / `PrimaryButton` still present and/or compile error (`selected:` still passed) and/or SnackBar text missing.

- [ ] **Step 3: Update `CarTierResultsScreen`**

In `lib/features/car/presentation/car_tier_results_screen.dart`:

1. Remove `bottomNavigationBar: _ContinueBar(...)` from the `Scaffold`.
2. Delete the entire `_ContinueBar` class.
3. Remove unused imports that only served Continue (`primary_button.dart` if unused; `auth_providers` / `guest_gate` stay if still used by `_handleAuthRetry` and any remaining guest path — **keep** guest gate on auth retry; remove guest gate from the old `_onContinue` path by deleting `_onContinue` entirely).
4. In the list `itemBuilder` for cards, change to:

```dart
          final quote = state.quotes[index - 1];
          return CarTierCard(
            key: ValueKey(quote.id),
            quote: quote,
            rounded: rounded,
            onTap: () {
              final messenger = ScaffoldMessenger.of(context);
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(l10n.carDetailsComingSoon),
                    duration: const Duration(seconds: 2),
                  ),
                );
            },
          );
```

5. Do **not** call `selectQuote` here.
6. Do **not** pass `selected:`.
7. Leave `_ResultsHeader`, `_LoadingSkeleton`, `_EmptyView`, `_ErrorView`, refresh, and auth-retry behavior unchanged.
8. Optionally bump skeleton `height` from `168` to `188` if the new card is taller — not required for tests.

Remove `guestModeProvider` import and `showGuestGate` usage that existed only inside `_onContinue`. Keep `showGuestGate` / `guestGateCarBody` for `_handleAuthRetry`.

After edits, ensure imports still resolve. Typical remaining imports:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_icons.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/date_formatting.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/features/auth/presentation/widgets/guest_gate_sheet.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/car/domain/entities/car_search_params.dart';
import 'package:safaria/features/car/presentation/car_routes.dart';
import 'package:safaria/features/car/presentation/providers/car_booking_providers.dart';
import 'package:safaria/features/car/presentation/widgets/car_tier_card.dart';
import 'package:safaria/l10n/app_localizations.dart';
```

(`auth_providers.dart` can be dropped if unused.)

- [ ] **Step 4: Run screen tests to verify they pass**

Run: `flutter test test/features/car/presentation/car_tier_results_screen_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/car/presentation/car_tier_results_screen.dart \
  test/features/car/presentation/car_tier_results_screen_test.dart
git commit -m "feat(car): browse-only results with details-coming-soon snackbar"
```

---

### Task 4: Verify suite + analyze

**Files:**
- Touch none unless analyze/tests force a fix

- [ ] **Step 1: Run car feature tests**

Run: `flutter test test/features/car/`  
Expected: all PASS (including notifier tests that still exercise `selectQuote`).

- [ ] **Step 2: Analyze touched presentation files**

Run:

```bash
flutter analyze lib/features/car/presentation/widgets/car_tier_card.dart \
  lib/features/car/presentation/car_tier_results_screen.dart \
  test/features/car/presentation/widgets/car_tier_card_test.dart \
  test/features/car/presentation/car_tier_results_screen_test.dart
```

Expected: no issues.

- [ ] **Step 3: Format**

Run: `dart format lib/features/car/presentation/widgets/car_tier_card.dart lib/features/car/presentation/car_tier_results_screen.dart test/features/car/presentation/widgets/car_tier_card_test.dart test/features/car/presentation/car_tier_results_screen_test.dart`

- [ ] **Step 4: Commit only if format/analyze produced diffs**

```bash
git add -u lib/features/car test/features/car
git status
# commit only if there are staged changes:
git commit -m "chore(car): format soft-browse results redesign"
```

If working tree clean, skip the commit.

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Soft browse layout A card | Task 2 |
| Drop `selected` / checkmark | Task 2 |
| Price + `AppIcons.forward` footer with RTL flip | Task 2 |
| Clean list S1 (header + cards) | Task 3 (keep header; no Continue) |
| Remove sticky Continue / `_ContinueBar` | Task 3 |
| Tap → `carDetailsComingSoon` SnackBar | Task 1 + Task 3 |
| Do not call `selectQuote` from UI | Task 3 |
| Keep refresh / skeleton / empty / error / auth retry | Task 3 (no change) |
| No details route / booking | All tasks (YAGNI) |
| Widget tests updated | Tasks 2–3 |
| Analyze + suite green | Task 4 |

## Out of scope (do not implement)

- Car details screen / `CarRoutes.detail`
- Contact capture / orders / payment
- Deleting unused `carContinue` / `carSelectVehicleHint` keys
- Changing `searchQuotes` auto-select of first quote
- Bus ticket-border card style
