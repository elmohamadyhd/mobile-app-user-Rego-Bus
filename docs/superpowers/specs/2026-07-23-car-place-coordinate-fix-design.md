# Car place picker — coordinate authority fix

**Date:** 2026-07-23  
**Status:** Approved

## Goal

Fix false-positive `carSearchSamePlace` validation on the Private car search
form when pickup and drop-off show clearly different addresses. Ensure every
confirmed `CarPlace` has internally consistent `latitude`, `longitude`, and
`label`, and that the picker works when only Google Places / Geocoding APIs are
enabled (map tiles broken or absent on the current API key).

## Problem

`CarPlacePickerScreen._confirm()` merges two independent state fields:

- `latitude` / `longitude` from `_center` (live map camera)
- `label` from `_draft` (autocomplete or reverse-geocode)

When the map does not render (Maps SDK not enabled on the key) or the user never
pans the map, `_center` can remain at the Cairo default (`30.0444`, `31.2357`)
while `_draft.label` reflects an autocomplete selection (e.g. Alexandria). The
returned `CarPlace` then has a mismatched label and coordinates.

If both pickup and drop-off pickers hit the same stale `_center`, they share
identical coordinates with different labels. `CarSearchForm` correctly rejects
them via `CarPlace.sameCoordinates()`, producing the snackbar shown in QA.

## Decisions (confirmed with product)

| Question | Choice |
|----------|--------|
| Coordinate authority | **Last-write-wins** among autocomplete, GPS, and map pan |
| Partial API availability | Picker must work when Places/Geocoding work but map tiles do not; structure must allow the inverse later |
| Validation | Keep coordinate-based `sameCoordinates` check — fix the data, not the validator |
| Scope | Picker confirm logic + capability-aware UI + tests only |

## Non-goals

- Inline autocomplete on the home card (still uses full-screen picker).
- Separate `GOOGLE_PLACES_API_KEY` / `GOOGLE_MAPS_SDK_KEY` env vars (deferred;
  capability helper is structured for a future split).
- Backend or search API changes.
- Label-based validation workaround.

## Root cause

```dart
// Current — broken
context.pop(CarPlace(
  latitude: _center.latitude,
  longitude: _center.longitude,
  label: draft.label,
));
```

`_center` and `_draft` can desync whenever autocomplete or GPS updates the
label without moving the map camera to the matching position.

## Solution: atomic draft + last-write-wins

### State (inside `CarPlacePickerScreen`)

| Field | Purpose |
|-------|---------|
| `CarPlace? _draft` | Canonical place — only object returned on confirm |
| `int _draftVersion` | Monotonic counter incremented on every draft write |
| `bool _ignoreMapEvents` | Suppresses `onCameraIdle` during programmatic `animateTo` |
| `LatLng _center` | Map rendering only — **never read on confirm** |

### Write paths

Each path replaces the **full** `_draft` (`lat`, `lng`, `label`) and increments
`_draftVersion`.

1. **Autocomplete select** — `PlacesClient.placeDetails()` → set `_draft` from
   API response. Best-effort `animateTo` if map is available; confirm does not
   wait on animation.
2. **GPS (“use my location”)** — set `_draft` coords from `Geolocator` position
   immediately; reverse-geocode updates label when the request completes.
3. **Map pan** — `onCameraIdle` (debounced 400 ms) → reverse-geocode at pin →
   replace `_draft` with pin coords + geocoded label. Only when
   `_ignoreMapEvents == false`.

### Confirm

```dart
// Fixed
await _flushPendingGeocode(); // await in-flight debounce, max 500 ms
context.pop(_draft!);
```

No merging of `_center` and `_draft`. If geocode is pending, flush before pop
so label matches coordinates.

### Stale map events

During `_animateTo`, set `_ignoreMapEvents = true` and record
`versionAtAnimateStart`. On `onCameraIdle`, only apply reverse-geocode when
`!_ignoreMapEvents` and the idle event is not from a superseded animate (version
unchanged since animate started). Clear `_ignoreMapEvents` when animation
completes or times out (2 s fallback).

## Partial Google API availability

One env key (`GOOGLE_MAPS_API_KEY`) backs Places API (New), Geocoding API, and
Maps SDK for Android. Any subset may be enabled in Google Cloud Console.

### Capability helper

New file: `lib/core/places/google_maps_capabilities.dart`

```dart
abstract final class GoogleMapsCapabilities {
  static bool get placesAvailable => AppConfig.isGoogleMapsConfigured;
  static bool get mapRenderingAvailable => AppConfig.isGoogleMapsConfigured;
}
```

`mapRenderingAvailable` uses the same key check in v1. A future
`GOOGLE_MAPS_SDK_KEY` override can be added without changing picker call-sites.

### Picker modes

| Places | Map tiles | UX |
|--------|-----------|-----|
| ✅ | ✅ | Full: search panel + map pin adjustment |
| ✅ | ❌ | **Search-only**: hide `GoogleMap` layer; panel fills screen; autocomplete + GPS work |
| ❌ | any | Block entry — existing `carMapsNotConfigured` snackbar on `CarPlaceField` |

**Map-unavailable detection (v1):** On first picker open per app session, if
`GoogleMap` `onMapCreated` does not fire within 3 s, set a session flag
`mapRenderingAvailable = false` and re-layout to search-only. This covers grey
tile / SDK-not-enabled keys without a separate probe endpoint.

Pickup silent auto-locate on init (`showUseMyLocation`) still runs without a
map — GPS + Geocoding do not require Maps SDK. Drop-off without a map starts at
the Cairo default until the user searches. The GPS FAB stays on pickup only.

## Search form validation

`CarSearchForm._onSearch()` keeps the existing checks:

1. Both places set.
2. `!_from!.sameCoordinates(_to!)` → `carSearchSamePlace` snackbar.
3. Round-trip date ordering.

No label comparison. With the picker fix, distinct cities always carry distinct
coordinates.

## Files to change

| File | Change |
|------|--------|
| `lib/features/car/presentation/car_place_picker_screen.dart` | Atomic draft, confirm fix, map-event guard, search-only layout |
| `lib/core/places/google_maps_capabilities.dart` | New capability helper |
| `test/features/car/presentation/car_place_picker_screen_test.dart` | Coord authority + search-only mode tests |
| `test/features/car/presentation/car_search_form_test.dart` | Different-coords search proceeds |

## Testing

| Test | Asserts |
|------|---------|
| Confirm after autocomplete (no map interaction) | Returned coords match `placeDetails`, not Cairo default |
| Confirm after autocomplete then map pan | Pin coords win (higher `_draftVersion`) |
| Confirm after GPS | Coords match geolocator position |
| `CarSearchForm` with distinct coords | No `carSearchSamePlace`; search proceeds |
| Search-only mode (`mapRenderingAvailable = false`) | No `GoogleMap` in tree; confirm after autocomplete works |

## Error handling

| Case | Behaviour |
|------|-----------|
| `placeDetails` fails | Show `carPlacesSearchFailed`; do not update `_draft` |
| Reverse-geocode fails | Keep coords; `label` empty (existing `displayLabel` fallback) |
| Geocode flush timeout on confirm | Pop `_draft` with coords + best available label |
| Map never created | Fall back to search-only after 3 s timeout |

## Success criteria

1. Repro from QA (Nasr City pickup + Alexandria drop-off) searches without
   `carSearchSamePlace`.
2. Confirmed `CarPlace` always has coords consistent with the last user action.
3. Picker is usable when Places/Geocoding work but map tiles do not.
4. All new and existing car picker / search form tests pass.
