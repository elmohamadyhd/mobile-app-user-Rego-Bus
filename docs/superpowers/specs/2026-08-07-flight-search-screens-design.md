# Flight search screens — design

**Date:** 2026-08-07  
**Status:** Approved (pending spec review)

## Goal

Wire the Home **Flight** tab to a real one-way flight search flow: an airport
picker for origin/destination, `POST /flights/search` for offers, a results
screen to browse them, and an offer details screen for the full breakdown.
Booking (passenger entry, bundles, hold, payment) is explicitly out of scope —
this spec stops at "browse offers," matching how the private-car spec stopped
at "browse quotes" before its booking flow was designed separately.

## Decisions (confirmed with product)

| Question | Choice |
|----------|--------|
| Scope | **Search flow only** — Home tab, airport picker, results, offer details. No passenger/payment screens. |
| Trip type | **One-way only** — round-trip/multi-city hidden until their request body is confirmed against the live API |
| Airport picker source | **`GET /flights/airports/search`** (ranked, has "all airports in city" entries) — `GET /flights/iata` stays unused in the UI |
| "Select flight" CTA | **Tappable, shows a "coming soon" snackbar** — matches how the Home flight tab already handles unsupported taps |

## Current state

- `lib/features/flight/` has **data + domain layers only** (built in a prior
  session): entities, DTO mapper, `FlightApi`, `FlightRepositoryImpl`, and
  `flight_providers.dart` (bare `flightApiProvider` / `flightRepositoryProvider`,
  no booking state yet).
- Home Flight tab (index `2` in `TransportModeTabBar`) shows a "coming soon"
  snackbar (`lib/features/home/presentation/widgets/home_search_card.dart`).
  The tab already renders a cabin-class picker (`_ClassField` /
  `FlightClass`) but reuses the **bus city picker** for From/To — wrong for
  flights, which need airport IATA codes, not bus city IDs.
- `homeOnePax` ("1 passenger") exists in both `.arb` files but is unused
  anywhere in the app — leftover placeholder for the passenger-count control
  this spec adds.
- `TripType` (`lib/shared/models/trip_type.dart`) only has `oneWay` /
  `roundTrip` — no `multiCity` — consistent with scoping multi-city out.

## Backend API

Full request/response shapes (including the ones this spec doesn't use) are
documented in the DTO extraction done in the prior session; summarized here
for the endpoints this spec touches.

### `GET /flights/airports/search?term=`

Ranked, non-paginated. Response `data` items:

```json
{
  "iata_code": "DXB",
  "name": "All Airport",
  "city": "Dubai",
  "country_code": "AE",
  "country": "UNITED ARAB EMIRATES",
  "latitude": 25.26948,
  "longitude": 55.30883,
  "is_domestic": false,
  "is_all_airport": true,
  "ranking": 179
}
```

`term` is required — a `400` with `{"term": "The term field is required."}`
comes back for an empty query; the picker must not fire the search until at
least 1–2 characters are typed.

### `POST /flights/search`

Request body — **note the misspelled `curreny` key is required** (`currency`
is silently rejected as an invalid value by the backend):

```json
{
  "origin": "CAI",
  "destination": "RUH",
  "date": "2026-09-15",
  "passengers": [{ "passengerTypeCode": "ADT", "count": 1 }],
  "sortingCriteria": "CheapestFirst",
  "cabinClass": "CABIN_CLASS_ECONOMY",
  "directFlightsOnly": false,
  "trip_type": "one_way",
  "curreny": "SAR"
}
```

Response `data` is an array of offers (already modeled as `FlightOffer` /
`FlightJourney` / `FlightSegment` / `FlightPriceClass` in
`lib/features/flight/domain/entities/flight_offer.dart`). One-way offers have
exactly one `journeys[]` entry. Empty result is `200` with `data: []`, not an
error.

### Known gaps (out of scope, do not build against)

`Bundles`, `Add Passenger`, `Hold Trip`, `Pending Trip` have no confirmed
response shape — Bundles fails with "offer id is not valid or expired" even
seconds after a fresh search, and Pending Trip's documented route 404s. These
stay as unparsed `Future<dynamic>` stubs on `FlightApi` until the backend team
confirms real payloads. `Confirm Order` has a full DTO already but its
success behavior on the demo backend is unverified (see the warning docstring
on `FlightConfirmedOrder`) — not used by this spec either way.

## Non-goals

- Bundles, passenger entry, hold/pending trip, confirm order, payment,
  tickets.
- Round-trip or multi-city search.
- The `GET /flights/iata` endpoint (kept in `FlightApi` for later, unused in UI).
- Guest gate / auth wall — flight search endpoints don't appear to require a
  bearer token (unlike bus/car); revisit if that turns out wrong in testing.
- Multi-passenger types (child/infant) — adults only, 1–9.

## Architecture

```
lib/features/flight/
├── data/                              # existing
│   ├── flight_api.dart
│   ├── flight_dto_mapper.dart
│   └── flight_repository_impl.dart
├── domain/                            # existing
│   ├── entities/
│   │   ├── flight_iata_airport.dart
│   │   ├── flight_airport_suggestion.dart
│   │   ├── flight_offer.dart
│   │   ├── flight_confirmed_order.dart
│   │   ├── flight_search_params.dart
│   │   └── flight_pagination.dart
│   └── repositories/
│       └── flight_repository.dart
└── presentation/                      # new
    ├── flight_routes.dart
    ├── flight_search_form.dart        # home Flight tab widget
    ├── flight_results_screen.dart
    ├── flight_offer_details_screen.dart
    ├── providers/
    │   └── flight_booking_providers.dart   # replaces flight_providers.dart
    └── widgets/
        ├── flight_airport_field.dart       # collapsed row on the form, mirrors bus _CityField
        ├── flight_airport_picker_sheet.dart # showFlightAirportPicker(...)
        ├── flight_passenger_count_field.dart
        ├── flight_offer_card.dart
        └── flight_segment_row.dart          # shared between results card + details screen
```

`flight_providers.dart` (bare API/repo providers, no state) is deleted; its
two providers move into `flight_booking_providers.dart` alongside the new
`FlightBookingState`/`FlightBookingNotifier` — matching
`bus_booking_providers.dart`, which houses both.

## Airport picker

`showFlightAirportPicker(context, title: ...)` — bottom sheet, structurally
like `showBusCityPicker` (search field + list, `useRootNavigator: true` so it
paints above `MainShell`'s floating nav bar), but the list comes from a live
debounced network call instead of a client-filtered cached list — there's no
"all flight airports" list to cache.

- Text field with a 300 ms debounce timer; below ~2 characters, show an idle
  "type to search" state instead of calling the API (avoids the guaranteed
  `400` on an empty `term`).
- Loading, empty ("No airports found"), and error (inline retry) states.
- Each row: airport name, city, country, IATA code chip; `is_all_airport`
  rows get a distinct "All airports" subtitle instead of a city name repeat.
- Selecting a row pops the sheet with a `FlightAirportSuggestion`.

No new Riverpod state needed here — the picker owns a local
`Future`/`Timer`-based debounce in its own `State`, same lifecycle scope as
the bus picker's `TextEditingController`.

## Search form (Home Flight tab)

`FlightSearchForm` replaces the current bus-form branch in
`home_search_card.dart` when `selectedTab == flightTabIndex`, the same way
`CarSearchForm` already replaces it for the Private tab.

| Control | Maps to |
|---------|---------|
| Origin field (`FlightAirportField`) | `FlightAirportSuggestion origin` |
| Destination field | `FlightAirportSuggestion destination` |
| Swap button | swaps origin ↔ destination |
| Departure date | `date` (one-way only — no trip-type toggle shown) |
| Cabin class (existing `_ClassField`) | `cabinClass` |
| Passenger count (new stepper, 1–9 adults) | `passengers: [{ADT, count}]` |
| Primary CTA | localized "Search flights" |

Validation before search: both airports set, origin ≠ destination (compare
IATA code), date not in the past — same shape as the car form's checks.

## Results screen

**Route:** `FlightRoutes.results` → `/flight/results`  
**Screen:** `FlightResultsScreen` — `BookingAppBar` titled "CAI → RUH".

Body, driven by `flightBookingProvider`:

| State | UI |
|-------|-----|
| Loading | skeleton cards (mirrors `TripResultsScreen`'s `_LoadingSkeleton`) |
| Error | inline error banner + retry (re-runs `search` with stored params) |
| Empty | "No flights found" message |
| Success | `ListView` of `FlightOfferCard` |

`FlightOfferCard` per offer: marketing carrier logo/code, first segment's
departure/arrival time + airport codes, total duration, stop count ("Direct"
/ "1 stop"), `totalAmount` + `currency`. Tapping a card pushes
`FlightOfferDetailsScreen` with the tapped `FlightOffer` (via `extra` — no
need for `selectedOffer` in shared state since navigation is one level deep
and the object is already fully hydrated from Search).

## Offer details screen

`FlightOfferDetailsScreen(offer: FlightOffer)` — no network call; purely
renders what Search already returned:

- Per journey (always 1, one-way): each `FlightSegment` as a
  `FlightSegmentRow` (departure/arrival time + terminal, flight number,
  carrier, equipment, layover gap between segments when `segments.length > 1`).
- Fare rules: `priceClasses[].rulesAndPenalties` as a bulleted list when
  present, hidden when null.
- Price breakdown: base, taxes, discount (if any), total.
- Pinned bottom CTA "Select this flight" — tappable, shows the same
  `homeComingSoon`-style snackbar as the Home tab today.

## Data flow

```
Home (Flight tab)
  └─ FlightSearchForm
       ├─ showFlightAirportPicker  (origin / destination fields)
       └─ on Search:
            FlightBookingNotifier.search(params)
              └─ FlightRepository.search
                   └─ FlightApi POST /flights/search
            → context.push(FlightRoutes.results)

FlightResultsScreen
  └─ watches flightBookingProvider (offers list + status)
  └─ on card tap → push FlightOfferDetailsScreen(offer: tapped)
       └─ "Select this flight" → "coming soon" snackbar
```

## Auth & errors

Flight search endpoints haven't shown a `401` gate in testing (unlike bus/car
search) — no guest gate wired into this spec. If a `401` shows up during
implementation, surface it the same way bus/car do (`ApiException` message on
the results screen, no special handling invented here).

| Condition | User-facing behavior |
|-----------|----------------------|
| Airport search network fail | Inline retry under the picker's list |
| Airport search zero results | "No airports found" in the sheet |
| Search API empty | Empty state on results screen |
| Search API error | Error banner on results + retry |
| Offer details | No network call — cannot fail independently of results |

## State management

```dart
enum FlightBookingStatus { idle, searching, error }

@freezed
abstract class FlightBookingState with _$FlightBookingState {
  const factory FlightBookingState({
    FlightSearchParams? searchParams,
    @Default([]) List<FlightOffer> offers,
    @Default(FlightBookingStatus.idle) FlightBookingStatus status,
    String? error,
    String? searchFromLabel,
    String? searchToLabel,
  }) = _FlightBookingState;
}
```

`FlightBookingNotifier extends Notifier<FlightBookingState>`, one method:
`Future<void> search(FlightSearchParams params)` — mirrors
`BusBookingNotifier.searchTrips`.

## Routing

```dart
// flight_routes.dart
abstract final class FlightRoutes {
  static const results = '/flight/results';
}

List<RouteBase> flightRoutes() => [
  GoRoute(
    path: FlightRoutes.results,
    builder: (_, __) => const FlightResultsScreen(),
  ),
];
```

Register `...flightRoutes()` in `app_router.dart` alongside `...busRoutes()`
and `...carRoutes()`. `FlightOfferDetailsScreen` is pushed with `extra` from
the results screen directly (no route needed) — same pattern car uses for
screens that only ever navigate from one place with a required object.

## Localization

New keys in `app_en.arb` / `app_ar.arb`:

- `flightOrigin`, `flightDestination`
- `flightAirportSearchHint` ("Search airport or city")
- `flightAirportSearchEmpty` ("No airports found")
- `flightAllAirportsIn` ("All airports in {city}")
- `flightPassengers`, `flightPassengersCount` ("{count} passenger(s)")
- `flightSearch` (form CTA)
- `flightResultsTitle` fallback, `flightResultsNoOffers`, `flightResultsError`, `flightResultsRetry`
- `flightDirect`, `flightStops` ("{count} stop(s)")
- `flightSelectThisFlight`, `flightBookingComingSoon`
- `flightFareRules`
- `flightPriceBase`, `flightPriceTaxes`, `flightPriceDiscount`, `flightPriceTotal`
- `flightSearchSelectAirports`, `flightSearchSamePlace`

`homeTabFlight` and `homeFlightClass`/`homeOnePax` already exist and are
reused as-is.

Run `flutter gen-l10n` after adding keys.

## Testing

| Test | Covers |
|------|--------|
| `flight_dto_mapper_test.dart` | Already exists implicitly via manual verification against live payloads in the prior session — add unit tests: envelope → `FlightOffer` list, empty array, pagination parsing, `curreny` typo in request body builder |
| `flight_booking_notifier_test.dart` | `search` success/empty/error; preserved `searchParams` on retry |
| `flight_offer_card_test.dart` | Renders time/duration/stops/price; RTL locale |
| `flight_search_form_test.dart` | Validation blocks search when airports missing or identical |
| `flight_airport_picker_sheet_test.dart` | Debounce doesn't fire below 2 chars; empty/error states |

## File checklist (implementation plan input)

| # | File / area |
|---|-------------|
| 1 | `lib/features/flight/presentation/providers/flight_booking_providers.dart` (new; delete `flight_providers.dart`) |
| 2 | `lib/features/flight/presentation/widgets/flight_airport_field.dart` |
| 3 | `lib/features/flight/presentation/widgets/flight_airport_picker_sheet.dart` |
| 4 | `lib/features/flight/presentation/widgets/flight_passenger_count_field.dart` |
| 5 | `lib/features/flight/presentation/widgets/flight_offer_card.dart` |
| 6 | `lib/features/flight/presentation/widgets/flight_segment_row.dart` |
| 7 | `lib/features/flight/presentation/flight_search_form.dart` |
| 8 | `lib/features/flight/presentation/flight_results_screen.dart` |
| 9 | `lib/features/flight/presentation/flight_offer_details_screen.dart` |
| 10 | `lib/features/flight/presentation/flight_routes.dart` |
| 11 | `lib/features/home/.../home_search_card.dart` — wire Flight tab to `FlightSearchForm` |
| 12 | `lib/core/router/app_router.dart` — `...flightRoutes()` |
| 13 | `lib/l10n/app_en.arb`, `app_ar.arb` |
| 14 | Tests listed above |
