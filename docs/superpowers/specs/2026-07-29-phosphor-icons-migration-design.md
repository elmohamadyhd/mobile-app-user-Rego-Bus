# Phosphor Icons Migration — Design

**Date:** 2026-07-29  
**Status:** Approved for planning  
**Package:** `safaria` (Flutter)

## Goal

Replace Tabler (`tabler_icons_plus`) and the `AppIcons` facade with **Phosphor Light** used **directly** in widgets/screens, so the app has a richer, consistent outline icon set (including a clear toilet / حمام glyph).

## Decisions

| Decision | Choice |
|----------|--------|
| Icon pack | Phosphor via `phosphoricons_flutter` (Dart 3 / final `IconData` compatible; not deprecated `phosphor_flutter`) |
| Default weight | **Light** (`PhosphorIconsLight`) |
| Access pattern | **Direct** — no `AppIcons` facade |
| Tabler | Remove from `pubspec.yaml` |
| Material icons | Not for app chrome/amenities; Material widgets (Checkbox, etc.) unchanged |
| Brand SVGs | Unchanged (`assets/brand/` + `BrandMark`) |

## Architecture

1. Add `phosphoricons_flutter` dependency; remove `tabler_icons_plus`.
2. Every UI icon call site imports `package:phosphoricons_flutter/phosphoricons_flutter.dart` and uses `PhosphorIconsLight.<name>`.
3. Delete `lib/core/theme/app_icons.dart`.
4. Update Cursor rule `ai-behavior.mdc`: icons must be `PhosphorIconsLight.*` from `phosphoricons_flutter`, never Tabler/`AppIcons`/Material amenity glyphs.
5. Keep `amenityIconFor(String)` as a thin mapper returning `IconData` from Phosphor Light (not a facade class).

## Glyph map (AppIcons → Phosphor Light)

| Former `AppIcons` | Phosphor Light |
|-------------------|----------------|
| `mail` | `envelopeSimple` |
| `lock` | `lock` |
| `eye` | `eye` |
| `eyeOff` | `eyeSlash` |
| `user` | `user` |
| `phone` | `phone` |
| `shield` | `shieldCheck` |
| `back` | `caretLeft` |
| `forward` | `caretRight` |
| `chevronDown` | `caretDown` |
| `close` | `x` |
| `check` | `check` |
| `bell` | `bell` |
| `bus` | `bus` |
| `busFront` / `gear` | `steeringWheel` |
| `photo` | `image` |
| `camera` | `camera` |
| `private` | `diamond` |
| `flight` | `airplane` |
| `transfer` | `car` |
| `train` | `train` |
| `locationFrom` | `crosshair` |
| `locationTo` | `mapPin` |
| `map` | `mapTrifold` |
| `swap` | `arrowsDownUp` |
| `seats` | `users` |
| `luggage` | `briefcase` |
| `wallet` | `wallet` |
| `walletDeposit` | `arrowDownLeft` |
| `walletWithdraw` | `arrowUpRight` |
| `ticket` | `ticket` |
| `search` | `magnifyingGlass` |
| `home` | `house` |
| `calendar` | `calendarBlank` |
| `filter` | `fadersHorizontal` |
| `error` | `warningCircle` |
| `star` | `star` |
| `amenityWifi` | `wifiHigh` |
| `amenityAC` | `wind` |
| `amenitySockets` | `plug` |
| `amenityWc` | `toilet` |
| `add` / `plus` | `plus` |
| `edit` | `pencilSimple` |
| `download` | `downloadSimple` |
| `share` | `shareNetwork` |
| `checkCircle` | `checkCircle` |
| `logout` | `signOut` |
| `language` | `translate` |
| `settings` | `gearSix` |
| `help` | `question` |

RTL: keep existing flip wrappers on back/forward carets where already used (`auth_back_button`, booking app bars). Prefer mirroring via those wrappers, not Material `Icons.arrow_back`.

## Out of scope

- Layout / color / typography redesign
- Phosphor Fill / Bold / Duotone in this pass (except Light only)
- Rewriting historical docs that mention `AppIcons`
- Custom SVG icon assets beyond existing brand marks

## Verification

- `flutter analyze` — no issues
- Grep: zero `AppIcons`, `tabler_icons`, `TablerIcons` under `lib/` and `test/`
- Grep: no `Icons.` used as amenity/chrome icons in feature widgets (Material widget icons like default Checkbox OK)
- Widget tests that assert `IconData` updated to Phosphor Light equivalents
- Manual smoke: amenities (incl. toilet), seat-map WC, bottom nav, auth eye toggle

## Risks

| Risk | Mitigation |
|------|------------|
| Mixed weights (Regular vs Light) | Cursor rule + analyze/grep gate for `PhosphorIconsRegular` / `Bold` / `Fill` in `lib/` |
| Binary size | Accept Phosphor font cost; tree-shake unused if tooling allows |
| Wrong glyph name at migrate time | Use map above; verify against `phosphoricons_flutter` API before commit |
