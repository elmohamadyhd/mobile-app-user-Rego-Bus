# Map place picker — load feedback + medium polish

**Date:** 2026-07-29  
**Status:** Approved  
**Screen:** `MapPlacePickerScreen` (`lib/shared/widgets/map_place_picker_screen.dart`)  
**Related:** `docs/superpowers/specs/2026-07-23-car-place-picker-map-first-design.md`

## Goal

Fix the blank beige map (no feedback while Google Map tiles/SDK initialize) and apply **medium** Skyline polish to the map-first place picker — without changing GPS timing, Places API behavior, or the map-first interaction model.

## Decisions

| Question | Choice |
|----------|--------|
| Slow-load pain | Blank beige map with no spinner/skeleton (A) |
| Polish depth | Medium (B) — loading + contrast + hierarchy |
| Ready signal | First `onCameraIdle` after `onMapCreated` (Approach 2) |
| GPS / Places | Unchanged this pass |

## Problem

On open, `GoogleMap` paints an empty beige surface until tiles arrive. `onMapCreated` alone is not enough; users see a dead map. Header title/back sit on raw tiles with weak contrast. Search/selection use `hairline` borders and muted caption colors that feel washed out. Confirm CTA can sit too close to the system gesture inset.

## Map loading (Approach 2)

### Behavior

1. While map rendering is available and the map is not yet “ready”, show a full-bleed **loading veil** over the `GoogleMap` layer (under the header and under the bottom sheet):
   - Soft fill using `AppColors.bgBase` (optionally slight dim).
   - Brand `CircularProgressIndicator` (primary).
   - Localized label via new key `mapLoading`.
2. Mark map **ready** on the **first** `onCameraIdle` that occurs **after** `onMapCreated`, and only when `_ignoreMapEvents` is `false` (so GPS/`animateCamera` idles do not clear the veil early).
3. Fade the veil out in **200–300 ms** (`Curves.easeOut`).
4. Keep existing **3 s** map-create timeout → `GoogleMapsCapabilities.markMapUnavailable()` → list-only UI (no veil on that path).
5. **Hard failsafe:** if ready never fires, dismiss the veil after **8 s** so the spinner cannot run forever. User can still search / confirm; map may still be blank underneath.
6. Center pin and GPS FAB may remain visible under/over the veil; pin stays `IgnorePointer`. Do not block the bottom sheet or header.

### State

| Flag / timer | Meaning |
|--------------|---------|
| `_mapCreated` | `onMapCreated` fired (existing) |
| `_mapReady` | First qualifying camera idle (or failsafe) |
| `_mapCreateTimeout` | Existing 3 s → unavailable |
| `_mapReadyFailsafe` | New 8 s → force `_mapReady = true` + fade |

### Copy

| Key | EN | AR |
|-----|----|----|
| `mapLoading` | Loading map… | جاري تحميل الخريطة |

Add `@mapLoading` description in `app_en.arb`. Shared key (screen lives in `shared/`, also used by addresses).

## Visual polish (medium)

Keep portrait stack (map + `DraggableScrollableSheet`) and landscape side-by-side. Tokens only (`AppColors` / `AppSpacing` / `AppRadius` / `AppTypography`). Phosphor Light icons only.

| Area | Change |
|------|--------|
| **Header** | Back + title in a frosted chip: `bgCard` ~92% opacity, light shadow, `AppRadius.lg` padding. Readable on tiles. |
| **Center pin** | Primary `PhosphorIconsLight.mapPin` + soft drop shadow + small primary-tint disc under the tip (visual anchor). Still fixed center, `IgnorePointer`. |
| **Search field** | Border `AppColors.border` (not `hairline`); hint `textSecondary`; icon `textSecondary`. |
| **Current selection card** | Border `AppColors.border`; slightly more padding; caption `textSecondary`. |
| **Sheet** | Keep `AppRadius.sheet`; clearer elevation/shadow; tighten vertical rhythm (handle → search → card → CTA) with `AppSpacing`. |
| **Confirm CTA** | Bottom padding = `AppSpacing.md` + `MediaQuery.paddingOf(context).bottom` (safe area). |
| **GPS FAB** | Clearer elevation; keep 48×48; set `accessibilityLabel` to a new or existing locate string (prefer new `mapLocateMe` if no suitable key). |

## Error / edge cases

| Case | Behavior |
|------|----------|
| Map unavailable (3 s / capability) | List-only UI; no loading veil |
| Ready failsafe (8 s) | Hide veil; map may still be blank; search/confirm work |
| Places search fail | Existing inline error |
| GPS denied / fail | Existing silent behavior |
| Keyboard / landscape | Existing sheet sizing; polish must not break RTL or landscape |

## Out of scope

- Speeding up Google tile network / API-key debugging
- Changing GPS cold-start or default Cairo → GPS sequencing
- Recents / address book
- Redesigning prediction list structure
- New map styles / lite mode / pre-warming maps elsewhere

## Files

| Action | Path |
|--------|------|
| Modify | `lib/shared/widgets/map_place_picker_screen.dart` |
| Modify | `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` |
| Modify | `test/features/car/presentation/car_place_picker_screen_test.dart` |
| Generate | `flutter gen-l10n` |

## Success criteria

- Opening the picker with maps available never shows a bare beige map without feedback; veil until first post-create camera idle (or 8 s failsafe).
- Veil does not appear in search-only / map-unavailable mode.
- Header, search, selection card, sheet, pin, CTA, and GPS FAB match the polish table above.
- Existing picker tests still pass; new tests cover veil presence and absence.
- RTL, landscape, and keyboard paths remain usable.

## Testing notes

- Widget tests: assert `mapLoading` text (or `ValueKey('mapLoadingOverlay')`) when map rendering is available before ready; assert absent when `GoogleMapsCapabilities.setMapRenderingAvailableForTesting(false)`.
- Do not require real tiles; fake/platform map callbacks or failsafe pumps are enough.
- Confirm path and autocomplete path remain covered by existing tests.
