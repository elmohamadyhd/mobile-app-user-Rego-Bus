# Private Saved Addresses Strip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On Home Private tab, show a horizontal strip of saved addresses that fills car drop-off on tap; hide when guest/empty/loading/error.

**Architecture:** Mirror bus `PopularDestinations`. New `SavedAddressesStrip` on Home watches `addressesProvider` + `guestModeProvider`. `HomeScreen` coordinates `CarPlace` from/to with `HomeSearchCard` → `CarSearchForm`.

**Tech Stack:** Flutter, Riverpod, existing `addressesProvider`, `CarPlace`/`MapPlace`, ARB l10n, Phosphor icons, design tokens.

## Global Constraints

- Arabic-first RTL; all strings via `AppLocalizations`; keys in both ARB files
- Design tokens only (`AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`)
- Icons: `PhosphorIconsLight.*`
- Package imports (`package:safaria/...`)
- Hide strip for guest / loading / error / empty (no CTA)
- Tap fills drop-off only; dim when same coordinates as pickup
- No commits unless the user explicitly requests them

## File Structure

| File | Responsibility |
|------|----------------|
| `lib/features/home/presentation/widgets/saved_addresses_strip.dart` | Horizontal address cards + hide rules |
| `lib/features/home/presentation/home_screen.dart` | Private-tab visibility + from/to coordination |
| `lib/features/home/presentation/widgets/home_search_card.dart` | Pass car place props into `CarSearchForm` |
| `lib/features/car/presentation/car_search_form.dart` | Accept controlled `toPlace` + from/to callbacks |
| `lib/l10n/app_en.arb` / `app_ar.arb` | `homeSavedAddresses` (+ swipe hint) |
| `test/features/home/presentation/saved_addresses_strip_test.dart` | Widget tests |

---

### Task 1: l10n keys

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ar.arb`

**Interfaces:**
- Produces: `AppLocalizations.homeSavedAddresses`, `homeSavedAddressesSwipeHint`

- [ ] **Step 1: Add EN keys** after `homePopularDestinationsSwipeHint`:

```json
  "homeSavedAddresses": "Saved addresses",
  "@homeSavedAddresses": {
    "description": "Home section title for saved addresses on the Private tab."
  },
  "homeSavedAddressesSwipeHint": "Swipe to see more addresses",
  "@homeSavedAddressesSwipeHint": {
    "description": "Accessibility hint that the saved addresses row scrolls horizontally."
  },
```

- [ ] **Step 2: Add AR keys** after `homePopularDestinationsSwipeHint`:

```json
  "homeSavedAddresses": "العناوين المحفوظة",
  "homeSavedAddressesSwipeHint": "اسحب لعرض المزيد من العناوين",
```

- [ ] **Step 3: Generate l10n**

Run: `flutter gen-l10n`

Expected: succeeds; getters exist on `AppLocalizations`

---

### Task 2: `SavedAddressesStrip` + tests (TDD)

**Files:**
- Create: `lib/features/home/presentation/widgets/saved_addresses_strip.dart`
- Create: `test/features/home/presentation/saved_addresses_strip_test.dart`

**Interfaces:**
- Consumes: `addressesProvider`, `guestModeProvider`, `SavedAddress`, `CarPlace`/`MapPlace.sameCoordinates`
- Produces:

```dart
class SavedAddressesStrip extends ConsumerWidget {
  const SavedAddressesStrip({
    super.key,
    required this.visible,
    this.excludePlace,
    required this.onSelected,
  });
  final bool visible;
  final CarPlace? excludePlace;
  final ValueChanged<CarPlace> onSelected;
}
```

- [ ] **Step 1: Write failing tests** in
  `test/features/home/presentation/saved_addresses_strip_test.dart`

Use a `_FakeAddressesNotifier` like addresses screen tests, and override
`guestModeProvider` with `AsyncData(false)` (and `true` for guest test).

```dart
testWidgets('renders nothing when not visible', ...);
testWidgets('renders nothing when guest', ...);
testWidgets('renders nothing when address list empty', ...);
testWidgets('lists address names when visible', ...);
testWidgets('tap selects place; same as exclude is ignored', ...);
```

Sample data:

```dart
const home = SavedAddress(
  id: 1,
  name: 'Home',
  mapLocation: MapLocation(
    latitude: 30.0444,
    longitude: 31.2357,
    addressName: '123 Nile Street, Cairo',
  ),
);
const work = SavedAddress(
  id: 2,
  name: 'Work',
  mapLocation: MapLocation(
    latitude: 30.06,
    longitude: 31.22,
    addressName: '456 Corniche, Cairo',
  ),
);
```

Tap test: `excludePlace` = Home coordinates → tap Home does nothing; tap Work
adds `CarPlace` with Work lat/lng and `label: addressName`.

- [ ] **Step 2: Run tests — expect FAIL** (widget missing)

Run: `flutter test test/features/home/presentation/saved_addresses_strip_test.dart`

- [ ] **Step 3: Implement `SavedAddressesStrip`**

Logic:
1. If `!visible` → shrink
2. If `guestModeProvider` is true (or still loading as guest-unknown: treat
   `value == true` as guest; if `AsyncLoading`/`error` on guest, prefer
   `valueOrNull ?? false` only when we know signed-in — **spec:** guest hides.
   Use: `final isGuest = ref.watch(guestModeProvider).value ?? false;` then if
   `isGuest` shrink. Do not fetch-driven UI for guests.
3. Watch `addressesProvider`; loading/error/empty `items` → shrink
4. Horizontal list like `popular_destinations.dart` with title + subtitle
5. Map on tap:

```dart
CarPlace(
  latitude: a.mapLocation.latitude,
  longitude: a.mapLocation.longitude,
  label: a.mapLocation.addressName,
);
```

6. Disable when `excludePlace?.sameCoordinates(place) == true`

Import `AppRadius` from `package:safaria/core/theme/app_spacing.dart`.

- [ ] **Step 4: Run tests — expect PASS**

Run: `flutter test test/features/home/presentation/saved_addresses_strip_test.dart`

---

### Task 3: Wire `CarSearchForm` controlled drop-off

**Files:**
- Modify: `lib/features/car/presentation/car_search_form.dart`
- Modify: `lib/features/home/presentation/widgets/home_search_card.dart`
- Modify: `lib/features/home/presentation/home_screen.dart`

**Interfaces:**
- Produces on `CarSearchForm`:

```dart
final CarPlace? toPlace;
final ValueChanged<CarPlace?>? onToPlaceChanged;
final ValueChanged<CarPlace?>? onFromPlaceChanged;
```

- [ ] **Step 1: Extend `CarSearchForm`**

- Add optional `toPlace`, `onToPlaceChanged`, `onFromPlaceChanged`
- `didUpdateWidget`: if `widget.toPlace != oldWidget.toPlace` and not same
  coordinates as `_to`, `setState(() => _to = widget.toPlace)`
- Whenever `_to` changes from UI, call `onToPlaceChanged`
- Whenever `_from` changes (picker, swap, GPS prefill), call `onFromPlaceChanged`
- On `initState` post-frame, notify current from/to like bus search card

- [ ] **Step 2: Extend `HomeSearchCard`**

```dart
final CarPlace? toPlace;
final ValueChanged<CarPlace?>? onToPlaceChanged;
final ValueChanged<CarPlace?>? onFromPlaceChanged;
```

Pass through to `CarSearchForm` when private tab:

```dart
CarSearchForm(
  toPlace: widget.toPlace,
  onToPlaceChanged: widget.onToPlaceChanged,
  onFromPlaceChanged: widget.onFromPlaceChanged,
)
```

- [ ] **Step 3: Wire `HomeScreen`**

```dart
CarPlace? _carFrom;
CarPlace? _carTo;
```

```dart
HomeSearchCard(
  ...
  toPlace: _carTo,
  onFromPlaceChanged: (p) => setState(() => _carFrom = p),
  onToPlaceChanged: (p) => setState(() => _carTo = p),
),
PopularDestinations(...),
SavedAddressesStrip(
  visible: _transportTab == TransportModeTabBar.privateTabIndex,
  excludePlace: _carFrom,
  onSelected: (place) {
    if (_carFrom != null && place.sameCoordinates(_carFrom!)) return;
    setState(() => _carTo = place);
  },
),
```

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/features/home lib/features/car/presentation/car_search_form.dart`

Expected: no issues in touched files

---

### Task 4: Verify

- [ ] **Step 1: Run strip + related home tests**

```bash
flutter test test/features/home/presentation/saved_addresses_strip_test.dart test/features/home/presentation/popular_destinations_test.dart
```

Expected: all PASS

- [ ] **Step 2: Spec compliance check**

Confirm: Private-only, addresses only, drop-off on tap, hide guest/empty/loading/error, dim same-as-pickup, l10n key `homeSavedAddresses`, no See all.
