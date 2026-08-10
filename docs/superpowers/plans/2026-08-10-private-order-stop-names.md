# Private Order Stop Names Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Auto-fill `departure.name` / `destination.name` on private orders from Google known place name, else `"Street, City"`.

**Architecture:** `PlaceNameResolver` builds the label; `PlacesClient.placeDetails` / `reverseGeocode` enrich labels at pick time; `CarDtoMapper` sends `CarPlace.label` as stop `name`.

**Tech Stack:** Flutter/Dart, Dio Places API (New) + Geocoding API, existing car booking DTOs.

## Global Constraints

- Prefer `displayName` when non-empty; else `"Street, City"`; omit missing parts; else `""`
- No full `formatted_address` as order name
- Resolve at pick time into `CarPlace.label`
- Package imports; no commits unless user asks

## File Structure

| File | Role |
|------|------|
| `lib/core/places/place_name_resolver.dart` | Pure name composition |
| `lib/core/places/places_client.dart` | Parse displayName + address components |
| `lib/features/car/domain/entities/car_create_order_request.dart` | `departureName` / `destinationName` |
| `lib/features/car/data/car_dto_mapper.dart` | Body includes `name` |
| `lib/features/car/presentation/providers/car_booking_providers.dart` | Any direct `CarCreateOrderRequest` construction |
| `test/core/places/place_name_resolver_test.dart` | Resolver unit tests |
| `test/core/places/places_client_test.dart` | Updated fixtures |
| `test/features/car/data/car_dto_mapper_test.dart` | Assert `name` in body |

---

### Task 1: PlaceNameResolver (TDD)

**Files:**
- Create: `lib/core/places/place_name_resolver.dart`
- Create: `test/core/places/place_name_resolver_test.dart`

**Interfaces:**
```dart
abstract final class PlaceNameResolver {
  static String resolve({
    String? knownName,
    String? street,
    String? city,
  });
}
```

- [ ] **Step 1: Write tests** — known wins; street+city; street only; city only; empty/whitespace
- [ ] **Step 2: Implement resolver**
- [ ] **Step 3: `flutter test test/core/places/place_name_resolver_test.dart`** — PASS

---

### Task 2: Enrich PlacesClient

**Files:**
- Modify: `lib/core/places/places_client.dart`
- Modify: `test/core/places/places_client_test.dart`

- [ ] **Step 1: Update `placeDetails`**
  - Field mask: `location,formattedAddress,displayName,addressComponents`
  - Label = `PlaceNameResolver.resolve(knownName: displayName.text, street: route, city: locality|admin2|admin1)`
  - Parse Places API (New) components: `longText` / `types`

- [ ] **Step 2: Update `reverseGeocode`**
  - Parse `address_components` (`long_name` / `types`)
  - Street = `route`; city = locality → admin_level_2 → admin_level_1
  - Label via resolver (no `formatted_address`)
  - Empty components → `""`

- [ ] **Step 3: Fix/extend places_client tests** for new label rules

- [ ] **Step 4: Run places tests** — PASS

---

### Task 3: Order request `name` fields

**Files:**
- Modify: `car_create_order_request.dart`, `car_dto_mapper.dart`, `car_booking_providers.dart` if needed
- Modify: `car_dto_mapper_test.dart`

- [ ] **Step 1: Add `departureName` / `destinationName` to request; fill from `params.from.label` / `params.to.label`**
- [ ] **Step 2: Put `name` in departure/destination maps in `createOrderBody`**
- [ ] **Step 3: Update mapper test to expect names `"A"` / `"B"`**
- [ ] **Step 4: `flutter test test/features/car/data/car_dto_mapper_test.dart test/core/places/`** — PASS

---

### Task 4: Verify

- [ ] `flutter analyze` on touched paths — no issues
- [ ] Spec check: known name, Street+City, pick-time label, order body `name`, empty OK
