# Car Place Coordinate Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix false-positive `carSearchSamePlace` errors by making `CarPlacePickerScreen` return atomic, consistent `CarPlace` objects (last-write-wins coords) and degrade gracefully when Maps SDK tiles are unavailable.

**Architecture:** Introduce `GoogleMapsCapabilities` for Places vs map-tile availability. Refactor picker state around a canonical `_draft` with `_draftVersion` and `_ignoreMapEvents` guards. Confirm pops `_draft` directly. Search-only layout hides `GoogleMap` when map rendering is unavailable.

**Tech Stack:** Flutter, Riverpod, `google_maps_flutter`, `geolocator`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-07-23-car-place-coordinate-fix-design.md`

---

## Notes for the implementing engineer

- Run `flutter analyze` after any task touching more than two files.
- No `.arb` changes expected — skip `flutter gen-l10n`.
- Widget tests use `GoogleMap` platform views; `pump()` with durations instead of `pumpAndSettle()` where maps are present to avoid platform-channel hangs.
- Reset `GoogleMapsCapabilities.resetSessionForTesting()` in `tearDown` of picker tests.
- Run targeted tests per task; full car suite at the end: `flutter test test/features/car/`

## File map

| File | Responsibility |
|------|----------------|
| `lib/core/places/google_maps_capabilities.dart` | Places vs map-tile capability + session flag |
| `lib/features/car/presentation/car_place_picker_screen.dart` | Atomic draft, confirm fix, map guards, search-only layout |
| `lib/features/car/presentation/car_search_form.dart` | `@visibleForTesting` initial places for widget tests |
| `test/features/car/presentation/car_place_picker_screen_test.dart` | Picker coord authority + search-only tests |
| `test/features/car/presentation/car_search_form_test.dart` | Distinct-coords search proceeds |
| `test/core/places/google_maps_capabilities_test.dart` | Capability helper unit tests |

---

### Task 1: Google Maps capabilities helper

**Files:**
- Create: `lib/core/places/google_maps_capabilities.dart`
- Create: `test/core/places/google_maps_capabilities_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/core/places/google_maps_capabilities_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rego/core/places/google_maps_capabilities.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: File('.env.example').readAsStringSync());
  });

  tearDown(GoogleMapsCapabilities.resetSessionForTesting);

  test('mapRenderingAvailable defaults true when key configured', () {
    expect(GoogleMapsCapabilities.mapRenderingAvailable, isTrue);
  });

  test('markMapUnavailable disables map rendering for session', () {
    GoogleMapsCapabilities.markMapUnavailable();
    expect(GoogleMapsCapabilities.mapRenderingAvailable, isFalse);
    expect(GoogleMapsCapabilities.placesAvailable, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/places/google_maps_capabilities_test.dart`
Expected: FAIL — `GoogleMapsCapabilities` not defined.

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/places/google_maps_capabilities.dart`:

```dart
import 'package:flutter/foundation.dart';

import 'package:rego/core/config/app_config.dart';

/// Tracks which Google APIs are usable on the current key.
///
/// v1 uses one env key; [mapRenderingAvailable] can flip false at runtime
/// when Maps SDK tiles fail to load (Places/Geocoding may still work).
abstract final class GoogleMapsCapabilities {
  static bool _sessionMapRenderingAvailable = true;

  static bool get placesAvailable => AppConfig.isGoogleMapsConfigured;

  static bool get mapRenderingAvailable =>
      placesAvailable && _sessionMapRenderingAvailable;

  static void markMapUnavailable() {
    _sessionMapRenderingAvailable = false;
  }

  @visibleForTesting
  static void setMapRenderingAvailableForTesting(bool value) {
    _sessionMapRenderingAvailable = value;
  }

  @visibleForTesting
  static void resetSessionForTesting() {
    _sessionMapRenderingAvailable = true;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/places/google_maps_capabilities_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/places/google_maps_capabilities.dart test/core/places/google_maps_capabilities_test.dart
git commit -m "feat(car): add Google Maps capability session helper"
```

---

### Task 2: Confirm returns autocomplete coords (picker TDD)

**Files:**
- Modify: `test/features/car/presentation/car_place_picker_screen_test.dart`
- Modify: `lib/features/car/presentation/car_place_picker_screen.dart`

- [ ] **Step 1: Add failing test — confirm after autocomplete**

In `test/features/car/presentation/car_place_picker_screen_test.dart`, add `tearDown`:

```dart
  tearDown(GoogleMapsCapabilities.resetSessionForTesting);
```

Add import:

```dart
import 'package:rego/core/places/google_maps_capabilities.dart';
```

Add new test after `selecting a prediction updates draft label`:

```dart
  testWidgets('confirm after autocomplete returns placeDetails coords',
      (tester) async {
    CarPlace? result;

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await context.push<CarPlace>(
                    CarRoutes.placePicker,
                    extra: const CarPlacePickerArgs(title: 'Drop-off'),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
          routes: [
            GoRoute(
              path: CarRoutes.placePicker.substring(1),
              builder: (context, state) => CarPlacePickerScreen(
                args: state.extra! as CarPlacePickerArgs,
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placesClientProvider.overrideWithValue(_FakePlacesClient()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField), 'Cai');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.tap(find.text('Cairo Tower, Egypt'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.latitude, closeTo(30.045, 0.001));
    expect(result!.longitude, closeTo(31.224, 0.001));
    expect(result!.label, 'Cairo Tower, Egypt');
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/car/presentation/car_place_picker_screen_test.dart --plain-name "confirm after autocomplete"`
Expected: FAIL — `latitude` is `30.0444` (Cairo default from `_center`), not `30.045`.

- [ ] **Step 3: Implement atomic draft helpers and confirm fix**

In `lib/features/car/presentation/car_place_picker_screen.dart`:

**3a.** Add import:

```dart
import 'package:rego/core/places/google_maps_capabilities.dart';
```

**3b.** Add state fields after `_locating`:

```dart
  int _draftVersion = 0;
  bool _ignoreMapEvents = false;
  int _animateVersionSnapshot = 0;
  bool _mapCreated = false;
  Timer? _mapCreateTimeout;
```

**3c.** Add `_setDraft` helper before `_reverseGeocode`:

```dart
  void _setDraft(CarPlace place) {
    setState(() {
      _draft = place;
      _draftVersion++;
      _center = LatLng(place.latitude, place.longitude);
    });
  }
```

**3d.** Replace `_reverseGeocode` body so it uses `_setDraft` and respects map guards:

```dart
  Future<void> _reverseGeocode() async {
    if (_ignoreMapEvents) return;
    final client = ref.read(placesClientProvider);
    if (!client.isConfigured) return;
    final locale = Localizations.localeOf(context).languageCode;
    final versionAtStart = _draftVersion;
    try {
      final place = await client.reverseGeocode(
        latitude: _center.latitude,
        longitude: _center.longitude,
        languageCode: locale,
      );
      if (!mounted || _ignoreMapEvents || versionAtStart != _draftVersion) {
        return;
      }
      _setDraft(place);
    } catch (_) {
      if (!mounted || _ignoreMapEvents || versionAtStart != _draftVersion) {
        return;
      }
      _setDraft(
        CarPlace(
          latitude: _center.latitude,
          longitude: _center.longitude,
          label: '',
        ),
      );
    }
  }
```

**3e.** Guard `_onCameraIdle`:

```dart
  void _onCameraIdle() {
    if (_ignoreMapEvents || !GoogleMapsCapabilities.mapRenderingAvailable) {
      return;
    }
    _geocodeDebounce?.cancel();
    _geocodeDebounce =
        Timer(const Duration(milliseconds: 400), _reverseGeocode);
  }
```

**3f.** Update `_selectPrediction` to call `_setDraft(place)` instead of manual setState:

```dart
      setState(() {
        _predictions = [];
      });
      _setDraft(place);
      if (GoogleMapsCapabilities.mapRenderingAvailable) {
        await _animateTo(LatLng(place.latitude, place.longitude));
      }
```

**3g.** Update `_centerOnMyLocation` to set draft coords immediately:

```dart
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final gps = LatLng(position.latitude, position.longitude);
      _center = gps;
      _setDraft(
        CarPlace(
          latitude: gps.latitude,
          longitude: gps.longitude,
          label: _draft?.label ?? '',
        ),
      );
      if (GoogleMapsCapabilities.mapRenderingAvailable) {
        await _animateTo(gps);
      }
      await _reverseGeocode();
```

**3h.** Replace `_confirm` with async flush + pop draft:

```dart
  Future<void> _confirm() async {
    final draft = _draft;
    if (draft == null) return;
    await _flushPendingGeocode();
    if (!mounted || _draft == null) return;
    context.pop(_draft!);
  }

  Future<void> _flushPendingGeocode() async {
    _geocodeDebounce?.cancel();
    _geocodeDebounce = null;
    if (_ignoreMapEvents) return;
    final completer = Completer<void>();
    final timer = Timer(const Duration(milliseconds: 500), () {
      if (!completer.isCompleted) completer.complete();
    });
    try {
      await _reverseGeocode();
    } finally {
      timer.cancel();
      if (!completer.isCompleted) completer.complete();
      await completer.future;
    }
  }
```

**3i.** Update `_PickerPanel` `onConfirm` type if needed — it already takes `VoidCallback`; change to pass `() => unawaited(_confirm())` at call sites, or keep `_confirm` sync wrapper:

```dart
  void _onConfirmPressed() => unawaited(_confirm());
```

Use `_onConfirmPressed` in `_PickerPanel(onConfirm: _onConfirmPressed)`.

**3j.** In `initState`, cancel map timeout in dispose:

```dart
    _mapCreateTimeout?.cancel();
```

Add to `dispose()`:

```dart
    _mapCreateTimeout?.cancel();
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/car/presentation/car_place_picker_screen_test.dart --plain-name "confirm after autocomplete"`
Expected: PASS.

- [ ] **Step 5: Fix existing `confirm returns CarPlace` test expectation**

The bare-confirm test (no autocomplete) should still return Cairo default coords from `_draft`. No change needed if `_draft` is initialized to Cairo in `initState`. Re-run full picker test file:

Run: `flutter test test/features/car/presentation/car_place_picker_screen_test.dart`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/car/presentation/car_place_picker_screen.dart test/features/car/presentation/car_place_picker_screen_test.dart
git commit -m "fix(car): confirm picker returns atomic draft coordinates"
```

---

### Task 3: Map animation guards (stale camera events)

**Files:**
- Modify: `lib/features/car/presentation/car_place_picker_screen.dart`
- Modify: `test/features/car/presentation/car_place_picker_screen_test.dart`

- [ ] **Step 1: Update `_animateTo` with ignore flag**

Replace `_animateTo`:

```dart
  Future<void> _animateTo(LatLng target) async {
    if (!GoogleMapsCapabilities.mapRenderingAvailable) return;
    _ignoreMapEvents = true;
    _animateVersionSnapshot = _draftVersion;
    _center = target;
    try {
      await _mapController
          ?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: target, zoom: 15),
            ),
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Map unavailable or animation failed — draft coords already set.
    } finally {
      if (mounted) {
        setState(() => _ignoreMapEvents = false);
      }
    }
  }
```

- [ ] **Step 2: Guard `onCameraMove` in build**

Change `onCameraMove` callback:

```dart
      onCameraMove: (position) {
        if (!_ignoreMapEvents) {
          _center = position.target;
        }
      },
```

- [ ] **Step 3: Run picker tests**

Run: `flutter test test/features/car/presentation/car_place_picker_screen_test.dart`
Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/car/presentation/car_place_picker_screen.dart
git commit -m "fix(car): ignore stale map camera events during animateTo"
```

---

### Task 4: Search-only mode when map unavailable

**Files:**
- Modify: `lib/features/car/presentation/car_place_picker_screen.dart`
- Modify: `test/features/car/presentation/car_place_picker_screen_test.dart`

- [ ] **Step 1: Add failing test — search-only hides GoogleMap**

Add to `car_place_picker_screen_test.dart`:

```dart
  testWidgets('search-only mode hides map and confirm still works',
      (tester) async {
    GoogleMapsCapabilities.setMapRenderingAvailableForTesting(false);
    CarPlace? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placesClientProvider.overrideWithValue(_FakePlacesClient()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: CarPlacePickerScreen(
            args: const CarPlacePickerArgs(title: 'Drop-off'),
            onPickedForTest: (place) => result = place,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(GoogleMap), findsNothing);

    await tester.enterText(find.byType(TextField), 'Cai');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.tap(find.text('Cairo Tower, Egypt'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.latitude, closeTo(30.045, 0.001));
  });
```

**Note:** `onPickedForTest` is added in Step 3 below — a `@visibleForTesting` optional callback on `CarPlacePickerScreen` that `_confirm` invokes before `context.pop` when non-null (test-only shortcut avoiding go_router).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/car/presentation/car_place_picker_screen_test.dart --plain-name "search-only"`
Expected: FAIL — `GoogleMap` still in tree / `onPickedForTest` missing.

- [ ] **Step 3: Implement search-only layout + map timeout**

**3a.** Add optional test callback to `CarPlacePickerScreen`:

```dart
class CarPlacePickerScreen extends ConsumerStatefulWidget {
  const CarPlacePickerScreen({
    super.key,
    required this.args,
    @visibleForTesting this.onPickedForTest,
  });

  final CarPlacePickerArgs args;
  final void Function(CarPlace place)? onPickedForTest;
```

**3b.** In `_confirm`, before pop:

```dart
    widget.onPickedForTest?.call(_draft!);
    if (!mounted) return;
    context.pop(_draft!);
```

**3c.** In `initState` post-frame callback, start map create timeout when map should render:

```dart
    if (GoogleMapsCapabilities.mapRenderingAvailable) {
      _mapCreateTimeout = Timer(const Duration(seconds: 3), () {
        if (!mounted || _mapCreated) return;
        GoogleMapsCapabilities.markMapUnavailable();
        setState(() {});
      });
    }
```

**3d.** Add `_onMapCreated`:

```dart
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapCreated = true;
    _mapCreateTimeout?.cancel();
  }
```

**3e.** In `build`, conditionally include map layer:

```dart
    final showMap = GoogleMapsCapabilities.mapRenderingAvailable;

    // ... inside Stack children:
    if (showMap) ...[
      mapLayer,
      const _CenterPin(),
      if (widget.args.showUseMyLocation)
        PositionedDirectional(
          end: AppSpacing.md,
          bottom: MediaQuery.sizeOf(context).height * _sheetPeek + AppSpacing.md,
          child: _GpsFab(
            loading: _locating,
            onTap: () => unawaited(_centerOnMyLocation()),
          ),
        ),
    ],
```

When `!showMap`, use a full-screen `_PickerPanel` (portrait) or expanded panel (landscape) without `DraggableScrollableSheet` over a map — simplest: set sheet to full height:

```dart
    if (!showMap) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: AppBar(
          leading: const AuthBackButton(),
          title: Text(widget.args.title),
        ),
        body: SafeArea(
          child: panel, // reuse _PickerPanel without scrollController
        ),
      );
    }
```

Extract `panel` construction so both branches share it. Pass `showDragHandle: showMap` to `_PickerPanel`.

Wire `onMapCreated: _onMapCreated` in `_MapLayer`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/car/presentation/car_place_picker_screen_test.dart --plain-name "search-only"`
Expected: PASS.

- [ ] **Step 5: Run all picker tests**

Run: `flutter test test/features/car/presentation/car_place_picker_screen_test.dart`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/car/presentation/car_place_picker_screen.dart test/features/car/presentation/car_place_picker_screen_test.dart
git commit -m "feat(car): search-only place picker when map tiles unavailable"
```

---

### Task 5: CarSearchForm distinct-coords validation test

**Files:**
- Modify: `lib/features/car/presentation/car_search_form.dart`
- Modify: `test/features/car/presentation/car_search_form_test.dart`

- [ ] **Step 1: Add test-only initial places to CarSearchForm**

In `car_search_form.dart`, add optional params:

```dart
class CarSearchForm extends ConsumerStatefulWidget {
  const CarSearchForm({
    super.key,
    @visibleForTesting this.initialFrom,
    @visibleForTesting this.initialTo,
  });

  @visibleForTesting
  final CarPlace? initialFrom;
  @visibleForTesting
  final CarPlace? initialTo;
```

In `_CarSearchFormState.initState` (add `initState`):

```dart
  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom;
    _to = widget.initialTo;
  }
```

- [ ] **Step 2: Write failing test**

Add to `car_search_form_test.dart`:

```dart
  testWidgets('search proceeds when pickup and drop-off differ', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carRepositoryProvider.overrideWithValue(FakeCarRepository()),
          placesClientProvider.overrideWithValue(_FakePlacesClient()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CarSearchForm(
                initialFrom: CarPlace(
                  latitude: 30.0626,
                  longitude: 31.3219,
                  label: 'Nasr City, Cairo',
                ),
                initialTo: CarPlace(
                  latitude: 31.2001,
                  longitude: 29.9187,
                  label: 'Alexandria',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Request a car'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Pickup and drop-off must be different'), findsNothing);
    expect(find.text('Select pickup and drop-off'), findsNothing);
  });
```

Use the actual English string for `carSearchSamePlace` from `app_en.arb` — check key:

```bash
rg "carSearchSamePlace" lib/l10n/app_en.arb
```

Replace assertion text with the exact localized English string if different (expected: `Pickup and drop-off must be different`).

- [ ] **Step 3: Run test**

Run: `flutter test test/features/car/presentation/car_search_form_test.dart`
Expected: PASS (picker fix is already in; this guards regression).

- [ ] **Step 4: Commit**

```bash
git add lib/features/car/presentation/car_search_form.dart test/features/car/presentation/car_search_form_test.dart
git commit -m "test(car): search form accepts distinct pickup and drop-off coords"
```

---

### Task 6: Final verification

**Files:** (none — verification only)

- [ ] **Step 1: Run analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Run car test suite**

Run: `flutter test test/features/car/ test/core/places/google_maps_capabilities_test.dart`
Expected: all PASS.

- [ ] **Step 3: Manual smoke test**

1. Open Private tab → set pickup via search (Nasr City) → set drop-off (Alexandria) → tap Request a car.
2. Confirm no `carSearchSamePlace` snackbar.
3. If Maps SDK disabled on key: picker should show search-only (no grey map); confirm still works.

- [ ] **Step 4: Commit spec status update (optional)**

Update `docs/superpowers/specs/2026-07-23-car-place-coordinate-fix-design.md` status line to `Approved`.

```bash
git add docs/superpowers/specs/2026-07-23-car-place-coordinate-fix-design.md
git commit -m "docs: mark car place coordinate fix spec approved"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Atomic `_draft` on confirm | Task 2 |
| Last-write-wins (`_draftVersion`) | Task 2, 3 |
| `_ignoreMapEvents` during animate | Task 3 |
| `_flushPendingGeocode` on confirm | Task 2 |
| `GoogleMapsCapabilities` helper | Task 1 |
| Search-only when map unavailable | Task 4 |
| Pickup GPS without map | Task 4 (GPS FAB in search-only scaffold) |
| Validation unchanged in form | Task 5 (regression test) |
| Error handling (placeDetails fail) | Existing code unchanged — verify manually |

## Success criteria

1. QA repro (Nasr City + Alexandria) no longer shows `carSearchSamePlace`.
2. `confirm after autocomplete` test passes with `placeDetails` coords.
3. Search-only mode works without `GoogleMap` in widget tree.
4. `flutter analyze` clean; car tests pass.
