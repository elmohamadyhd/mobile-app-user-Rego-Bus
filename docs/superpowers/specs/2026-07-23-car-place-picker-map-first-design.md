# Car place picker — map-first redesign

**Date:** 2026-07-23  
**Status:** Approved

## Goal

Replace the compact search bottom sheet with a **unified map-first location picker** per field (pickup or drop-off), aligned with Skyline screen 20 (Transfer search). One screen merges search, GPS, map pin adjust, and confirm.

## Decisions

| Question | Choice |
|----------|--------|
| Direction | **Map-first full-screen route** (not tall modal sheet) |
| Entry | `CarPlaceField` → `go_router` push; returns `CarPlace?` |
| Map + search | **Synced** — prediction moves camera; camera idle updates label |
| Home card | Unchanged collapsed rows |

## Architecture

- New `CarPlacePickerScreen` at `/car/place-picker`.
- `DraggableScrollableSheet` over full-bleed `GoogleMap` with fixed center pin.
- Panel contains: search bar, results/idle body, `PrimaryButton` confirm.
- Floating GPS FAB (pickup only).
- Removes `showCarPlacePicker` / `car_place_picker_sheet.dart`; `car_map_adjust_sheet.dart` logic absorbed into screen.

## Screen layout

**Portrait:** map full bleed; top bar (back + title); GPS FAB; bottom draggable panel (handle, search, body, confirm).

**Landscape (≥ medium):** `Row` — map `Expanded(flex: 3)` | panel `Expanded(flex: 2)` with max width constraint.

## Interaction

1. Open → camera on `initial`, user GPS (pickup if permitted), or Cairo default.
2. Search ≥2 chars → Places API (New) autocomplete in panel.
3. Tap prediction → place details → animate camera → set draft `CarPlace`.
4. Camera idle → debounced reverse geocode → update draft label.
5. Confirm → `pop(draft)`; back → `pop(null)`.
6. Confirm disabled until draft has coordinates.

## Error states

- Places search fail → inline `carPlacesSearchFailed` in panel.
- No results → `carPlacesNoResults`.
- Location permission denied → silent (GPS FAB no-op); user can search or drag map.
- `!placesClientProvider.isConfigured` → snackbar on entry (field level, unchanged).

## Out of scope

- Session recents / address book
- Single screen editing both pickup and drop-off
- Time picker on this screen

## Files

| Action | Path |
|--------|------|
| Create | `lib/features/car/presentation/car_place_picker_screen.dart` |
| Modify | `lib/features/car/presentation/car_routes.dart`, `car_place_field.dart` |
| Delete | `lib/features/car/presentation/widgets/car_place_picker_sheet.dart`, `car_map_adjust_sheet.dart` |
| Tests | `test/features/car/presentation/car_place_picker_screen_test.dart`; remove sheet tests |

## Success criteria

- Tapping pickup/drop-off opens full-screen map picker
- Search and map pin stay in sync
- Confirm returns `CarPlace` with label + coordinates
- RTL, landscape, keyboard-safe panel
- Car feature tests pass
