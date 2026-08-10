# Private Order Stop Names — Design

_Date: 2026-08-10 | Status: approved for planning + implementation_

## Purpose

Populate `departure.name` and `destination.name` on `POST /private/orders`
automatically. The user never types a stop name. Prefer Google’s public/known
place name; otherwise send `"Street, City"`.

## Decisions (locked)

| Topic | Decision |
|---|---|
| Known name | Places `displayName` when present for a named place (POI / establishment / landmark) |
| Fallback | `"Street, City"` from geocode/Places address components (route + locality); omit missing parts |
| When | At pick time (autocomplete details, reverse geocode, GPS) — store on `CarPlace.label` |
| Format | `"Street, City"` (comma + space) |
| Saved addresses | Keep `mapLocation.addressName` as the label/name |
| Order payload | Include `name` on both `departure` and `destination` |
| Empty | If resolution fails → `""` (UI still uses `displayLabel` fallback) |
| Approach | Enrich Places client + shared resolver; mapper reads `CarPlace.label` |

## Scope

**In**
- `PlaceNameResolver` in `core/places/`
- Enrich `PlacesClient.placeDetails` and `reverseGeocode`
- Add `departureName` / `destinationName` to `CarCreateOrderRequest` and JSON body
- Unit tests for resolver, Places parsing, mapper body

**Out**
- Manual name entry UI
- Re-geocoding only at confirm
- Changing quote/search APIs
- Backfilling old orders

## Name resolution

```text
if displayName (known place) non-empty → use it
else if street and city → "Street, City"
else if street only → street
else if city only → city
else → ""
```

### Places details (autocomplete pick)

Field mask includes `displayName`, `formattedAddress`, `location`, and
address components / short formatted fields needed for street + city.

Priority: known `displayName` first; else compose street + city (do **not**
prefer full `formattedAddress` as the order name).

### Reverse geocode (map pan / GPS)

Parse `address_components`:

- Street: `route` (optionally with `street_number` if useful; default **route
  only** unless both are trivially available as `"number route"`)
- City: `locality`, else `administrative_area_level_2`, else
  `administrative_area_level_1`

Apply the same resolver. Ignore raw `formatted_address` for the stored label
except as a last-resort when components are missing **and** no better parts
exist — prefer `""` over dumping a full multi-line formatted address if
street/city cannot be extracted. **Locked:** if street/city cannot be
extracted, use `""` (do not fall back to full `formatted_address`).

### Saved address

`label = addressName` — no Places call.

## Architecture

```
Map / Autocomplete / GPS
        ↓
  PlacesClient (enriched)
        ↓
  PlaceNameResolver → CarPlace.label
        ↓
  CarSearchParams.from / .to
        ↓
  CarDtoMapper.createOrderBody
        ↓
  departure.name / destination.name
```

### Request body (additions)

```json
{
  "trip_id": 1,
  "rounded": false,
  "departure": {
    "latitude": "...",
    "longitude": "...",
    "date": "yyyy-MM-dd HH:mm",
    "name": "Cairo Airport"
  },
  "destination": {
    "latitude": "...",
    "longitude": "...",
    "date": "yyyy-MM-dd HH:mm",
    "name": "Nile Corniche, Cairo"
  }
}
```

`CarCreateOrderRequest` gains `departureName` and `destinationName` (String),
filled from `params.from.label` / `params.to.label`.

Pay order reuses the same body builder — `name` is included there too.

## Error handling

- Places/geocode failure → `label: ''`; order still posts with `"name": ""`
- Never block search or confirm solely because name resolution failed

## Testing

- Resolver: known name wins; street+city; street only; city only; empty
- `reverseGeocode` fixture with `address_components`
- `placeDetails` fixture with `displayName` vs components-only
- Mapper includes `name` keys in body

## Out of scope reminders

Does not change the map picker UX beyond the label string quality. Does not
add a name field to the confirm screen.
