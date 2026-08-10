# Private Tab Saved Addresses Strip — Design

_Date: 2026-08-10 | Status: approved for planning + implementation_

## Purpose

On Home, when the transport tab is **Private**, show a horizontal strip of the
user’s saved addresses under the search card — same layout role as bus
`PopularDestinations`. Tapping an address fills the private-car **drop-off**
field. If there are no addresses (or the user cannot see them), the section
is hidden entirely.

## Decisions (locked)

| Topic | Decision |
|---|---|
| Content | Saved addresses only (not popular cities / landmarks) |
| Layout | Horizontal gradient cards mirroring bus popular destinations |
| Visibility | Private tab only; hide when guest, loading, error, or empty list |
| Tap | Set car search **drop-off (To)** |
| Same as pickup | Dim + non-tappable when coordinates match current pickup |
| Card title | `SavedAddress.name` only (up to 2 lines, wraps) |
| Card subtitle | None |
| Field label | `CarPlace.label` = `mapLocation.addressName` |
| “See all” / manage | None — address book stays under Profile |
| State wiring | Approach 1 — `HomeScreen` coordinates strip ↔ search card (mirror bus) |
| Pagination | Page 1 from `addressesProvider` only |

## Scope

**In**
- New `SavedAddressesStrip` widget under `home/presentation/widgets/`
- Wire into `home_screen.dart` for Private tab visibility
- Extend `HomeSearchCard` / `CarSearchForm` so drop-off can be set from outside
- Map `SavedAddress` → `CarPlace`
- Hide section for guest / loading / error / empty
- Dim cards that match current pickup coordinates
- l10n keys for section title (AR + EN)
- Widget tests for hide rules and tap → drop-off

**Out**
- Popular destinations / landmarks for private car
- Suggestions inside the map place picker
- Creating or editing addresses from Home
- Flight / bus tab changes
- Load-more / full address-book UI in the strip
- Guest sign-in CTA on the strip

## Architecture

### Ownership

`HomeScreen` holds:

- `_transportTab`
- `CarPlace? _carFrom` / `CarPlace? _carTo` for coordination (or equivalent
  callbacks from `HomeSearchCard`), parallel to bus `_fromCity` / `_toCity`

Recommended contract:

```dart
// HomeSearchCard / CarSearchForm (additions)
CarPlace? toPlace;                    // controlled drop-off from parent
CarPlace? fromPlace;                  // so strip can exclude matching pickup
ValueChanged<CarPlace?>? onToPlaceChanged;
ValueChanged<CarPlace?>? onFromPlaceChanged;

// SavedAddressesStrip
final bool visible;                   // true iff private tab
final CarPlace? excludePlace;         // current pickup
final ValueChanged<CarPlace> onSelected;
```

`SavedAddressesStrip` watches `guestModeProvider` and `addressesProvider`
when `visible`. Guests: do not rely on a failed fetch — treat as hidden
without requiring a successful address list.

### Mapping

```dart
CarPlace fromSaved(SavedAddress a) => CarPlace(
  latitude: a.mapLocation.latitude,
  longitude: a.mapLocation.longitude,
  label: a.mapLocation.addressName,
);
```

Exclude / dim when `excludePlace != null && place.sameCoordinates(excludePlace)`.

### Placement

```
ShellTabScrollView
  HomeSearchCard
  PopularDestinations        // bus tab only (unchanged)
  SavedAddressesStrip        // private tab only (new)
```

## UI

- Section title: l10n key `homeSavedAddresses` (add to `app_en.arb` +
  `app_ar.arb`) — not `homePopularDestinations`
- Cards: reuse visual language of `_DestCard` (gradient alternate, map-pin,
  press scale, `AppRadius`, tokens) with name only (`maxLines: 2`, wraps)
- Empty / loading / error / guest → `SizedBox.shrink()`
- RTL: `EdgeInsetsDirectional`, auto-mirroring list scroll
- Responsive: card width from viewport like popular destinations (`~2.2`
  visible slots); no fixed layout container widths beyond that pattern
- Icons: `PhosphorIconsLight.*`

## Error handling

- API failure: hide strip (no error banner on Home)
- Guest: hide strip
- Empty `items`: hide strip

## Testing

- Hide when `visible: false`, guest, empty, loading, error
- Tap selects drop-off with correct lat/lng/label
- Card matching pickup is not tappable
- Pump under `Locale('ar')` at minimum

## Out of scope reminders

This does **not** reverse the addresses v1 non-goal for in-picker address
book; it only adds a Home Private-tab shortcut into drop-off, using the
existing Profile address book data.
