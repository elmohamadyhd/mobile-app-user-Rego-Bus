# Popular Destinations → Bus To Field Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.
>
> Execute on the **current branch**. Commits only if the user explicitly asks.

**Goal:** Show all bus locations as a horizontal popular-destinations list on
Home (bus tab only); tapping a city fills the search **To** field.

**Architecture:** `HomeScreen` coordinates `fromCity` / `toCity` between
`HomeSearchCard` (callbacks + controlled `toCity`) and `PopularDestinations`
(watches `busLocationsProvider`). Section hidden when not on bus tab or when
locations are loading/empty/error.

**Tech Stack:** Flutter, Riverpod, `BusLocation`, `busLocationsProvider`,
`flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-03-popular-destinations-to-field-design.md`

## Global Constraints

- Package imports: `package:safaria/...` only.
- Icons: `PhosphorIconsLight.*` only if any new icons.
- Tokens: `AppColors` / `AppSpacing` / `AppRadius` / `AppTypography`.
- User strings via `AppLocalizations`.
- Directional insets (`EdgeInsetsDirectional`).
- Visible only for bus tab; hide for other transport tabs.
- Ignore tap when selected city id equals current **From** id.
- No price, no “See all”.
- Hide section on loading / empty / error (no crash).
- Do not create a new git branch.
- Do not commit unless the user asks.

## File map

| File | Action |
|------|--------|
| `lib/features/home/presentation/widgets/popular_destinations.dart` | Rewrite |
| `lib/features/home/presentation/widgets/home_search_card.dart` | Add city change callbacks + controlled `toCity` sync |
| `lib/features/home/presentation/home_screen.dart` | Wire state + visibility |
| `lib/l10n/app_en.arb` / `app_ar.arb` | Remove orphan `homeSeeAll`, `homeCityLuxor`, `homeCityAswan` only |
| `test/features/home/presentation/popular_destinations_test.dart` | Create |
| `test/features/home/presentation/home_screen_popular_destinations_test.dart` | Create |
| Keep `homeComingSoon` — still used elsewhere |

---

### Task 1: Rewrite `PopularDestinations` (data + UI)

**Files:**
- Modify: `lib/features/home/presentation/widgets/popular_destinations.dart`
- Create: `test/features/home/presentation/popular_destinations_test.dart`

**Produces:**
```dart
class PopularDestinations extends ConsumerWidget {
  const PopularDestinations({
    super.key,
    required this.visible,
    this.excludeCityId,
    required this.onSelected,
  });
  final bool visible;
  final int? excludeCityId;
  final ValueChanged<BusLocation> onSelected;
}
```

**Consumes:** `busLocationsProvider`, `BusLocation.displayName`

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/bus/domain/entities/bus_location.dart';
import 'package:safaria/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:safaria/features/bus/presentation/providers/bus_locations_provider.dart';
import 'package:safaria/features/home/presentation/widgets/popular_destinations.dart';
import 'package:safaria/l10n/app_localizations.dart';
import '../../bus/fake_bus_repository.dart';

void main() {
  final cairo = FakeBusRepository.sampleLocations.first; // id 1 typically
  final alex = FakeBusRepository.sampleLocations[1];

  Widget pump({
    required bool visible,
    int? excludeCityId,
    required List<BusLocation> Function() onCapture,
  }) {
    final selected = <BusLocation>[];
    return ProviderScope(
      overrides: [
        busRepositoryProvider.overrideWithValue(
          FakeBusRepository(
            locationsResult: FakeBusRepository.sampleLocations,
          ),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: PopularDestinations(
            visible: visible,
            excludeCityId: excludeCityId,
            onSelected: selected.add,
          ),
        ),
      ),
    );
  }

  testWidgets('renders nothing when not visible', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          busRepositoryProvider.overrideWithValue(FakeBusRepository()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: PopularDestinations(
              visible: false,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Popular destinations'), findsNothing);
  });

  testWidgets('lists location names when visible', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          busRepositoryProvider.overrideWithValue(FakeBusRepository()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: PopularDestinations(
              visible: true,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Popular destinations'), findsOneWidget);
    expect(find.text('Cairo'), findsWidgets); // or sample displayName
  });

  testWidgets('tap selects city; same as exclude is ignored', (tester) async {
    final selected = <BusLocation>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          busRepositoryProvider.overrideWithValue(FakeBusRepository()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: PopularDestinations(
              visible: true,
              excludeCityId: 1,
              onSelected: selected.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Tap Cairo (id 1) — ignored
    await tester.tap(find.text('Cairo').first);
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    // Tap Alexandria — selected
    await tester.tap(find.text('Alexandria').first);
    await tester.pumpAndSettle();
    expect(selected.single.id, 2);
  });
}
```

Adjust expected English names to match `FakeBusRepository.sampleLocations`
`nameEn` values exactly (read the fake before writing asserts).

- [ ] **Step 2: Run tests — expect FAIL**

```bash
flutter test test/features/home/presentation/popular_destinations_test.dart
```

- [ ] **Step 3: Implement `PopularDestinations`**

```dart
class PopularDestinations extends ConsumerWidget {
  const PopularDestinations({
    super.key,
    required this.visible,
    this.excludeCityId,
    required this.onSelected,
  });

  final bool visible;
  final int? excludeCityId;
  final ValueChanged<BusLocation> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!visible) return const SizedBox.shrink();

    final async = ref.watch(busLocationsProvider);
    return async.when(
      data: (locations) {
        if (locations.isEmpty) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context);
        final locale = Localizations.localeOf(context).languageCode;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.homePopularDestinations,
              style: AppTypography.title.copyWith(fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: locations.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final city = locations[i];
                  final excluded = excludeCityId != null &&
                      city.id == excludeCityId;
                  return _DestCard(
                    city: city.displayName(locale),
                    gradient: i.isEven
                        ? const LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryDeep,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [
                              AppColors.secondary,
                              AppColors.onSecondary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    enabled: !excluded,
                    onTap: excluded
                        ? null
                        : () => onSelected(city),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
```

Adapt `_DestCard` to take `enabled` + `onTap` (`InkWell` / `GestureDetector`),
opacity when disabled. Remove price and See all. Verify
`AppColors.onSecondary` contrast on amber — if poor, use a darker amber
token already in `AppColors` (e.g. existing secondary dark) without inventing
new hex in the widget if a token exists; otherwise keep the previous amber
pair from the old card as a last resort and note it.

- [ ] **Step 4: Run tests — expect PASS**

```bash
flutter test test/features/home/presentation/popular_destinations_test.dart
```

---

### Task 2: Controlled To + city callbacks on `HomeSearchCard`

**Files:**
- Modify: `lib/features/home/presentation/widgets/home_search_card.dart`
- Modify: `test/features/home/presentation/home_search_card_test.dart` (extend)

**Produces:**
```dart
// New optional params on HomeSearchCard:
final ValueChanged<BusLocation?>? onFromCityChanged;
final ValueChanged<BusLocation?>? onToCityChanged;
final BusLocation? toCity; // when set from parent, sync into _toCity
```

**Consumes:** existing `_fromCity` / `_toCity` state

- [ ] **Step 1: Write failing test**

```dart
testWidgets('updates To when parent passes a new toCity', (tester) async {
  BusLocation? reportedTo;
  final to = FakeBusRepository.sampleLocations[1];
  await tester.pumpWidget(
    _wrap(
      HomeSearchCard(
        selectedTab: TransportModeTabBar.busTabIndex,
        onTabChanged: (_) {},
        initialFromCity: FakeBusRepository.sampleLocations.first,
        toCity: null,
        onToCityChanged: (c) => reportedTo = c,
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.pumpWidget(
    _wrap(
      HomeSearchCard(
        selectedTab: TransportModeTabBar.busTabIndex,
        onTabChanged: (_) {},
        initialFromCity: FakeBusRepository.sampleLocations.first,
        toCity: to,
        onToCityChanged: (c) => reportedTo = c,
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text(to.displayName('en')), findsOneWidget);
});
```

- [ ] **Step 2: Implement sync + notify**

- Add fields `toCity`, `onFromCityChanged`, `onToCityChanged` to widget.
- In `didUpdateWidget`, if `widget.toCity != oldWidget.toCity` and
  `widget.toCity != _toCity`, `setState(() => _toCity = widget.toCity)`.
- Whenever `_fromCity` / `_toCity` change (picker, swap, init), call the
  corresponding callbacks after `setState`.
- Keep `initialFromCity` / `initialToCity` for first frame.

- [ ] **Step 3: Run home_search_card tests**

```bash
flutter test test/features/home/presentation/home_search_card_test.dart
```

Expected: PASS.

---

### Task 3: Wire `HomeScreen` + integration tests + ARB cleanup

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart`
- Create: `test/features/home/presentation/home_screen_popular_destinations_test.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` (remove orphans)
- Run: `flutter gen-l10n`

**Consumes:** Task 1 + Task 2 APIs

- [ ] **Step 1: Wire HomeScreen**

```dart
BusLocation? _fromCity;
BusLocation? _toCity;

// children:
HomeSearchCard(
  selectedTab: _transportTab,
  onTabChanged: (i) => setState(() => _transportTab = i),
  toCity: _toCity,
  onFromCityChanged: (c) => setState(() => _fromCity = c),
  onToCityChanged: (c) => setState(() => _toCity = c),
),
PopularDestinations(
  visible: _transportTab == TransportModeTabBar.busTabIndex,
  excludeCityId: _fromCity?.id,
  onSelected: (city) {
    if (_fromCity?.id == city.id) return;
    setState(() => _toCity = city);
  },
),
```

Import `TransportModeTabBar` / `BusLocation` as needed. If search card still
owns initial defaults for Cairo/Alex, ensure `onFromCityChanged` fires after
first resolve so `excludeCityId` is correct — if cities start null until
user picks, that is OK per current card behavior.

- [ ] **Step 2: Integration tests**

```dart
testWidgets('popular tap fills To on bus tab', ...);
testWidgets('section hidden on car tab', ...);
```

Pump a minimal `HomeScreen` (or extractable harness) with
`FakeBusRepository` + auth/session overrides as required by `HomeScreen`.
If `HomeScreen` is heavy, pump the same Column structure used in home with
the real widgets under `ProviderScope` overrides — prefer testing the
wired pair without full shell if shell deps block; otherwise override
`sessionControllerProvider` / `guestModeProvider` / notifications like
other home tests if they exist.

If no existing home screen test harness, create the lightest pump that
builds `HomeSearchCard` + `PopularDestinations` with the same state logic
in a tiny `_Harness` StatefulWidget in the test file that mirrors
`HomeScreen` wiring (acceptable if full `HomeScreen` needs many overrides).
Prefer full `HomeScreen` when feasible.

- [ ] **Step 3: Remove orphan ARB keys**

Delete `homeSeeAll`, `homeCityLuxor`, `homeCityAswan` from both ARB files
only if unused. Keep `homeComingSoon`. Run `flutter gen-l10n`.

- [ ] **Step 4: Analyze + tests**

```bash
flutter test test/features/home/
dart analyze lib/features/home
```

Expected: PASS / no issues.

---

## Spec coverage self-check

| Spec item | Task |
|---|---|
| All locations horizontal list | 1 |
| Bus-tab visibility | 1 + 3 |
| Tap → To | 2 + 3 |
| Same as From ignored | 1 + 3 |
| No price / See all | 1 |
| Hide loading/empty/error | 1 |
| Parent coordination | 3 |
| Tests | 1–3 |

## Placeholder scan

No TBD steps. Names: `visible`, `excludeCityId`, `onSelected`, `toCity`,
`onFromCityChanged`, `onToCityChanged`.
