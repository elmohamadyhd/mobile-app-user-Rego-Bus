# Private car search — design

**Date:** 2026-07-23  
**Status:** Approved (pending spec review)

## Goal

Wire the Home **Private** tab to a real private-transfer search flow: inline
Google Places autocomplete for pickup and drop-off on the home search card,
`GET /private/search` for vehicle quotes, and a results screen to browse tiers.
Guests may search and view results without signing in; login is prompted only
when they try to continue past results (booking is out of scope).

## Decisions (confirmed with product)

| Question | Choice |
|----------|--------|
| Location input | **Inline autocomplete** on the home card + optional “adjust on map” link (Approach B) |
| Scope | **Form + results only** — no order creation, payment, or voucher |
| Auth | **Browse-then-login** — no gate on opening the tab or running search; gate on “Continue” |

## Current state

- `lib/features/car/` does **not** exist.
- Home Private tab (index `1` in `TransportModeTabBar`) shows a “coming soon”
  snackbar (`lib/features/home/presentation/widgets/home_search_card.dart`).
- The search card reuses the **bus city picker** for all tabs — wrong for
  private transfers, which require GPS coordinates.
- No Google Maps / Places packages or API keys in the project.
- No address-book feature (API exists at `/profile/address-book`; deferred).
- Architecture spec (`2026-07-08-multi-vehicle-architecture-design.md`) already
  defines the `car/` slice shape and on-demand-quote flow.

## Backend API

### `GET /private/search`

| Parameter | Type | Notes |
|-----------|------|-------|
| `from_latitude` | `double` | Pickup |
| `from_longitude` | `double` | Pickup |
| `to_latitude` | `double` | Drop-off |
| `to_longitude` | `double` | Drop-off |
| `rounded` | `boolean` | `false` = one-way, `true` = round-trip |
| Auth | Bearer | Documented as required; same as bus search — attempt without pre-gate, handle `401` |
| `Accept-Language` | `ar` \| `en` | Via existing Dio interceptor |

**Response** — `data` is an array of priced vehicle quotes:

```json
{
  "id": 1,
  "rounded": true,
  "go_price": 69.87,
  "round_price": 104.81,
  "currency": "SAR",
  "status": true,
  "company": {
    "id": 1,
    "name": "Sky Travel",
    "refundability": true,
    "refund_policy": "Sky Travel",
    "logo_url": "https://…"
  },
  "from_location": { "id": 1, "name": "Cairo", "latitude": "30.04…", "longitude": "31.24…" },
  "to_location": { "id": 2, "name": "Alexandria", "latitude": "31.24…", "longitude": "29.98…" },
  "vehicle": {
    "id": 1,
    "name": "Hundai",
    "category_id": 1,
    "category_name": "Sedan",
    "seats_number": 5,
    "model": "Matrix",
    "year": 2010,
    "big_bags_count": 4,
    "small_bags_count": 1,
    "gear_type": "automatic",
    "featured_url": "https://…"
  }
}
```

Empty result: HTTP `200`, `data: []` — not an error.

**Not sent to search:** departure date, return date, time. Those are collected
on the form for UX continuity and stored in notifier state for a future order
step (`POST /private/orders`).

### Deferred APIs (out of scope)

- `POST /private/orders` — booking
- `GET /profile/address-book` — saved addresses shortcut
- `GET /profile/private/orders` — tickets tab history

## Non-goals

- Order creation, contact capture, payment, voucher.
- Address-book CRUD or picker integration.
- Full-screen map-first location flow (Approach A) — map is secondary only.
- Distance/duration estimate (“~22 km · 35 min” in V1 design) — no backend field.
- Flight or train tab work.
- Lifting shared widgets from bus into `shared/` preemptively.

## Architecture

New standalone slice per multi-vehicle spec:

```
lib/features/car/
├── data/
│   ├── car_api.dart                 # GET /private/search
│   ├── car_dto_mapper.dart
│   └── car_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── car_place.dart           # lat, lng, label
│   │   ├── car_search_params.dart   # from, to, rounded, departDate, returnDate?
│   │   └── car_trip_quote.dart      # one data[] item
│   └── repositories/
│       └── car_repository.dart
└── presentation/
    ├── car_routes.dart
    ├── car_search_form.dart         # home Private tab widget
    ├── car_tier_results_screen.dart
    ├── car_map_adjust_sheet.dart    # optional pin fine-tune (secondary)
    ├── providers/
    │   └── car_booking_providers.dart
    └── widgets/
        ├── car_place_autocomplete_field.dart
        └── car_tier_card.dart
```

Shared Places client (not bus/car-specific):

```
lib/core/places/
├── places_client.dart               # Autocomplete + Place Details over HTTPS
└── places_providers.dart          # Riverpod provider
```

`AppConfig` gains `googleMapsApiKey` from `.env` (`GOOGLE_MAPS_API_KEY`).

## Location input — Approach B (inline autocomplete)

### Primary: autocomplete fields on the home card

`CarSearchForm` replaces bus city fields when the Private tab is active.

Each location row (`CarPlaceAutocompleteField`) contains:

1. **Label** — “Pickup” / “Drop-off” (localized overline, same visual weight as
   bus `_CityField`).
2. **Text field** — debounced Places Autocomplete (300 ms), powered by
   `PlacesClient.autocomplete(term, languageCode)`.
3. **Prediction overlay** — `OverlayEntry` or anchored dropdown below the
   field (not a separate route). Max 5 suggestions; tap selects.
4. **On select** — call `PlacesClient.placeDetails(placeId)` → set
   `CarPlace(lat, lng, label)` on the form state.

Autocomplete sessions use a per-field session token (UUID) per Google billing
best practice; token resets after a place is selected.

### Secondary: “Adjust on map”

A text link under each field (or a map-pin icon button) opens
`CarMapAdjustSheet` — a **modal bottom sheet** (~60 % screen height), not a
full-screen picker:

- `GoogleMap` with draggable camera (fixed center pin).
- Shows the current `CarPlace` coordinates or a sensible default (device
  location if permitted, else Cairo centroid).
- Debounced reverse-geocode on camera idle → updates label in sheet header.
- “Confirm” pops the sheet and writes the adjusted `CarPlace` back to the form.

This satisfies the “map pin” requirement without making map the primary entry.

### Optional: “Use my location”

Small action on the pickup field only. Uses `geolocator` → permission prompt →
reverse-geocode → fills pickup `CarPlace`. Out of scope if permission plumbing
delays v1 — can ship autocomplete-only first and add in a follow-up task within
the same plan if time allows.

### Validation before search

- Both `from` and `to` must be set (lat/lng resolved, not just typed text).
- `from` and `to` must differ (same coordinates → inline error).
- Round-trip: `returnDate` must be on or after `departDate`.

## Search form layout

Rendered inside `HomeSearchCard` when `selectedTab == privateTabIndex`.

| Control | Maps to |
|---------|---------|
| Trip type toggle (one-way / round-trip) | `rounded: false \| true` |
| Pickup autocomplete field | `CarPlace from` |
| Drop-off autocomplete field | `CarPlace to` |
| Swap button | swaps `from` ↔ `to` |
| Departure date | `departDate` (stored, not sent to search) |
| Return date (round-trip only) | `returnDate` (stored) |
| Primary CTA | localized “Request a car” |

**Responsive:** form body scrollable inside the card; in landscape, respect
`AppBreakpoints.maxContentWidth` via parent `HomeScreen` constraints. No fixed
heights on the autocomplete dropdown — cap list height and make it scrollable.

**Tab bar:** add `TransportModeTabBar.privateTabIndex = 1`; remove “coming soon”
snackbar for that index.

## Results screen

**Route:** `CarRoutes.results` → `/car/results`  
**Screen:** `CarTierResultsScreen` — title “Choose vehicle” (localized).

### Header

- Route line: `from.label → to.label` (truncate with ellipsis on narrow widths).
- Subtitle: formatted depart date; append return date when round-trip.

### Body

`ListView` of `CarTierCard` widgets, one per `CarTripQuote`:

| Element | Source |
|---------|--------|
| Company logo | `company.logo_url` (fallback: initials avatar) |
| Company name | `company.name` |
| Vehicle image | `vehicle.featured_url` |
| Category + model | `vehicle.category_name`, `vehicle.model` |
| Capacity | `vehicle.seats_number` seats, bag counts |
| Gear | `vehicle.gear_type` (localized enum) |
| Price | `go_price` if one-way, `round_price` if round-trip |
| Currency | `currency` |
| Refund badge | shown when `company.refundability == true` |

### States

| State | UI |
|-------|-----|
| Loading | 3 skeleton cards |
| Success, non-empty | tier list |
| Success, empty | empty-state illustration + “Try different locations” |
| Error | inline error banner + retry button |

### Selection + Continue CTA

- Tap a card → visual selected state; `CarBookingNotifier` stores
  `selectedQuote` (`trip_id` = quote `id`).
- Pinned bottom bar: “Continue” (disabled until a quote is selected).
- **Guest:** `showGuestGate(returnTo: CarRoutes.results)` — copy adapted for
  car (“Sign in to continue your transfer”). No navigation beyond results in
  this slice.
- **Signed-in:** same gate for now (booking screen does not exist yet) — show
  a localized snackbar “Booking coming soon” or disable CTA with subtitle.
  Prefer snackbar so the gate pattern is tested for guests and the signed-in
  path is obviously incomplete.

Pull-to-refresh re-runs search with preserved `CarSearchParams`.

## Data flow

```
Home (Private tab)
  └─ CarSearchForm
       ├─ PlacesClient.autocomplete / placeDetails  (on type / select)
       ├─ CarMapAdjustSheet (optional, on “adjust on map”)
       └─ on Search:
            CarBookingNotifier.searchQuotes(params)
              └─ CarRepository.searchQuotes
                   └─ CarApi GET /private/search
            → context.push(CarRoutes.results)

CarTierResultsScreen
  └─ watches carBookingProvider (quotes AsyncValue)
  └─ on Continue → guest gate or “coming soon” snackbar
```

## Auth & errors

1. **No login wall** on opening Private tab or filling the form.
2. **Search** calls the live API; Dio sends bearer token when present.
3. **401 on search** → `showGuestGate(returnTo: CarRoutes.results)`; on return,
   notifier auto-retries `searchQuotes` with preserved params.
4. **Other errors** → `AsyncValue.error`; results screen shows retry.
5. **Continue CTA** → guest gate (see above).

## Domain entities

### `CarPlace`

```dart
final class CarPlace {
  const CarPlace({
    required this.latitude,
    required this.longitude,
    required this.label,
  });
  final double latitude;
  final double longitude;
  final String label;
}
```

### `CarSearchParams`

```dart
final class CarSearchParams {
  const CarSearchParams({
    required this.from,
    required this.to,
    required this.rounded,
    required this.departDate,
    this.returnDate,
  });
  final CarPlace from;
  final CarPlace to;
  final bool rounded;
  final DateTime departDate;
  final DateTime? returnDate;
}
```

### `CarTripQuote`

Maps one `data[]` element. Nested value objects: `CarCompany`, `CarVehicle`,
`CarNamedLocation` (from/to in response — informational; search uses form
coordinates, not these IDs).

### `CarRepository`

```dart
abstract interface class CarRepository {
  Future<List<CarTripQuote>> searchQuotes(CarSearchParams params);
}
```

## Home integration

`home_search_card.dart` becomes a thin shell:

- Owns tab index and which form widget to show.
- Bus tab → existing bus fields (unchanged for this spec).
- Private tab → `CarSearchForm`.
- Flight / train → keep “coming soon” until their specs land.

`CarSearchForm` owns submit logic: validate → `carBookingProvider.notifier
.searchQuotes()` → `context.push(CarRoutes.results)`.

## Routing

```dart
// car_routes.dart
abstract final class CarRoutes {
  static const results = '/car/results';
}

List<RouteBase> carRoutes() => [
  GoRoute(
    path: CarRoutes.results,
    builder: (_, __) => const CarTierResultsScreen(),
  ),
];
```

Register `...carRoutes()` in `app_router.dart` alongside `...busRoutes()`.

## Dependencies & config

**New packages** (require explicit approval before `pubspec.yaml` edit):

| Package | Purpose |
|---------|---------|
| `google_maps_flutter` | Map in `CarMapAdjustSheet` |
| `geolocator` | Optional “use my location” |

Places Autocomplete + Place Details + Geocoding: **HTTPS via `PlacesClient`**
using `GOOGLE_MAPS_API_KEY` — no extra Places SDK package. Autocomplete and
place details use **Places API (New)** at `places.googleapis.com/v1`; reverse
geocode uses the **Geocoding API** (`/maps/api/geocode/json`).

**`.env.example`:**

```
GOOGLE_MAPS_API_KEY=
```

**Platform:** Android manifest meta-data + iOS `AppDelegate`/`Info.plist` for
Maps key; `NSLocationWhenInUseUsageDescription` if geolocator ships in v1.

## Localization

New keys in `app_en.arb` / `app_ar.arb` (representative set):

- `carPickup`, `carDropoff`
- `carPlaceSearchHint`
- `carAdjustOnMap`
- `carUseMyLocation`
- `carRequestCar` (search CTA)
- `carChooseVehicle` (results title)
- `carNoQuotes`, `carNoQuotesBody`
- `carSeats`, `carBags`, `carGearAutomatic`, `carGearManual`
- `carRefundable`
- `carContinue`
- `carBookingComingSoon`
- `carSearchSelectBothPlaces`
- `carSearchSamePlace`
- `guestGateCarBody` (guest gate variant for Continue)

Run `flutter gen-l10n` after adding keys.

## Testing

| Test | Covers |
|------|--------|
| `car_dto_mapper_test.dart` | JSON envelope → `CarTripQuote` list; empty array; string lat/lng |
| `car_booking_notifier_test.dart` | `searchQuotes` success/empty/error; `selectedQuote`; 401 retry hook |
| `car_tier_card_test.dart` | Renders price, seats, company name; RTL locale |
| `car_search_form_test.dart` | Validation blocks search when places missing |

`PlacesClient` gets a unit test with mocked HTTP responses (no live Google calls
in CI).

## Error states (explicit)

| Condition | User-facing behavior |
|-----------|---------------------|
| Autocomplete network fail | Inline “Couldn’t search places” under field; retry on next keystroke |
| Zero autocomplete results | “No places found” in dropdown |
| Search API empty | Empty state on results screen |
| Search API 401 | Guest gate sheet |
| Search API 5xx / timeout | Error banner on results + retry |
| Map sheet without API key | Hide “adjust on map” link; autocomplete still works if Places key set |

## File checklist (implementation plan input)

| # | File / area |
|---|-------------|
| 1 | `lib/core/config/app_config.dart` — `googleMapsApiKey` |
| 2 | `lib/core/places/places_client.dart` + providers |
| 3 | `lib/features/car/domain/**` |
| 4 | `lib/features/car/data/**` |
| 5 | `lib/features/car/presentation/**` |
| 6 | `lib/features/home/.../home_search_card.dart` — wire Private tab |
| 7 | `lib/shared/widgets/transport_mode_tab_bar.dart` — `privateTabIndex` |
| 8 | `lib/core/router/app_router.dart` — `carRoutes()` |
| 9 | `lib/l10n/app_en.arb`, `app_ar.arb` |
| 10 | `.env.example` |
| 11 | Android/iOS Maps config |
| 12 | Tests listed above |

## V1 design alignment

Skyline batch design (`design/V1/…`) shows a full-screen map sheet for
location pick. This spec deliberately uses **inline autocomplete** (Approach B)
for faster iteration; the map adjust sheet preserves pin fine-tuning without
matching screen 20 pixel-for-pixel. Results screen aligns with screen 21
(“Choose vehicle” tier list).

## UI refactor (picker sheet) — 2026-07-23

After shipping the initial inline autocomplete, the home-card location block was
refactored for Skyline parity with bus city rows.

| Before | After |
|--------|-------|
| `TextField` with inline predictions inside the bordered card | Collapsed `CarPlaceField` row (label + value + chevron) |
| “Use my location” / “Adjust on map” as stacked `TextButton`s under pickup | Quick-action tiles in `CarPlacePickerSheet` idle body (GPS pickup-only + map) |
| Raw `lat, lng` shown when reverse geocode fails | `CarPlace.displayLabel` shows localized “Selected location” |
| Uneven row heights; swap button misaligned | Equal-height rows; swap centered between pickup and drop-off |

**Interaction:** tap a place row → `showCarPlacePicker` bottom sheet (mirrors
`showBusCityPicker`) with search, predictions, GPS (pickup only), and map
adjust. The home card is read-only display; editing happens in the sheet.

**Files:** `car_place_field.dart`, `car_place_picker_sheet.dart`; removed
`car_place_autocomplete_field.dart`. Approach B inline editing on the card is
superseded for location *editing* only — search/booking logic unchanged.

**Sheet polish (same day):** idle state shows drag handle, current-selection
card (when set), and quick-action rows instead of a duplicate search placeholder
in empty space. Footer `TextButton`s removed; sheet height is ~50% at idle and
~75% while searching.
