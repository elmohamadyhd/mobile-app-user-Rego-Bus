# Phosphor Icons Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Tabler + `AppIcons` with Phosphor Light icons used directly in every UI call site.

**Architecture:** Add `phosphor_flutter`, remap all former `AppIcons.*` usages to `PhosphorIconsLight.*` per the approved glyph map, delete `app_icons.dart`, remove `tabler_icons_plus`, update Cursor icon rules.

**Tech Stack:** Flutter, `phosphoricons_flutter`, existing Riverpod/go_router app (`package:safaria`)

**Spec:** `docs/superpowers/specs/2026-07-29-phosphor-icons-migration-design.md`

## Global Constraints

- Default weight: **only** `PhosphorIconsLight` in app UI.
- No `AppIcons`, no `TablerIcons`, no Material icons for chrome/amenities.
- Brand SVGs unchanged.
- Use `./tool/pub-get.ps1` (Windows) after pubspec changes — not bare `flutter pub get`.
- Do not commit unless the user explicitly asks.
- Glyph map is authoritative (see Task 1 table / spec).

---

## File structure (touched)

| Path | Role |
|------|------|
| `pubspec.yaml` | Swap deps |
| `lib/core/theme/app_icons.dart` | Delete after migration |
| `lib/features/**`, `lib/shared/**` | Direct Phosphor imports |
| `lib/features/bus/presentation/widgets/amenity_icon.dart` | Mapper → Phosphor Light |
| `.cursor/rules/ai-behavior.mdc` | Icon rule update |
| `test/**` | IconData assertions |

---

### Task 1: Dependency + amenity mapper + rule

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/features/bus/presentation/widgets/amenity_icon.dart`
- Modify: `.cursor/rules/ai-behavior.mdc`
- Keep temporarily: `lib/core/theme/app_icons.dart` (deleted in Task 6)

**Interfaces:**
- Produces: `IconData amenityIconFor(String amenity)` returning Phosphor Light icons
- Glyph map (use exactly):

| Former | Phosphor Light |
|--------|----------------|
| mail | envelopeSimple |
| lock | lock |
| eye | eye |
| eyeOff | eyeSlash |
| user | user |
| phone | phone |
| shield | shieldCheck |
| back | caretLeft |
| forward | caretRight |
| chevronDown | caretDown |
| close | x |
| check | check |
| bell | bell |
| bus | bus |
| busFront / gear | steeringWheel |
| photo | image |
| camera | camera |
| private | diamond |
| flight | airplane |
| transfer | car |
| train | train |
| locationFrom | crosshair |
| locationTo | mapPin |
| map | mapTrifold |
| swap | arrowsDownUp |
| seats | users |
| luggage | briefcase |
| wallet | wallet |
| walletDeposit | arrowDownLeft |
| walletWithdraw | arrowUpRight |
| ticket | ticket |
| search | magnifyingGlass |
| home | house |
| calendar | calendarBlank |
| filter | fadersHorizontal |
| error | warningCircle |
| star | star |
| amenityWifi | wifiHigh |
| amenityAC | wind |
| amenitySockets | plug |
| amenityWc | toilet |
| add / plus | plus |
| edit | pencilSimple |
| download | downloadSimple |
| share | shareNetwork |
| checkCircle | checkCircle |
| logout | signOut |
| language | translate |
| settings | gearSix |
| help | question |

- [ ] **Step 1: Update pubspec**

In `pubspec.yaml`, under `dependencies:`:
- Remove: `tabler_icons_plus: ^3.44.0`
- Add: `phosphor_flutter: ^2.1.0` (or latest compatible 2.x from pub.dev)

- [ ] **Step 2: Install deps**

Run (Windows):

```powershell
.\tool\pub-get.ps1
```

Expected: resolves `phosphor_flutter`, no `tabler_icons_plus`.

- [ ] **Step 3: Verify Phosphor API names**

Quick check that map names exist (adjust only if analyzer fails later):

```powershell
rg "toilet|wifiHigh|wind|steeringWheel|envelopeSimple|magnifyingGlass|fadersHorizontal|gearSix|mapTrifold|calendarBlank" "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\phosphor_flutter-*\lib" -g "*.dart" -m 20
```

- [ ] **Step 4: Rewrite `amenity_icon.dart`**

Replace file contents with:

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Maps a free-text amenity label to a Phosphor Light icon.
IconData amenityIconFor(String amenity) {
  final s = amenity.toLowerCase();
  if (s.contains('wifi') || s.contains('wi-fi') || s.contains('واي')) {
    return PhosphorIconsLight.wifiHigh;
  }
  if (s.contains('a/c') ||
      s.contains('air') ||
      s.contains('تكييف') ||
      s.contains('مكي')) {
    return PhosphorIconsLight.wind;
  }
  if (s.contains('sock') ||
      s.contains('plug') ||
      s.contains('power') ||
      s.contains('كهرب') ||
      s.contains('شحن')) {
    return PhosphorIconsLight.plug;
  }
  if (s.contains('wc') ||
      s.contains('w.c') ||
      s.contains('toilet') ||
      s.contains('bath') ||
      s.contains('restroom') ||
      s.contains('water') ||
      s.contains('مياه') ||
      s.contains('ماء') ||
      s.contains('حمام') ||
      s.contains('مرحاض')) {
    return PhosphorIconsLight.toilet;
  }
  return PhosphorIconsLight.check;
}
```

- [ ] **Step 5: Update Cursor rule**

In `.cursor/rules/ai-behavior.mdc`, replace the Icons bullet with:

```markdown
- **Icons:** Use `PhosphorIconsLight.*` from `package:phosphor_flutter/phosphor_flutter.dart` for every UI icon — never `AppIcons`, Tabler, or Material `Icons.*` for chrome/amenities. Keep stroke weight Light unless a future spec explicitly allows Fill for selected states.
```

- [ ] **Step 6: Analyze amenity mapper**

Run:

```powershell
flutter analyze lib/features/bus/presentation/widgets/amenity_icon.dart
```

Expected: No issues. If a glyph name is wrong, fix against pub cache and update the spec map.

---

### Task 2: Shared + shell + home icons

**Files:**
- Modify: `lib/shared/widgets/transport_mode_tab_bar.dart`
- Modify: `lib/shared/widgets/skyline_tab_hero.dart`
- Modify: `lib/shared/widgets/language_icon_button.dart`
- Modify: `lib/shared/widgets/language_picker_sheet.dart`
- Modify: `lib/shared/widgets/map_place_picker_screen.dart`
- Modify: `lib/features/shell/presentation/widgets/main_nav_bar.dart`
- Modify: `lib/features/home/presentation/widgets/home_search_card.dart`
- Modify: `lib/features/home/presentation/widgets/home_flight_class_picker.dart`

**Interfaces:**
- Consumes: glyph map from Task 1

- [ ] **Step 1: Replace imports and icons in each file**

For each file:
1. Remove `import 'package:safaria/core/theme/app_icons.dart';`
2. Add `import 'package:phosphor_flutter/phosphor_flutter.dart';`
3. Replace every `AppIcons.X` with the Phosphor Light equivalent from the map

Examples:

```dart
// transport_mode_tab_bar.dart
(l10n.homeTabBus, PhosphorIconsLight.bus),
(l10n.homeTabPrivate, PhosphorIconsLight.diamond),
(l10n.homeTabFlight, PhosphorIconsLight.airplane),
(l10n.homeTabTrain, PhosphorIconsLight.train),

// main_nav_bar.dart
(PhosphorIconsLight.house, l10n.navHome),
(PhosphorIconsLight.ticket, l10n.navTickets),
(PhosphorIconsLight.user, l10n.navProfile),
```

- [ ] **Step 2: Analyze touched shared/home/shell**

```powershell
flutter analyze lib/shared lib/features/shell lib/features/home
```

Expected: No issues related to icons.

---

### Task 3: Auth + profile + addresses + wallet

**Files:**
- Modify all under:
  - `lib/features/auth/presentation/**`
  - `lib/features/profile/presentation/**`
  - `lib/features/addresses/presentation/**`
  - `lib/features/wallet/presentation/**`

**Interfaces:**
- Consumes: glyph map from Task 1

- [ ] **Step 1: Bulk-replace per feature folder**

Same pattern as Task 2. Critical mappings:

```dart
AppIcons.back → PhosphorIconsLight.caretLeft
AppIcons.eye / eyeOff → eye / eyeSlash
AppIcons.mail → envelopeSimple
AppIcons.language → translate
AppIcons.settings → gearSix
AppIcons.help → question
AppIcons.logout → signOut
AppIcons.walletDeposit → arrowDownLeft
AppIcons.walletWithdraw → arrowUpRight
AppIcons.add / plus → plus
AppIcons.edit → pencilSimple
AppIcons.shield → shieldCheck
AppIcons.photo → image
```

Keep existing `Transform.flip` on back buttons (e.g. `auth_back_button.dart`).

- [ ] **Step 2: Analyze**

```powershell
flutter analyze lib/features/auth lib/features/profile lib/features/addresses lib/features/wallet
```

Expected: No issues.

---

### Task 4: Bus feature icons

**Files:**
- Modify all `lib/features/bus/presentation/**` that reference `AppIcons` (screens + widgets), including:
  - `trip_card.dart`, `seat_grid.dart`, `trip_details_screen.dart`, `trip_results_screen.dart`, `seat_selection_screen.dart`, `eticket_screen.dart`, `passenger_confirm_screen.dart`, booking chrome, order cards/sheets, FABs, filters, etc.

**Interfaces:**
- Consumes: `amenityIconFor` (already Phosphor) + glyph map

- [ ] **Step 1: Replace AppIcons in bus presentation**

Special cases:

```dart
// seat_grid.dart markers
PhosphorIconsLight.steeringWheel  // driver
PhosphorIconsLight.signOut        // door (was logout)
PhosphorIconsLight.toilet         // WC

// trip_card stops chevron / pin
PhosphorIconsLight.caretDown
PhosphorIconsLight.mapPin
```

- [ ] **Step 2: Analyze bus**

```powershell
flutter analyze lib/features/bus
```

Expected: No issues.

---

### Task 5: Car feature icons

**Files:**
- Modify all `lib/features/car/presentation/**` referencing `AppIcons`

**Interfaces:**
- Consumes: glyph map from Task 1

- [ ] **Step 1: Replace AppIcons in car presentation**

```dart
AppIcons.transfer → PhosphorIconsLight.car
AppIcons.seats → PhosphorIconsLight.users
AppIcons.luggage → PhosphorIconsLight.briefcase
AppIcons.gear → PhosphorIconsLight.steeringWheel
AppIcons.locationFrom → PhosphorIconsLight.crosshair
AppIcons.locationTo → PhosphorIconsLight.mapPin
AppIcons.swap → PhosphorIconsLight.arrowsDownUp
```

- [ ] **Step 2: Analyze car**

```powershell
flutter analyze lib/features/car
```

Expected: No issues.

---

### Task 6: Delete facade + fix tests + grep gate

**Files:**
- Delete: `lib/core/theme/app_icons.dart`
- Modify: any `test/**` files importing `app_icons.dart` or asserting `AppIcons.*`
  - Known: `test/features/bus/presentation/trip_results_screen_test.dart`
  - `test/features/bus/presentation/trip_details_screen_test.dart`
  - `test/features/bus/presentation/seat_grid_test.dart`
  - `test/features/bus/presentation/seat_selection_screen_test.dart`
  - `test/features/bus/presentation/widgets/trip_filter_button_test.dart`
  - `test/features/car/presentation/car_place_picker_screen_test.dart`
  - `test/features/car/presentation/widgets/car_tier_card_test.dart`
  - `test/shared/widgets/language_picker_sheet_test.dart`
  - `test/features/auth/onboarding_screen_test.dart`
  - `test/features/auth/login_screen_test.dart`

- [ ] **Step 1: Find remaining AppIcons / Tabler references**

```powershell
rg "AppIcons|tabler_icons|TablerIcons|app_icons" lib test -g "*.dart"
```

Expected: only hits that you are about to fix (or none).

- [ ] **Step 2: Update tests**

Replace `AppIcons.X` assertions with `PhosphorIconsLight.X` equivalents; add phosphor import; remove app_icons import.

Example pattern:

```dart
expect(find.byIcon(PhosphorIconsLight.fadersHorizontal), findsOneWidget);
```

- [ ] **Step 3: Delete `lib/core/theme/app_icons.dart`**

- [ ] **Step 4: Full analyze + focused tests**

```powershell
flutter analyze
flutter test test/features/bus/presentation/seat_grid_test.dart test/features/bus/presentation/trip_card_test.dart test/features/bus/presentation/widgets/trip_filter_button_test.dart test/shared/widgets/language_picker_sheet_test.dart test/features/auth/login_screen_test.dart test/features/car/presentation/widgets/car_tier_card_test.dart
```

Expected: analyze clean; listed tests pass.

- [ ] **Step 5: Final grep gate**

```powershell
rg "AppIcons|tabler_icons|TablerIcons|app_icons\.dart" lib test -g "*.dart"
rg "PhosphorIconsRegular|PhosphorIconsBold|PhosphorIconsFill|PhosphorIconsDuotone" lib -g "*.dart"
```

Expected: no matches.

---

## Spec coverage (self-review)

| Spec requirement | Task |
|------------------|------|
| Add phosphor_flutter / remove tabler | Task 1 |
| Direct PhosphorIconsLight usage | Tasks 2–5 |
| Delete AppIcons facade | Task 6 |
| Amenity toilet → toilet | Task 1 |
| Update ai-behavior rule | Task 1 |
| Tests + grep gate | Task 6 |
| Brand SVGs out of scope | — (no task) |
| No Fill/Bold this pass | Task 6 grep |

No placeholders remain. Glyph names verified at Task 1 Step 3 against installed package.
