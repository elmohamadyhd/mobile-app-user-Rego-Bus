# Addresses (address book) — design

**Date:** 2026-07-25  
**Status:** Draft — pending review

## Goal

Replace the Profile → **Addresses** “coming soon” snackbar with a real, API-backed
saved-addresses flow: list saved locations, add a new address, edit an existing
one, and delete. Matches Skyline screen **29 · Address book**
(`design/V1/REGO Buses - Batch 1+2.dc.html`).

## Current state

- `ProfileScreen` row `profileMenuAddresses` calls `_showComingSoon`
  (`lib/features/profile/presentation/profile_screen.dart:39-42`).
- No `lib/features/addresses/` slice exists.
- `CarPlacePickerScreen` already implements map-first location picking for the car
  feature (`lib/features/car/presentation/car_place_picker_screen.dart`), built on
  `core/places/`. Car design explicitly deferred address-book integration
  (`docs/superpowers/specs/2026-07-23-car-place-picker-map-first-design.md`).
- Localization has only the profile menu label (`profileMenuAddresses`).

## Backend APIs (`docs/Wadeny.postman_collection.json` → Profile → addresses)

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/profile/address-book` | Paginated list |
| `POST` | `/profile/address-book` | Create |
| `PUT` | `/profile/address-book/:id` | Update |
| `DELETE` | `/profile/address-book/:id` | Delete |

All require bearer auth (`401` when unauthenticated).

### List response shape

```json
{
  "status": 200,
  "message": "Customer addresses list",
  "errors": {},
  "data": [
    {
      "id": 22,
      "city": null,
      "name": "محرب بيك",
      "phone": "1554052685",
      "notes": "…",
      "whatsapp_share_link": "https://api.whatsapp.com/send?text=…",
      "map_location": {
        "lat": 24.2222,
        "lng": 46.5555,
        "address_name": "محرم بيك شارع المطافي عماره عشره"
      }
    }
  ],
  "pagination": {
    "total": 1,
    "lastPage": 1,
    "perPage": 15,
    "currentPage": 1,
    "nextPageUrl": null,
    "previousPageUrl": null
  }
}
```

### Create / update body

Required: `name`, `map_location` (`lat`, `lng`, `address_name`).  
Optional: `phone`, `city_id`, `notes`.

Server returns the saved record (including `id`, `phone`, `whatsapp_share_link`).

Validation errors (`400`) return field keys under `errors` (Arabic messages).

## Design vs API gaps

| V1 design element | API support | v1 decision |
|-------------------|-------------|-------------|
| Home / Work / custom icon types | No `type` field — only free-text `name` | Generic pin icon for every row; optional soft tint rotation by index for visual variety |
| “Default” badge | No `is_default` field | **Omit** badge in v1 |
| Edit pencil on card | — | Tap card **or** pencil → edit screen |
| Delete | `DELETE` endpoint exists | Delete from edit screen (destructive button + confirm dialog) |
| WhatsApp share link | Returned on each record | **Out of scope** v1 |
| `city` / `city_id` | Optional on write; `city` null in samples | **Out of scope** — do not show city picker until a cities API is wired |

## Non-goals (v1)

- Picking an address book entry inside car/bus booking flows (future integration).
- “Set as default” / home-work categorization.
- WhatsApp / maps share actions.
- City picker (`city_id`).
- Infinite backend pagination UX beyond “load next page when user scrolls near end”
  (keep implementation simple — most riders have few addresses).

## Architecture

New standalone slice, mirroring `features/wallet/`:

```
lib/features/addresses/
├── data/
│   ├── addresses_api.dart
│   ├── addresses_dto_mapper.dart
│   └── addresses_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── saved_address.dart          # SavedAddress, MapLocation (Freezed)
│   │   └── address_page.dart           # list + pagination cursor
│   └── repositories/
│       └── addresses_repository.dart
└── presentation/
    ├── addresses_routes.dart
    ├── addresses_screen.dart           # list + empty + add CTA
    ├── address_form_screen.dart        # create / edit
    ├── providers/
    │   └── addresses_providers.dart
    └── widgets/
        ├── addresses_app_bar.dart
        ├── address_card.dart
        └── add_address_button.dart
```

### Shared map picker extraction

`CarPlacePickerScreen` cannot be imported from `features/car/` (feature-slice rule).
Extract a **shared** map-first picker:

| Action | Path |
|--------|------|
| Create | `lib/shared/models/map_place.dart` — `latitude`, `longitude`, `label` (+ `displayLabel` helper moved from `CarPlace`) |
| Create | `lib/shared/widgets/map_place_picker_screen.dart` — UI moved from car, parameterized by title + initial + `showUseMyLocation` |
| Create | `lib/shared/widgets/map_place_picker_args.dart` |
| Modify | `lib/features/car/` — thin wrapper route delegating to shared picker, mapping `MapPlace` ↔ `CarPlace` at the boundary |
| Modify | `lib/core/router/app_router.dart` — register shared picker route **or** duplicate route entries in car + addresses that both build the same shared screen |

Recommended route: single shared path `/place-picker` on the root navigator,
returning `MapPlace?` via `context.pop`.

## Navigation

**`addresses_routes.dart`:**

```dart
abstract final class AddressesRoutes {
  static const list = '/profile/addresses';
  static const create = '/profile/addresses/new';
  static String edit(int id) => '/profile/addresses/$id/edit';
}
```

**`app_router.dart`** — spread `...addressesRoutes()` beside `...walletRoutes()`.

**`profile_screen.dart`** — guest gate identical to wallet:

```dart
onTap: () => isGuest
    ? context.go(AppRoutes.login, extra: AuthGateArgs(returnTo: AddressesRoutes.list))
    : context.push(AddressesRoutes.list),
```

**Form → map picker:** `context.push<MapPlace>(PlacePickerRoutes.picker, extra: args)`.

## Screen behaviour

### 1. Addresses list (`AddressesScreen`)

- White `AddressesAppBar` (“Saved addresses”), back pops.
- `RefreshIndicator` + scrollable list on `AppColors.bgBase`.
- Each row: `AddressCard` — tinted icon, **name** (bold), **map_location.address_name**
  (secondary, 2 lines max), trailing edit icon.
- Dashed `AddAddressButton` at bottom (Skyline screen 29).
- **Empty state:** illustration-free — centered title + subtitle + same add button.
- **Loading / error:** standard `AsyncValue` centre spinner / retry.
- **Pagination:** when `pagination.nextPageUrl != null`, fetch next page on
  scroll end and append (no pull required).
- Landscape: constrain to `AppBreakpoints.maxContentWidth`, centred.

### 2. Address form (`AddressFormScreen`)

Modes: **create** (`/new`) and **edit** (`/:id/edit`).

Fields:

| Field | Control | Validation |
|-------|---------|------------|
| Label (`name`) | `TextFormField` | Required, non-empty trim |
| Location | Read-only row showing `address_name`; tap opens map picker | Required coordinates + `address_name` |
| Phone | Optional `TextFormField` (`keyboardType: phone`) | Optional |
| Notes | Optional multiline | Optional |

- Primary **Save** (`PrimaryButton`) — disabled while submitting.
- Edit mode: **Delete** text button (error colour) → confirm dialog → `DELETE` → pop to list.
- On save success: `pop` to list; list provider invalidates/refreshes.
- Map row shows `map_location.address_name` or placeholder l10n when unset.
- Keyboard-safe `SingleChildScrollView` + `resizeToAvoidBottomInset: true`.

### 3. Map place picker (shared)

Same interaction contract as car place picker (search ↔ map sync, confirm disabled
until coordinates exist). `showUseMyLocation: true` for address form.

## State

`AddressesNotifier` — `AsyncNotifier<AddressPage>`:

- `build()` → `repository.list(page: 1)`
- `refresh()` → replace state
- `loadMore()` → append if `hasNextPage`
- `delete(id)` → optimistic remove or refresh-after-success

`AddressFormNotifier` — `AsyncNotifier<SavedAddress?>` for edit preload, or
separate `FutureProvider.family` for `getById` if list already has the row.

Prefer **refresh list after mutate** over complex local patching (YAGNI).

## Error handling

- Repository wraps `DioException` → `ApiException` (wallet pattern).
- Form submit: show `SnackBar` with `ApiException.message` or first field error.
- List error: inline message + retry button.
- 401: handled globally by Dio interceptor (existing); screen shows error state.

## Localization (new keys — both `app_en.arb` + `app_ar.arb`)

| Key | EN example |
|-----|------------|
| `addressesScreenTitle` | Saved addresses |
| `addressesEmptyTitle` | No saved addresses yet |
| `addressesEmptySubtitle` | Add a location to reuse it when booking |
| `addressesAddNew` | Add new address |
| `addressesError` | Couldn't load addresses |
| `addressesRetry` | Try again |
| `addressFormCreateTitle` | New address |
| `addressFormEditTitle` | Edit address |
| `addressFormNameLabel` | Label |
| `addressFormNameHint` | Home, work, … |
| `addressFormLocationLabel` | Location |
| `addressFormLocationPlaceholder` | Pick on map |
| `addressFormPhoneLabel` | Phone (optional) |
| `addressFormNotesLabel` | Notes (optional) |
| `addressFormSave` | Save |
| `addressFormDelete` | Delete address |
| `addressFormDeleteTitle` | Delete this address? |
| `addressFormDeleteMessage` | This can't be undone. |
| `addressFormDeleteConfirm` | Delete |
| `addressFormSaved` | Address saved |
| `addressFormDeleted` | Address deleted |
| `addressFormNameRequired` | Label is required |
| `addressFormLocationRequired` | Pick a location on the map |

Reuse existing `carPlaceSelectedLocation` / map-picker strings where they fit;
add `mapPlacePickerTitle` only if car-specific titles are insufficient.

## Icons

Use `AppIcons` facade — add if missing: `edit`, `home` (optional), `pin` /
reuse `locationTo` for card icon.

## Testing

| Layer | File |
|-------|------|
| DTO mapper | `test/features/addresses/data/addresses_dto_mapper_test.dart` |
| Repository | `test/features/addresses/data/addresses_repository_impl_test.dart` (mock API) |
| List screen | `test/features/addresses/presentation/addresses_screen_test.dart` |
| Form screen | `test/features/addresses/presentation/address_form_screen_test.dart` |
| Profile nav | extend `test/features/profile/profile_screen_test.dart` |
| Car regression | existing car place picker tests still pass after shared extraction |

Widget tests: pump under `Locale('ar')` at minimum; assert guest gate, empty
state, list rows, add navigation.

## Success criteria

- Profile → Addresses opens list (guest → login with return path).
- List reflects `GET /profile/address-book`; pull-to-refresh works.
- Add / edit / delete round-trip against API.
- Map picker returns coordinates + `address_name` into the form.
- RTL, landscape scroll, large text — no overflow.
- `flutter analyze` clean; new tests pass.

## File touch summary

| Action | Path |
|--------|------|
| Create | `lib/features/addresses/**` (full slice) |
| Create | `lib/shared/models/map_place.dart`, `lib/shared/widgets/map_place_picker_*.dart` |
| Modify | `lib/features/car/presentation/car_place_picker_screen.dart` → delegate to shared |
| Modify | `lib/features/profile/presentation/profile_screen.dart` |
| Modify | `lib/core/router/app_router.dart` |
| Modify | `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` |
| Modify | `lib/core/theme/app_icons.dart` (if needed) |
| Test | `test/features/addresses/**`, profile test extension |
