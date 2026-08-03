# Popular Destinations → Bus “To” Field — Design

_Date: 2026-08-03 | Status: approved for planning + implementation_

## Purpose

Replace the hardcoded Luxor/Aswan popular-destination cards on Home with a
live horizontal list from `busLocationsProvider` (same source as the bus
city pickers). Tapping a city fills the bus search **To** field. The section
is visible only while the transport tab is **Bus**.

## Decisions (locked)

| Topic | Decision |
|---|---|
| Source | All cities from `busLocationsProvider` |
| Layout | Horizontal scroll of destination cards |
| Visibility | Show only when bus search tab is selected; hide for car / flight / train |
| Tap | Set Home search **To** to that `BusLocation` |
| Same as **From** | Ignore tap (no change to **To**); optionally dim that card |
| Price on cards | Remove |
| “See all” | Remove |
| State wiring | Approach 1 — parent (`HomeScreen`) coordinates callbacks between search card and popular list |

## Scope

**In**
- Wire `PopularDestinations` to `busLocationsProvider`
- Horizontal list of all locations with localized `displayName`
- Bus-tab-only visibility
- Tap → update **To** on `HomeSearchCard`
- Block tap when city id equals current **From** id
- Loading / empty / error: hide section (no crash); optional light shimmer while loading is acceptable if already patterned elsewhere — default **hide when not data**
- Remove unused ARB keys only if they become orphaned (`homeCityLuxor`, `homeCityAswan`, price-related if any)

**Out**
- Popular ranking / curated subset API
- “See all” screen
- Prices / fares on cards
- Popular destinations for car / flight / train
- Changing **From** via popular cards

## Architecture

### Ownership

`HomeScreen` holds:

- `_transportTab`
- Current `BusLocation? _fromCity` and `BusLocation? _toCity` for coordination  
  **or** receives updates from `HomeSearchCard` via callbacks and passes
  `toCity` / `onToCityChanged` / `fromCityId` down.

Recommended contract:

```dart
// HomeSearchCard (additions)
BusLocation? toCity;                 // optional controlled To
ValueChanged<BusLocation?>? onToCityChanged;
ValueChanged<BusLocation?>? onFromCityChanged; // so parent knows exclude id

// PopularDestinations
final bool visible;                  // true iff bus tab
final int? excludeCityId;            // current From id
final ValueChanged<BusLocation> onSelected;
```

`PopularDestinations` watches `busLocationsProvider` when `visible`.

### Tap handling

```dart
void _onPopularSelected(BusLocation city) {
  if (_fromCity != null && city.id == _fromCity!.id) return;
  // update To on search card / parent state
}
```

Cards whose `id == excludeCityId` should not invoke selection (and may use
reduced opacity / ignore pointers).

### UI

- Title row: `homePopularDestinations` only (no `homeSeeAll` button).
- Horizontal `ListView` of cards; city label via `displayName(locale)`.
- Alternate existing brand gradients (primary blue / secondary amber family)
  by index `% 2` — reuse `AppColors`, no new hardcoded hex if tokens cover it.
  Existing card already used literal blues/ambers; prefer `AppColors.primary` /
  `AppColors.secondary` (or existing hero tones) when rewriting.

### Errors / empty / loading

| State | Behavior |
|---|---|
| `visible == false` | Render nothing |
| Loading | Hide section (or tiny shimmer — hide is default) |
| Empty list | Hide section |
| Error | Hide section |

## Testing

- Selecting a popular city updates **To** label / state on the search card.
- Selecting the same city as **From** does not change **To**.
- Section finds widgets when bus tab selected; finds nothing on another tab.
- With empty locations async data, section not shown / no exception.

## Files (expected)

| Action | Path |
|---|---|
| Modify | `lib/features/home/presentation/widgets/popular_destinations.dart` |
| Modify | `lib/features/home/presentation/home_screen.dart` |
| Modify | `lib/features/home/presentation/widgets/home_search_card.dart` |
| Modify | `lib/l10n/app_en.arb` / `app_ar.arb` (only if removing orphan keys) |
| Create/Modify | `test/features/home/presentation/...` |

## Success criteria

- On Home bus tab: horizontal list of API cities; tap fills **To**.
- Switching away from bus tab hides the section.
- Tapping the current **From** city is a no-op.
