# Bus Trip Features — Design

_Date: 2026-08-03 | Status: approved for planning_

## Purpose

Backend trip payloads now include a real `features` array (id, name, icon URL).
Replace the static `BusPlaceholderAmenities` stand-in with live data on trip
results cards and trip details, amending the amenities gap noted in
`2026-07-08-bus-live-api-gaps.md`.

## Decisions (locked)

| Topic | Decision |
|---|---|
| Icon source | Backend `icon` URL; Phosphor fallback on missing URL or load failure |
| Empty / missing `features` | Hide amenity UI entirely (no placeholders) |
| Labels | Localize known `id`s via ARB; unknown ids → backend `name` |
| Entity shape | Replace `List<String> amenities` with `List<BusFeature> features` |

## Scope

**In**
- Domain entity + mapper binding for trip `features[]`
- Trip results card compact icon row
- Trip details compact row + amenities bottom sheet chips
- ARB keys for known feature ids beyond the existing wifi/ac/sockets/wc set
  (`dvd`, `gps` at minimum for the Blue Bus sample)

**Out**
- Filtering / sorting trips by feature
- Offline icon asset bundling beyond normal `Image.network` cache
- Amenities on orders / e-tickets (those screens do not currently show trip amenities)
- Changing the seat-map WC marker (unrelated salon cell)

## Data model

### `BusFeature` (Freezed)

```dart
@freezed
abstract class BusFeature with _$BusFeature {
  const factory BusFeature({
    required String id,
    required String name,
    String? iconUrl,
  }) = _BusFeature;
}
```

### `BusTripSummary`

- Remove `BusPlaceholderAmenities` and `amenities: List<String>`.
- Add `@Default([]) List<BusFeature> features`.
- `mergeEnrichment`: prefer `detail.features` when non-empty; else keep cached.

### Mapper (`BusDtoMapper.tripFromJson`)

From trip JSON `features` (list of maps):

- Require non-empty `id` and `name` (string coercion ok); skip invalid entries.
- `iconUrl` = non-empty `icon` string, else `null`.
- Missing or non-list `features` → `[]` (no placeholder fill-in).

Sample payload shape (abridged):

```json
"features": [
  { "id": "dvd", "name": "DVD", "icon": "https://…/DVD.webp" },
  { "id": "ac", "name": "Air Conditioner", "icon": "https://…/Air-Conditioner.webp" },
  { "id": "gps", "name": "GPS tracking system", "icon": "https://…/GPS-Tracking-System.webp" },
  { "id": "wc", "name": "WC", "icon": "https://…/WC.webp" },
  { "id": "wifi", "name": "Wi Fi", "icon": "https://…/Wi-Fi.webp" }
]
```

## UI

### Shared presentation

- `AmenityIconsRow` / `AmenityChip` accept `BusFeature` (row: `List<BusFeature>`).
- Feature icon widget:
  1. If `iconUrl != null` → small `Image.network` (fixed icon size tokens OK).
  2. On error / null URL → Phosphor via `amenityIconFor` heuristics on `id` then `name`.
- Results card: show up to 4 icons; hide the row when `features.isEmpty`.
- Trip details header: same compact row + caret; hide when empty.
- Amenities sheet: `Wrap` of chips; only opened when features exist.

### Localization

Resolve chip/sheet labels with a presentation helper (needs `AppLocalizations`;
not domain — domain must not depend on Flutter l10n):

| `id` (case-insensitive) | ARB key |
|---|---|
| `wifi` | `amenityWifi` |
| `ac` | `amenityAC` |
| `sockets` / `plug` / `power` | `amenitySockets` (keep existing key; may not appear in sample) |
| `wc` | `amenityWc` |
| `dvd` | new `amenityDvd` |
| `gps` | new `amenityGps` |
| other | backend `name` as-is |

Add `amenityDvd` / `amenityGps` to both `app_en.arb` and `app_ar.arb`.

## Error handling

- Mapper never throws on malformed feature items — skip them.
- Icon load failure is visual-only (Phosphor); does not surface a snackbar.
- Empty features is not an error state.

## Testing

- Mapper: maps full features list; skips bad items; absent field → `[]`.
- Mapper / entity: no default placeholder amenities.
- `mergeEnrichment` keeps cached features when detail list is empty.
- Label helper: known id → ARB; unknown → `name`.
- Trip card / details: amenities chrome hidden when empty; visible when present.

## Files (expected)

| Action | Path |
|---|---|
| Create | `lib/features/bus/domain/entities/bus_feature.dart` |
| Modify | `lib/features/bus/domain/entities/bus_trip.dart` |
| Modify | `lib/features/bus/data/bus_dto_mapper.dart` |
| Modify | `lib/features/bus/presentation/widgets/amenity_*.dart` |
| Modify | `lib/features/bus/presentation/widgets/trip_card.dart` |
| Modify | `lib/features/bus/presentation/trip_details_screen.dart` |
| Modify | `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` |
| Modify | bus fixtures + mapper / widget tests |

Requires `dart run build_runner build --delete-conflicting-outputs` and `flutter gen-l10n`.

## Success criteria

- Blue Bus Comfort trip shows DVD, AC, GPS, WC, Wi‑Fi from API.
- Localized labels for known ids; English API name for unknown ids.
- Icons load from URLs; Phosphor if a URL fails.
- Trips with no features show no amenity chrome.
