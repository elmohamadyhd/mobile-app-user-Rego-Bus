# Home UI Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish Home mode tabs, disable empty CTAs, compact car date|time row, and show real avatar + clearer bell dot — per `docs/superpowers/specs/2026-07-28-home-ui-polish-design.md`.

**Architecture:** In-place edits to existing shared and feature widgets. No new features, APIs, or design tokens. Reuse `PrimaryButton` disabled/`loading` behavior and `ProfileCircleAvatar` for the hero.

**Tech Stack:** Flutter, Riverpod, go_router, existing Skyline tokens (`AppColors` / `AppSpacing` / `AppTypography` / `AppIcons`), ARB l10n.

## Global Constraints

- Do not invent new brand colors or hardcode hex outside existing tokens / already-local shadow patterns
- All user-facing strings via `AppLocalizations` (prefer existing keys)
- RTL: `EdgeInsetsDirectional`, no left/right
- Icons via `AppIcons` only
- Never edit `*.g.dart` / `*.freezed.dart`
- Commit only when the user asks (plan steps may stage messages; skip `git commit` unless requested)
- Spec out of scope stays out: destinations images, notification API, sticky CTA redesign

---

## File map

| File | Role |
|------|------|
| `lib/shared/widgets/transport_mode_tab_bar.dart` | Stronger selected tab |
| `lib/features/car/presentation/car_search_form.dart` | Compact date\|time; disable CTA when places empty |
| `lib/features/home/presentation/widgets/home_search_card.dart` | Disable bus CTA when cities empty; CTA label already mode-aware via form switch |
| `lib/shared/widgets/skyline_tab_hero.dart` | Avatar API on greeting row; clearer bell dot |
| `lib/features/home/presentation/home_screen.dart` | Pass `avatarUrl` into greeting row |
| `test/features/car/presentation/car_search_form_test.dart` | Update empty-CTA + add date\|time layout assertion |
| `test/features/home/presentation/home_search_card_test.dart` | New: bus CTA disabled / private label |
| `test/shared/widgets/skyline_tab_hero_test.dart` | New: avatar fallback + optional network; bell Semantics |

---

### Task 1: Car form — disabled CTA + compact date|time

**Files:**
- Modify: `lib/features/car/presentation/car_search_form.dart`
- Modify: `test/features/car/presentation/car_search_form_test.dart`

**Interfaces:**
- Consumes: `PrimaryButton(label:, loading:, onPressed:)`, existing `_from` / `_to` / `_DateTimeField`
- Produces: `onPressed: canSubmit ? _onSearch : null` where `canSubmit = _from != null && _to != null`; one-way `_DateTimeField` lays out date and time side-by-side

- [ ] **Step 1: Update failing/expectation test for empty places**

Replace the snackbar assertion in `validation blocks search when places missing` with disabled-button behavior:

```dart
testWidgets('validation blocks search when places missing', (tester) async {
  // ... same pumpWidget setup as existing test ...
  await tester.pumpAndSettle();

  final opacityFinder = find.ancestor(
    of: find.text('Request a car'),
    matching: find.byType(Opacity),
  );
  expect(tester.widget<Opacity>(opacityFinder).opacity, 0.6);

  await tester.tap(find.text('Request a car'), warnIfMissed: false);
  await tester.pumpAndSettle();

  expect(find.text('Select pickup and drop-off'), findsNothing);
});
```

Add a layout test (one-way default):

```dart
testWidgets('one-way shows date and time on one horizontal row', (tester) async {
  // pump CarSearchForm with same overrides as existing tests
  await tester.pumpAndSettle();

  final dateCenter = tester.getCenter(find.textContaining(RegExp(r'\d'))); // fragile — prefer:
  // Find time via DateFormat pattern after settling; better approach:
  // Use find.byType(_DateTimeField) is private — assert:
  // 1) carSearchTime label exists once
  // 2) homeDepart label exists
  // 3) vertical distance between date value and time value is small

  final timeLabel = find.text('Time'); // en: carSearchTime
  final departLabel = find.text('Departure'); // or whatever homeDepart is in en
  expect(timeLabel, findsOneWidget);
  expect(departLabel, findsOneWidget);

  final dy = (tester.getCenter(timeLabel).dy - tester.getCenter(departLabel).dy).abs();
  expect(dy, lessThan(24), reason: 'date and time labels should share one row');
});
```

Check exact English strings in ARB before writing (`homeDepart`, `carSearchTime`).

- [ ] **Step 2: Run tests — expect FAIL**

```bash
flutter test test/features/car/presentation/car_search_form_test.dart
```

Expected: FAIL — empty tap still shows snackbar and/or opacity is 1.0; date/time labels not side-by-side.

- [ ] **Step 3: Implement CTA gate**

In `_CarSearchFormState.build`, before `PrimaryButton`:

```dart
final canSubmit = _from != null && _to != null;
```

```dart
PrimaryButton(
  label: l10n.carRequestCar,
  loading: _searching,
  onPressed: canSubmit ? _onSearch : null,
),
```

In `_onSearch`, remove only the snackbar block for `_from == null || _to == null` (keep same-place / past / return checks).

- [ ] **Step 4: Implement compact one-way `_DateTimeField`**

Rewrite `_DateTimeField.build` so non-round-trip (when used as full-width one-way) is:

```dart
// Structure (conceptual):
Row(
  children: [
    calendar icon circle,
    Expanded(
      child: Column(
        crossAxisAlignment: start,
        children: [
          overline(label), // depart
          _TappableValue(dateValue, onPickDate),
        ],
      ),
    ),
    VerticalDivider(color: AppColors.hairline, width: 1),
    Expanded(
      child: Column(
        crossAxisAlignment: start,
        children: [
          overline(timeLabel),
          _TappableValue(timeValue, onPickTime),
        ],
      ),
    ),
  ],
)
```

For `compact: true` (round-trip columns): stack date then time vertically inside the column (spec allows this when width is tight) — keep current stacked content but tighten padding (`AppSpacing` tokens).

Use `EdgeInsetsDirectional` and existing typography/colors.

- [ ] **Step 5: Re-run tests — PASS**

```bash
flutter test test/features/car/presentation/car_search_form_test.dart
```

Expected: PASS (including existing search-proceeds test).

- [ ] **Step 6: Commit (only if user requested)**

```bash
git add lib/features/car/presentation/car_search_form.dart test/features/car/presentation/car_search_form_test.dart
git commit -m "fix(car): disable empty CTA and compact date-time row on home search"
```

---

### Task 2: Bus form — disable empty CTA

**Files:**
- Modify: `lib/features/home/presentation/widgets/home_search_card.dart`
- Create: `test/features/home/presentation/home_search_card_test.dart`

**Interfaces:**
- Consumes: `HomeSearchCard(selectedTab:, onTabChanged:)`, `TransportModeTabBar.busTabIndex` / `privateTabIndex`
- Produces: Bus `PrimaryButton.onPressed` null unless both cities set; private tab still embeds `CarSearchForm` (label `carRequestCar`)

- [ ] **Step 1: Add `@visibleForTesting` initial cities (minimal hook)**

On `HomeSearchCard`:

```dart
const HomeSearchCard({
  super.key,
  required this.selectedTab,
  required this.onTabChanged,
  @visibleForTesting this.initialFromCity,
  @visibleForTesting this.initialToCity,
});

@visibleForTesting
final BusLocation? initialFromCity;
@visibleForTesting
final BusLocation? initialToCity;
```

In `initState` (add if missing):

```dart
@override
void initState() {
  super.initState();
  _fromCity = widget.initialFromCity;
  _toCity = widget.initialToCity;
}
```

- [ ] **Step 2: Write failing tests**

```dart
// test/features/home/presentation/home_search_card_test.dart
// Pump MaterialApp + ProviderScope with busLocationsProvider override if needed.
// Tab 0 (bus): empty cities → Opacity around homeSearch label is 0.6
// With initialFromCity + initialToCity → Opacity 1.0
// Tab privateTabIndex → find.text for carRequestCar (en: 'Request a car')
```

Use a tiny fake `BusLocation` from existing test fixtures if available; otherwise construct with required fields from `BusLocation` entity.

- [ ] **Step 3: Run — FAIL**

```bash
flutter test test/features/home/presentation/home_search_card_test.dart
```

- [ ] **Step 4: Gate bus CTA**

In `_buildBusForm`:

```dart
final canSubmit = _fromCity != null && _toCity != null;
PrimaryButton(
  label: l10n.homeSearch,
  loading: _searching,
  onPressed: canSubmit ? _onSearch : null,
),
```

Remove snackbar-only path for missing cities in `_onSearch` (keep early return safety if desired without UI).

- [ ] **Step 5: Run — PASS**

```bash
flutter test test/features/home/presentation/home_search_card_test.dart
flutter analyze lib/features/home/presentation/widgets/home_search_card.dart
```

- [ ] **Step 6: Commit (only if user requested)**

```bash
git add lib/features/home/presentation/widgets/home_search_card.dart test/features/home/presentation/home_search_card_test.dart
git commit -m "fix(home): disable bus search CTA until cities are selected"
```

---

### Task 3: Stronger transport mode tabs

**Files:**
- Modify: `lib/shared/widgets/transport_mode_tab_bar.dart`
- Optional test: `test/shared/widgets/transport_mode_tab_bar_test.dart`

**Interfaces:**
- Consumes: `selectedIndex`, `onChanged`
- Produces: Visual-only change; same public API

- [ ] **Step 1: Write widget test for selected styling**

```dart
testWidgets('selected tab uses primary icon color', (tester) async {
  var index = 1;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: TransportModeTabBar(
          selectedIndex: index,
          onChanged: (i) => index = i,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final privateIcon = tester.widget<Icon>(
    find.descendant(
      of: find.text('Private'), // homeTabPrivate en — verify ARB
      matching: find.byType(Icon),
    ),
  );
  expect(privateIcon.color, AppColors.primary);
});
```

- [ ] **Step 2: Strengthen `_TransportModeTab`**

- Selected: `Material` color white (keep) + `elevation: 2` + `shadowColor: AppColors.primary.withValues(alpha: 0.18)`  
  OR selected fill `AppColors.primaryTint` with white border — pick one and keep contrast ≥ existing.
- Icon size 20–22; selected icon `AppColors.primary`; unselected `AppColors.textMuted`.
- Label: selected `FontWeight.w800` + `AppColors.primary`; unselected muted.
- Keep `InkWell` + padding so height ≥ 48.

Do not change tab count/order.

- [ ] **Step 3: Run tests + analyze**

```bash
flutter test test/shared/widgets/transport_mode_tab_bar_test.dart
flutter analyze lib/shared/widgets/transport_mode_tab_bar.dart
```

- [ ] **Step 4: Commit (only if user requested)**

```bash
git add lib/shared/widgets/transport_mode_tab_bar.dart test/shared/widgets/transport_mode_tab_bar_test.dart
git commit -m "fix(ui): strengthen transport mode tab selected state"
```

---

### Task 4: Hero avatar + clearer bell badge

**Files:**
- Modify: `lib/shared/widgets/skyline_tab_hero.dart`
- Modify: `lib/features/home/presentation/home_screen.dart`
- Create: `test/shared/widgets/skyline_tab_hero_test.dart`

**Interfaces:**
- Consumes: `AuthUser.avatarUrl`, `ProfileCircleAvatar` (`style: ProfileCircleAvatarStyle.hero`)
- Produces:
  - `SkylineTabGreetingRow({ required initial, String? avatarUrl, ... })`
  - `SkylineTabHeroBellButton` larger amber dot (10–11 logical px)

- [ ] **Step 1: Extend greeting row API**

```dart
class SkylineTabGreetingRow extends StatelessWidget {
  const SkylineTabGreetingRow({
    super.key,
    required this.initial,
    required this.greeting,
    required this.headline,
    this.avatarUrl,
    this.trailing,
  });

  final String initial;
  final String? avatarUrl;
  // ...
}
```

Replace the letter-only `Container` with:

```dart
ProfileCircleAvatar(
  size: 42,
  initial: initial,
  networkUrl: avatarUrl,
  style: ProfileCircleAvatarStyle.hero,
)
```

Import: `package:safaria/features/profile/presentation/widgets/profile_circle_avatar.dart`  
(If analyzer/architecture complains, move `profile_circle_avatar.dart` to `lib/shared/widgets/` in this same task — no behavior change.)

- [ ] **Step 2: Wire HomeScreen**

```dart
SkylineTabGreetingRow(
  initial: initial,
  avatarUrl: user?.avatarUrl,
  greeting: l10n.homeGreeting(userName),
  headline: l10n.homeWhereTo,
  trailing: const SkylineTabHeroBellButton(),
),
```

- [ ] **Step 3: Enlarge bell badge**

In `SkylineTabHeroBellButton`, change the badge `Container` to ~10–11 width/height; keep `AppColors.secondary` and border. Wrap icon button with `Semantics(button: true, label: ...)` using existing or new l10n key if none exists — if adding key, update both ARBs + `flutter gen-l10n`.

- [ ] **Step 4: Tests**

```dart
testWidgets('greeting shows initial when no avatarUrl', ...);
testWidgets('bell badge is at least 10px', (tester) async {
  await tester.pumpWidget(/* SkylineTabHeroBellButton in MaterialApp */);
  // Find the secondary-colored DecoratedBox/Container by color predicate
  // assert size >= 10
});
```

- [ ] **Step 5: Analyze + targeted tests**

```bash
flutter test test/shared/widgets/skyline_tab_hero_test.dart test/features/shell/home_shell_layout_test.dart
flutter analyze lib/shared/widgets/skyline_tab_hero.dart lib/features/home/presentation/home_screen.dart
```

- [ ] **Step 6: Commit (only if user requested)**

```bash
git add lib/shared/widgets/skyline_tab_hero.dart lib/features/home/presentation/home_screen.dart test/shared/widgets/skyline_tab_hero_test.dart
# + arb if Semantics key added
git commit -m "fix(home): show profile avatar and clearer notification dot on hero"
```

---

### Task 5: Final verification

- [ ] **Step 1: Run full related suite**

```bash
flutter test test/features/car/presentation/car_search_form_test.dart test/features/home/presentation/home_search_card_test.dart test/shared/widgets/transport_mode_tab_bar_test.dart test/shared/widgets/skyline_tab_hero_test.dart test/features/shell/home_shell_layout_test.dart
flutter analyze lib/shared/widgets/transport_mode_tab_bar.dart lib/shared/widgets/skyline_tab_hero.dart lib/features/car/presentation/car_search_form.dart lib/features/home/presentation/widgets/home_search_card.dart lib/features/home/presentation/home_screen.dart
```

Expected: all PASS / no issues.

- [ ] **Step 2: Manual smoke (device or emulator)**

1. Home AR locale: selected Private tab visually strong  
2. Empty places → CTA dimmed, no snackbar  
3. Fill places → CTA enabled → loading → navigate  
4. Date|time side-by-side on one-way  
5. Avatar letter / photo; bell amber dot readable  

---

## Spec coverage

| Spec requirement | Task |
|------------------|------|
| Stronger mode selector | 3 |
| Dynamic CTA labels (bus vs car via form switch) | 1 + 2 |
| Disable CTA until from+to | 1 + 2 |
| Keep loading on search | 1 + 2 (existing) |
| Car date\|time side-by-side (one-way) | 1 |
| Round-trip compact columns | 1 |
| Real avatar + letter fallback | 4 |
| Clearer bell dot (no count) | 4 |
| Out of scope left alone | — |

## Placeholder / consistency self-check

- No TBD steps; exact files and commands listed  
- `canSubmit` / `onPressed: null` consistent across car + bus  
- `SkylineTabGreetingRow.avatarUrl` wired only from Home  
- Commits gated on user request per repo rules  
