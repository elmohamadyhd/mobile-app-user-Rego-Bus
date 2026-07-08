# Multi-Vehicle Architecture — Design Spec
_Date: 2026-07-08 | Status: approved_

## Scope

Define the app-wide feature structure for supporting multiple transport modes —
bus, private car, flight now; train, ship, cruise, hotel later — and the
migration path from today's bus-only `features/booking/` into that structure.

Out of scope: actual screen implementation (covered by mode-specific specs,
e.g. `2026-06-30-booking-flow-design.md` for bus), real payment integration,
train/ship/cruise/hotel (structure only needs to accommodate them later).

---

## Why this shape

The backend confirms the three current modes are genuinely different systems,
not one system with a `mode` parameter (see `docs/business-overview.md`,
`docs/wadeny-apis.md`):

| Mode | Backend flow | Session shape |
|------|-------------|----------------|
| Bus | `search locations/stations` → `search trips` → `trip details` → `select seats` → `create-ticket` | stateless, keyed by `trip_id` |
| Flight | `search airports` → `search flights` → `browse bundles` → `hold offer` → `add passengers` → `confirm order` | stateful, keyed by `offer_id` across steps |
| Private car | `search` by GPS coords (`from_latitude/longitude`, `to_latitude/longitude`, `rounded`) → `create order` | stateless quote, no seat/offer concept |

Each mode also has its own request/response shapes, its own currency handling
(flights carry `currency`), and its own address-book integration (private
transfers reuse saved GPS locations). There is no shared backend contract to
mirror in the data layer. Given that, and the user's explicit choice, the app
uses **Approach B: fully independent features per mode** — each mode owns its
entire booking flow (data, domain, presentation) end to end.

**What "independent" does and doesn't mean:** each feature owns its booking
logic — search, results/quote, passenger or contact capture, payment, and
ticket/voucher. Framework primitives (`core/` — Dio client, router, theme,
config, storage, utils — and `shared/` — `PrimaryButton`, `GradientHero`,
`AppScaffold`, brand widgets) stay shared; duplicating those would just be a
second copy of the app's framework, not feature isolation.

**Accepted cost:** passenger capture, payment method selection, and
ticket/voucher rendering are implemented three times (once per mode). This is
a deliberate trade for merge-safety and independent iteration — confirmed by
the user, who plans to build out each mode's full workflow separately.

---

## Top-level structure

```
lib/features/
├── bus/          ← refactored out of today's `booking`
│   ├── data/          bus_api.dart · dto/ · bus_repository_impl.dart · mock_bus_data.dart
│   ├── domain/        entities/ (BusTripSummary, BusTripDetail, SeatMap, BusTicket)
│   │                  repositories/bus_repository.dart
│   └── presentation/  bus_search_form.dart · results/detail/seat-selection screens
│                      · passenger/payment/ticket screens · providers/ · bus_routes.dart
├── flight/
│   ├── data/          flight_api.dart · dto/ · flight_repository_impl.dart · mock_flight_data.dart
│   ├── domain/        entities/ (FlightOffer, FlightSegment, FareBundle, FlightTicket)
│   │                  repositories/flight_repository.dart
│   └── presentation/  flight_search_form.dart · results/detail/bundle screens
│                      · passenger/payment/ticket screens · providers/ · flight_routes.dart
└── car/          ← on-demand quote flow, not a results list
    ├── data/          car_api.dart · dto/ · car_repository_impl.dart · mock_car_data.dart
    ├── domain/        entities/ (CarTier, RideQuote, RideBooking)
    │                  repositories/car_repository.dart
    └── presentation/  car_search_form.dart · tier-options/ride-detail screens
                       · contact/payment/voucher screens · providers/ · car_routes.dart
```

Unchanged in role: `core/` (network, router, theme, config, storage, utils),
`shared/` (presentational widgets), and the `auth` / `home` / `profile` /
`shell` features.

The current `booking` feature is renamed and reshaped into `bus` — its
`TripSummary`/`TripDetail`/seat/`ETicket` models become explicitly bus-owned,
and the flight fields already leaking into `BookingFlowState` (`flightClass`,
round-trip) move into `flight`, where they belong natively.

---

## Inside a feature

### Scheduled-inventory shape — `bus` and `flight`

Flow: **search form → results list → detail → seat/bundle selection →
passenger → payment → ticket.**

`bus` (mirrors the current, working flow):

```
bus/
├── domain/
│   ├── entities/   bus_trip.dart (BusTripSummary, BusTripDetail)
│   │               seat_map.dart (SeatRow, SeatCell, SeatStatus)
│   │               bus_passenger.dart · bus_ticket.dart
│   └── repositories/bus_repository.dart
│       // searchStations · searchTrips · tripDetail · seatMap · createTicket
├── data/
│   ├── dto/        bus_trip_dto.dart · seat_map_dto.dart · bus_ticket_dto.dart
│   ├── bus_api.dart               ← Dio calls to /buses/*
│   ├── bus_repository_impl.dart   ← DTO → entity mapping
│   └── mock_bus_data.dart         ← today's mock, moved here
└── presentation/
    ├── providers/bus_booking_providers.dart  ← BusBookingNotifier + BusBookingState
    ├── bus_search_form.dart
    ├── bus_results_screen.dart · bus_trip_details_screen.dart · bus_seat_selection_screen.dart
    ├── bus_passenger_screen.dart · bus_payment_screen.dart · bus_ticket_screen.dart
    ├── bus_routes.dart
    └── widgets/  trip_card.dart · seat_grid.dart · amenity_chip.dart
```

`flight` reuses the skeleton but its state is **keyed by `offer_id`**, not a
simple trip id, because the backend session (`hold` → `passengers` →
`confirm`) spans that key across steps:

```
flight/
├── domain/
│   ├── entities/   flight_offer.dart (FlightOfferSummary, FlightOfferDetail, FlightSegment)
│   │               fare_bundle.dart · flight_passenger.dart · flight_ticket.dart
│   └── repositories/flight_repository.dart
│       // searchAirports · searchFlights · bundlesFor(offerId) · holdOffer(offerId)
│       // addPassengers(offerId, ...) · confirmOrder(offerId)
├── data/  dto/ · flight_api.dart (Dio calls to /flights/*) · flight_repository_impl.dart · mock_flight_data.dart
└── presentation/
    ├── providers/flight_booking_providers.dart
    │   // FlightBookingState carries offerId once search resolves it,
    │   // and every subsequent step (bundle, hold, passengers, confirm) uses it.
    ├── flight_search_form.dart        ← from/to airport, dates, cabin class, round-trip
    ├── flight_results_screen.dart · flight_offer_details_screen.dart · flight_bundle_screen.dart
    ├── flight_passenger_screen.dart · flight_payment_screen.dart · flight_ticket_screen.dart
    ├── flight_routes.dart
    └── widgets/  offer_card.dart · segment_timeline.dart · bundle_card.dart
```

### On-demand-quote shape — `car`

Flow: **search form → tier options (quoted) → ride detail → contact →
payment → voucher.** No departures list, no seat map, no offer/session key —
the backend returns priced options directly from GPS coordinates.

```
car/
├── domain/
│   ├── entities/   car_tier.dart (economy/SUV/van, capacity, quoted price)
│   │               ride_quote.dart (pickup, dropoff, requested time, tier options)
│   │               ride_contact.dart · ride_booking.dart (voucher)
│   └── repositories/car_repository.dart
│       // quote(fromCoords, toCoords, {rounded}) · createOrder(...)
├── data/  dto/ · car_api.dart (Dio calls to /private/*) · car_repository_impl.dart · mock_car_data.dart
└── presentation/
    ├── providers/car_booking_providers.dart  ← CarBookingNotifier + CarBookingState
    ├── car_search_form.dart           ← pickup + drop-off (from address book or map pick) + time
    ├── car_tier_options_screen.dart · car_ride_detail_screen.dart
    ├── car_contact_screen.dart · car_payment_screen.dart · car_voucher_screen.dart
    ├── car_routes.dart
    └── widgets/  tier_card.dart · route_preview.dart
```

**Boundary call:** stateless presentational atoms with no booking logic
(a labeled input, a payment-method radio tile, a price row) may live in
`shared/widgets` even though the screens that use them are duplicated — that
keeps duplication to flow/state, not pixels. Lift on second use (rule of
three), not preemptively.

---

## Home and routing

`home` stays a thin composition layer: it owns the tab bar and popular
destinations, but no booking logic. Each feature exposes its own search-form
widget (`BusSearchForm`, `FlightSearchForm`, `CarSearchForm`); `home` swaps in
the one for the active tab and knows nothing about what's inside it.

On submit, each form produces a params object **owned by its own feature**
(e.g. `BusSearchParams`, keyed differently per mode since bus needs
cities+date, flight needs airports+dates+cabin+trip-type, car needs
coordinates+time). `home` passes the params to that feature's notifier and
navigates to that feature's first route. `home`'s only knowledge of each mode
is: its search-form widget, its params type, and its entry route.

Routing is federated instead of one growing `AppRoutes` god-class:

```
bus/presentation/bus_routes.dart       → BusRoutes.results/detail/seats/passenger/payment/ticket   (/bus/…)
flight/presentation/flight_routes.dart → FlightRoutes.results/detail/bundle/passenger/payment/ticket (/flight/…)
car/presentation/car_routes.dart       → CarRoutes.tiers/detail/contact/payment/voucher            (/car/…)
```

`core/router/app_router.dart` becomes an aggregator: it spreads each
feature's exported route list into the single `GoRouter`, alongside the
unchanged auth routes and `MainShell`. Cross-feature navigation always goes
through route string constants — never by importing another feature's
providers or widgets. That import boundary is what makes the isolation real,
not just a folder convention.

---

## Migration path

Four phases. Each phase leaves `flutter analyze && flutter test` green and
the app in a shippable state.

**Phase 1 — Reshape `booking` → `bus`** (refactor only, no new modes)
- Move `features/booking/` → `features/bus/`; update imports.
- Rename to bus-owned entities: `TripSummary`→`BusTripSummary`,
  `TripDetail`→`BusTripDetail`, `ETicket`→`BusTicket`.
- Split `BookingFlowNotifier`/`State` → `BusBookingNotifier`/`BusBookingState`;
  drop the flight leakage (`flightClass`, flight-only round-trip handling).
- Introduce the missing data boundary: `domain/repositories/bus_repository.dart`
  + `data/bus_repository_impl.dart` wrapping today's `MockBookingData`. The
  notifier stops reading mock data directly — this makes `bus` a correct
  three-layer slice and the template `flight`/`car` copy from.
- Extract `bus_search_form.dart` out of `home_search_card.dart`; federate
  routes into `bus_routes.dart`; point `home`'s bus tab at the new form and
  notifier.
- Verify: `flutter analyze && flutter test`, then drive the bus flow
  end-to-end to confirm no regression.

**Phase 2 — Stand up `flight`** (clone the pattern, swap the middle)
- Full slice per the anatomy above, offer-id-keyed state, mock data matching
  the real `/flights/*` shapes (cabin class, trip type, currency, bundles).
- Register `flight_routes.dart`; wire the flight tab; remove its "coming soon".

**Phase 3 — Stand up `car`** (second flow shape)
- Full slice per the anatomy above, GPS-coordinate search, tier-quote
  response, mock data matching `/private/*` shapes.
- Register `car_routes.dart`; wire the private-car tab; remove its "coming soon".

**Phase 4 — Cleanup**
- Lift shared presentational atoms into `shared/widgets` on second use, not
  before.
- Document the per-mode feature convention (this spec) in `CLAUDE.md` and
  `.cursor/rules/architecture.mdc` so future modes (train, ship, cruise,
  hotel) follow the same slice shape without needing to re-derive it.

Sequencing means the app can ship after any phase: Phase 1 alone yields a
clean `bus`; Phase 2 adds flights; Phase 3 adds cars.

---

## Deferred / out of scope

- Real API wiring for bus (repository interface is introduced now; the impl
  can keep using mock data until the backend integration task).
- Concrete screen-by-screen visual design for flight and car (separate specs,
  same pattern as `2026-06-30-booking-flow-design.md`).
- Shared `shared/widgets` extraction candidates — decided opportunistically
  in Phase 4 once flight exists to compare against bus.
- Train, ship, cruise, hotel — structure accommodates them as future sibling
  features but they are not being built now.
