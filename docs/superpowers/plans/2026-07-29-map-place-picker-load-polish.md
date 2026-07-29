# Map Place Picker Load + Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a map-loading veil until the first post-create camera idle (8s failsafe), and apply medium Skyline polish to `MapPlacePickerScreen`.

**Architecture:** Keep the existing map-first picker. Add `_mapReady` + failsafe timer next to the existing create timeout; overlay sits above `GoogleMap` and under chrome/sheet. Polish is widget-local token swaps (header chip, pin, search/selection borders, sheet rhythm, safe-area CTA, GPS a11y).

**Tech Stack:** Flutter, `google_maps_flutter`, Riverpod, `AppLocalizations`, Phosphor Light, existing car picker widget tests.

**Spec:** `docs/superpowers/specs/2026-07-29-map-place-picker-load-polish-design.md`

## Global Constraints

- Tokens only: `AppColors` / `AppSpacing` / `AppRadius` / `AppTypography` — no hardcoded hex/radii.
- Icons: `PhosphorIconsLight.*` only.
- All user-facing strings via ARB (`mapLoading`, `mapLocateMe`) in both `app_en.arb` and `app_ar.arb`.
- Directional layout (`EdgeInsetsDirectional`, RTL-safe).
- Do not change GPS sequencing, Places API, or map-unavailable 3s behavior.
- Do not commit unless the user explicitly asks.
- After ARB edits: `flutter gen-l10n`.
- Analyze/tests: `flutter analyze` and `flutter test test/features/car/presentation/car_place_picker_screen_test.dart`.

---

## File structure (touched)

| Path | Role |
|------|------|
| `lib/l10n/app_en.arb` | `mapLoading`, `mapLocateMe` + `@` metadata |
| `lib/l10n/app_ar.arb` | Arabic strings |
| `lib/shared/widgets/map_place_picker_screen.dart` | Ready state, veil, polish |
| `test/features/car/presentation/car_place_picker_screen_test.dart` | Overlay presence / absence / failsafe |

---

### Task 1: Localization keys

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ar.arb`

**Interfaces:**
- Produces: `AppLocalizations.mapLoading`, `AppLocalizations.mapLocateMe`

- [ ] **Step 1: Add English keys**

Near the other place-picker keys in `app_en.arb` (after `carMapsNotConfigured` is fine), add:

```json
  "mapLoading": "Loading map…",
  "@mapLoading": {
    "description": "Overlay label while Google Map initializes on the place picker."
  },
  "mapLocateMe": "Locate me",
  "@mapLocateMe": {
    "description": "Accessibility label for the GPS / center-on-me FAB on the map place picker."
  },
```

- [ ] **Step 2: Add Arabic keys**

In `app_ar.arb`:

```json
  "mapLoading": "جاري تحميل الخريطة",
  "mapLocateMe": "موقعي الحالي",
```

- [ ] **Step 3: Generate localizations**

Run: `flutter gen-l10n`  
Expected: succeeds; generated `AppLocalizations` exposes `mapLoading` and `mapLocateMe`.

- [ ] **Step 4: Commit (only if user asked)**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "feat(l10n): add map loading and locate-me strings"
```

---

### Task 2: Failing tests for loading veil

**Files:**
- Modify: `test/features/car/presentation/car_place_picker_screen_test.dart`
- Test: same file

**Interfaces:**
- Consumes: `mapLoading` string; overlay `ValueKey('mapLoadingOverlay')` (implemented in Task 3)
- Produces: three widget tests that fail until overlay logic exists

- [ ] **Step 1: Write failing tests**

Add after the existing `setUp`/`tearDown` block helpers, these tests (use existing `pumpPicker`):

```dart
  testWidgets('shows map loading overlay when maps are available',
      (tester) async {
    await pumpPicker(
      tester,
      args: const CarPlacePickerArgs(title: 'Pickup'),
    );

    expect(find.byKey(const ValueKey('mapLoadingOverlay')), findsOneWidget);
    expect(find.text('Loading map…'), findsOneWidget);
  });

  testWidgets('hides map loading overlay when maps unavailable',
      (tester) async {
    GoogleMapsCapabilities.setMapRenderingAvailableForTesting(false);
    await pumpPicker(
      tester,
      args: const CarPlacePickerArgs(title: 'Pickup'),
    );

    expect(find.byKey(const ValueKey('mapLoadingOverlay')), findsNothing);
    expect(find.text('Loading map…'), findsNothing);
  });

  testWidgets('dismisses map loading overlay after ready failsafe',
      (tester) async {
    await pumpPicker(
      tester,
      args: const CarPlacePickerArgs(title: 'Pickup'),
    );
    expect(find.byKey(const ValueKey('mapLoadingOverlay')), findsOneWidget);

    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const ValueKey('mapLoadingOverlay')), findsNothing);
  });
```

Note: `pumpPicker` already pumps ~300ms after open — overlay must still be present until ready/failsafe. Do not call `pumpAndSettle` for the failsafe test after the 8s pump if animations loop; prefer finite `pump` durations.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
flutter test test/features/car/presentation/car_place_picker_screen_test.dart --name "map loading"
```

Expected: FAIL — `ValueKey('mapLoadingOverlay')` / `Loading map…` not found (or first test fails).

- [ ] **Step 3: Commit (only if user asked)**

```bash
git add test/features/car/presentation/car_place_picker_screen_test.dart
git commit -m "test: cover map place picker loading overlay"
```

---

### Task 3: Map ready state + loading veil

**Files:**
- Modify: `lib/shared/widgets/map_place_picker_screen.dart`

**Interfaces:**
- Consumes: `AppLocalizations.mapLoading`
- Produces:
  - `bool _mapReady`
  - `Timer? _mapReadyFailsafe`
  - `_markMapReady()` → sets ready, cancels failsafe, `setState`
  - Overlay widget with `key: ValueKey('mapLoadingOverlay')`
  - `_onCameraIdle` sets ready when `_mapCreated && !_ignoreMapEvents && !_mapReady`

- [ ] **Step 1: Add ready state fields and helpers**

In `_MapPlacePickerScreenState`, next to `_mapCreated` / `_mapCreateTimeout`:

```dart
  bool _mapReady = false;
  Timer? _mapReadyFailsafe;

  static const _mapReadyFailsafeDuration = Duration(seconds: 8);
  static const _mapVeilFade = Duration(milliseconds: 250);

  void _markMapReady() {
    if (!mounted || _mapReady) return;
    _mapReadyFailsafe?.cancel();
    setState(() => _mapReady = true);
  }

  void _startMapReadyFailsafe() {
    _mapReadyFailsafe?.cancel();
    _mapReadyFailsafe = Timer(_mapReadyFailsafeDuration, _markMapReady);
  }
```

In `dispose`, cancel `_mapReadyFailsafe`.

In `initState` post-frame, when `GoogleMapsCapabilities.mapRenderingAvailable`, after scheduling the 3s create timeout, also call `_startMapReadyFailsafe()`.

Update `_onMapCreated`:

```dart
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapCreated = true;
    _mapCreateTimeout?.cancel();
  }
```

Update `_onCameraIdle` — at the top, after the existing early returns for ignore/unavailable, add:

```dart
  void _onCameraIdle() {
    if (_ignoreMapEvents || !GoogleMapsCapabilities.mapRenderingAvailable) {
      return;
    }
    if (_mapCreated && !_mapReady) {
      _markMapReady();
    }
    // ... existing draft / geocode debounce logic unchanged ...
  }
```

- [ ] **Step 2: Add `_MapLoadingVeil` widget**

```dart
class _MapLoadingVeil extends StatelessWidget {
  const _MapLoadingVeil({required this.visible, required this.label});

  final bool visible;
  final String label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: _MapPlacePickerScreenState._mapVeilFade,
        curve: Curves.easeOut,
        child: visible
            ? ColoredBox(
                key: const ValueKey('mapLoadingOverlay'),
                color: AppColors.bgBase,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        label,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
```

When `visible` becomes false, keep fading: better pattern — always keep the `ColoredBox` in tree until opacity hits 0, or use:

```dart
AnimatedOpacity(
  opacity: visible ? 1 : 0,
  duration: _MapPlacePickerScreenState._mapVeilFade,
  curve: Curves.easeOut,
  child: IgnorePointer(
    child: ColoredBox(
      key: const ValueKey('mapLoadingOverlay'),
      color: AppColors.bgBase,
      child: /* spinner + label */,
    ),
  ),
)
```

and only insert the veil in the `Stack` when `showMap && (!_mapReady || _fading)` — simplest approach that still satisfies tests:

- While `!_mapReady`, show veil with key.
- After `_markMapReady`, remove after fade: set `_mapReady = true` then optionally keep a `_showVeil` that becomes false after fade via `Future.delayed` / `AnimationStatus`. **Minimal approach for tests:** remove veil from tree when `_mapReady` (instant hide is OK if fade is nice-to-have; prefer fade with delayed removal).

Recommended minimal:

```dart
if (showMap && !_mapReady)
  _MapLoadingVeil(label: l10n.mapLoading),
```

with `_MapLoadingVeil` as a static colored overlay (fade can wrap it). Failsafe test pumps 8s then expects key gone — `_markMapReady` removes it.

- [ ] **Step 3: Insert veil in portrait and landscape map stacks**

Portrait `Stack` children order:

1. `mapLayer`
2. Loading veil (if `!_mapReady`)
3. `_CenterPin`
4. Header `SafeArea`
5. GPS FAB
6. Sheet

Landscape map `Stack`: same relative order (map → veil → pin → back → GPS).

Pass `l10n.mapLoading` into the veil.

- [ ] **Step 4: Run map-loading tests**

Run:

```bash
flutter test test/features/car/presentation/car_place_picker_screen_test.dart --name "map loading"
```

Expected: PASS for all three new tests.

- [ ] **Step 5: Run full picker suite**

Run:

```bash
flutter test test/features/car/presentation/car_place_picker_screen_test.dart
```

Expected: all PASS (sheet remains usable under veil).

- [ ] **Step 6: Commit (only if user asked)**

```bash
git add lib/shared/widgets/map_place_picker_screen.dart
git commit -m "feat: show map loading veil until camera idle"
```

---

### Task 4: Medium visual polish

**Files:**
- Modify: `lib/shared/widgets/map_place_picker_screen.dart`

**Interfaces:**
- Consumes: `AppLocalizations.mapLocateMe`
- Produces: polished header, pin, search, selection card, sheet padding, GPS FAB a11y

- [ ] **Step 1: Header scrim chip**

Replace the plain title `Row` in the portrait header with a Material/DecoratedBox chip:

```dart
Material(
  color: AppColors.bgCard.withValues(alpha: 0.92),
  elevation: 2,
  shadowColor: Colors.black26,
  borderRadius: BorderRadius.circular(AppRadius.lg),
  child: Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.xs,
      AppSpacing.xs,
      AppSpacing.md,
      AppSpacing.xs,
    ),
    child: Row(
      children: [
        AuthBackButton(onTap: () => context.pop()),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            widget.args.title,
            style: AppTypography.title.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  ),
)
```

Ensure `app_spacing.dart` / `AppRadius` is imported (file already uses `AppRadius` via `app_spacing.dart` — add import if missing: `package:safaria/core/theme/app_spacing.dart` already present).

- [ ] **Step 2: Richer center pin**

Replace `_CenterPin` body with pin + shadow + tint disc:

```dart
class _CenterPin extends StatelessWidget {
  const _CenterPin();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsLight.mapPin,
              size: 40,
              color: AppColors.primary,
              shadows: [
                Shadow(
                  color: Color(0x40000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            SizedBox(height: 2),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: SizedBox(width: 10, height: 10),
            ),
          ],
        ),
      ),
    );
  }
}
```

If shadow hex is frowned on by design-tokens rule, use `Colors.black.withValues(alpha: 0.25)` instead of raw `Color(0x40…)`.

- [ ] **Step 3: Search + selection contrast**

In `_PickerPanel` search `Container` decoration:

- `border: Border.all(color: AppColors.border)` (replace `hairline`)
- Magnifier icon color: `AppColors.textSecondary`
- Hint style color: `AppColors.textSecondary`

In `_CurrentSelectionRow`:

- `border: Border.all(color: AppColors.border)`
- Padding: `AppSpacing.md` stays or use `EdgeInsetsDirectional.all(AppSpacing.md)` with a bit more vertical via `md` only (already md)
- Caption color: `AppColors.textSecondary` (replace `textMuted`)

- [ ] **Step 4: Sheet rhythm + safe-area CTA**

In `_PickerPanel` confirm `Padding`, use:

```dart
padding: EdgeInsetsDirectional.fromSTEB(
  AppSpacing.md,
  AppSpacing.sm,
  AppSpacing.md,
  AppSpacing.md + MediaQuery.paddingOf(context).bottom,
),
```

Slightly increase spacing under the drag handle / before search if needed (`AppSpacing.sm` → keep consistent 8dp rhythm).

Sheet `Material` elevation: keep 8 or bump to 12; `shadowColor: Colors.black26`.

- [ ] **Step 5: GPS FAB accessibility**

In `_GpsFab`, accept `String accessibilityLabel` and wrap `InkWell` / `Material`:

```dart
class _GpsFab extends StatelessWidget {
  const _GpsFab({
    required this.loading,
    required this.onTap,
    required this.accessibilityLabel,
  });
  // ...
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: accessibilityLabel,
      child: Material(
        color: AppColors.bgCard,
        elevation: 6,
        shadowColor: Colors.black26,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: loading ? null : onTap,
          child: /* unchanged 48x48 */,
        ),
      ),
    );
  }
}
```

Call sites: `accessibilityLabel: l10n.mapLocateMe` (pass `l10n` into builders that construct the FAB, or read `AppLocalizations.of(context)` inside `_GpsFab`).

- [ ] **Step 6: Analyze + full picker tests**

Run:

```bash
flutter analyze lib/shared/widgets/map_place_picker_screen.dart
flutter test test/features/car/presentation/car_place_picker_screen_test.dart
```

Expected: no issues; all tests PASS.

- [ ] **Step 7: Commit (only if user asked)**

```bash
git add lib/shared/widgets/map_place_picker_screen.dart lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "style: polish map place picker chrome and contrast"
```

---

### Task 5: Spec compliance pass

**Files:**
- Verify only (no new files unless a gap is found)

- [ ] **Step 1: Checklist against spec**

Confirm each item:

| Spec item | Done? |
|-----------|-------|
| Veil until first idle after create | |
| Ignore idle while `_ignoreMapEvents` | |
| 3s unavailable path unchanged | |
| 8s failsafe | |
| No veil when maps unavailable | |
| Header scrim chip | |
| Richer pin | |
| Search/selection border + contrast | |
| Sheet rhythm + safe CTA | |
| GPS a11y label | |
| `mapLoading` / `mapLocateMe` AR+EN | |

- [ ] **Step 2: Manual smoke (device/emulator)**

1. Open car pickup picker with network → see loading veil, then map tiles, veil clears.  
2. Confirm search + confirm still work during/after veil.  
3. Rotate to landscape → veil/polish still sane.  
4. Force airplane mode / bad key if available → 3s fallback list-only, no stuck spinner.

- [ ] **Step 3: Final analyze + test**

```bash
flutter analyze
flutter test test/features/car/presentation/car_place_picker_screen_test.dart
```

Expected: clean / PASS.

---

## Plan self-review

1. **Spec coverage:** Loading Approach 2, polish table, l10n, tests, out-of-scope respected — Tasks 1–5 map 1:1.  
2. **Placeholders:** None.  
3. **Type consistency:** `_mapReady`, `ValueKey('mapLoadingOverlay')`, `mapLoading` / `mapLocateMe` names consistent across tasks.
