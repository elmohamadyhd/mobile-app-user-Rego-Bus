# Bus Flow Redesign — Design Spec
_Date: 2026-07-08 | Status: approved_

## Scope

The detailed screen-and-flow design for the **`bus` feature slice** (see
`2026-07-08-multi-vehicle-architecture-design.md`), wired to the **real
`/buses/*` backend** and reworked for better UX around the multi-stop /
segment-pricing behavior seen in the legacy "Safaria" app.

- Implements the `bus` feature from the multi-vehicle architecture spec.
- **Supersedes** the bus portions of `2026-06-30-booking-flow-design.md`
  (which used mock data, a single flat trip price, and crammed stop chips into
  the results card).
- **One-way only** this iteration; round trip is deferred (see below).

## Key decisions

| Topic | Decision |
|-------|----------|
| Stop selection | **Dedicated step on the trip-detail screen** — clean results cards; boarding + drop-off pickers with a **live fare** that updates as stops change. |
| Seat class (Economy, Comfort, Business 40, First class, First 10, Prime Mix) | **Per-seat on the seat map.** Each seat carries its `seat_type_id` → type + price. No separate class step; class becomes a seat-map legend/filter. |
| Passengers | **Count only, flat fare.** A stepper on search sets the target seat count; selected seats are the source of truth. No adult/kid price split. |
| Filtering | **Client-side** over already-loaded results (time, price, operator, sort); a re-search only when date/cities change. The legacy filter's departure/arrival-station dropdowns are folded into the trip-detail stop pickers. |
| Round trip | **Deferred.** Build one-way end-to-end first; add round trip as a follow-up (the API books one segment at a time via `create-ticket`). |

## Backend model (why the flow is shaped this way)

The `/buses/*` API works on **cities first, then stations (locations) within
each city**:

- `GET /buses/trips?city_from&city_to&date&currency` → trips between two cities.
- Each trip serves **several boarding locations** in the origin city
  (e.g. October, Zayed, Zamalek, Tagamo3) and **several drop-off locations** in
  the destination (e.g. Ras Sdr, Moussa Coast, Dahab, Ras Shitan).
- `GET /buses/trips/{id}/seats?from_location_id&to_location_id&date` — the seat
  map (and its per-seat pricing) is **keyed to the chosen boarding/drop-off
  pair**. A different pair is effectively a different priced segment — this is
  why the fare changes with stops.
- `POST /buses/trips/{id}/create-ticket` with
  `{from_city_id, to_city_id, from_location_id, to_location_id, date, seats:[{seat_type_id, seat_id}]}`.
- Supporting lookups: `GET /buses/locations`, `/buses/stations`, `/buses/carriers`.

## Screen-by-screen

### 1. Bus search (home "Buses" tab)
- Fields: from-city / to-city (swap), depart date (return hidden — round trip
  deferred), passenger count stepper.
- Data source: city typeahead via `GET /buses/locations`.
- Submit → `searchTrips(...)` → push results. Owns `BusSearchParams`.

### 2. Results
- Header: `Cairo → Sinai · Thu 14 Feb · N pax`, filter button.
- **Decluttered `TripCard`:** operator + logo, class range, `07:00 · 2h · 2 stops · 09:00`,
  compact amenity icons, **"from EGP X"**, Choose. `See routing` opens the full
  ordered route. No stop chips on the card.
- Filter sheet: time range, price range, operator, sort — applied client-side.
- States: loading skeleton, empty ("no trips"), error + retry.
- Choose → `selectTrip(trip)` → push trip detail.

### 3. Trip detail — the redesign
- Operator/route/date header + route timeline (`See routing`) + amenities.
- **Board at** (origin stops) and **Drop off at** (destination stops) — each a
  selectable list of `BusStop { name, area, time }`.
- **Live segment fare** box updates as the pair changes; recomputes
  duration/times for the chosen segment.
- Sets `fromStop` / `toStop` (→ `from_location_id` / `to_location_id`).
- CTA "Choose seats" → `loadSeats(tripId, fromLocationId, toLocationId, date)` → push seats.

### 4. Seat selection
- Legend by **status** (available / reserved / selected) and a **class legend**
  (seat types with their colors).
- `SeatMap`: driver, WC, aisle gaps, seat cells. Tapping a seat shows its
  **type + price**; selecting adds it to a **running total**.
- Target = passenger count (guidance only; user may pick any number — seats
  selected define the final passenger count).
- Continue (enabled when ≥1 seat) → push summary.

### 5. Booking summary
- Trip: cities, date, pax, operator, chosen seats + their classes, chosen
  departure/arrival stations + times, ride time.
- **Promo code** entry → `after discount`; **tax**; **total**.
- Payment method (wallet / card), Terms & conditions checkbox.
- Pay Now → `createTicket(...)` → success overlay ("Bus Booked") → e-ticket.

### 6. Success → e-ticket
- Confirmation, then boarding-pass ticket (reuses the existing e-ticket screen,
  rebound to `BusTicket`).

## Entities (Freezed, `bus/domain/entities/`)

```
BusStop        { locationId, name, area, time }
BusTripSummary { id, operatorName, operatorCode, classLabelRange,
                 departTime, arriveTime, durationMin, stopsCount,
                 amenities: List<String>, fromPriceEgp, currency,
                 boardingStops: List<BusStop>, dropoffStops: List<BusStop> }
BusTripDetail  { summary, routing: List<BusStop>, amenities }
SeatType       { id, label, colorKey }          // Economy … Prime Mix
SeatCell       { seatId, seatTypeId, priceEgp, status }  // + null = aisle, plus driver/WC markers
SeatRow        { cells: List<SeatCell?> }
SeatMap        { rows: List<SeatRow>, types: List<SeatType> }
BusTicket      { bookingRef, tripSummary, fromStop, toStop,
                 seats: List<SeatCell>, totalEgp, issuedAt }
BusSearchParams{ cityFromId, cityToId, date, passengers, currency }
```

Seat `status`: `available | reserved | selected`.

## State & notifier (`bus/presentation/providers/bus_booking_providers.dart`)

`BusBookingState`: `searchParams, trips, status, selectedTrip, fromStop,
toStop, segmentFareEgp, seatMap, selectedSeats, seatsTotalEgp, promoCode,
discountEgp, taxEgp, totalEgp, paymentMethod, ticket, error`.

| Method | Effect |
|--------|--------|
| `searchTrips(params)` | loads trips for the city pair + date |
| `selectTrip(trip)` | sets `selectedTrip`, seeds default `fromStop`/`toStop` + `segmentFare` |
| `setStops(from, to)` | updates the pair, refreshes `segmentFare` |
| `loadSeats()` | fetches the seat map for trip + stop pair + date |
| `toggleSeat(seatId)` | add/remove seat, recompute `seatsTotal` |
| `applyPromo(code)` | sets `discount`, recompute `total` |
| `setPaymentMethod(m)` | wallet / card |
| `confirmBooking()` | `create-ticket`, produce `ticket` |
| `reset()` | back to initial |

## Repository (`bus/domain/repositories/bus_repository.dart`)

```
searchLocations(term)                                  -> List<City>       // GET /buses/locations
searchTrips(cityFrom, cityTo, date, currency, page)    -> List<BusTripSummary>
tripDetail(tripId)                                     -> BusTripDetail
seatMap(tripId, fromLocationId, toLocationId, date)    -> SeatMap
createTicket(tripId, fromCityId, toCityId,
             fromLocationId, toLocationId, date, seats) -> BusTicket
```

Impl in `bus/data/bus_repository_impl.dart` (Dio via `bus_api.dart`, DTO →
entity mapping). Mock stays in `bus/data/mock_bus_data.dart` until live wiring.

## Routes (`bus/presentation/bus_routes.dart`, federated into app_router)

```
/bus/results   /bus/detail   /bus/seats   /bus/summary   /bus/ticket
```

The `BusSearchForm` is embedded by `home`; navigation between bus screens uses
these route constants.

## File layout (`lib/features/bus/`)

```
domain/entities/   bus_stop.dart · bus_trip.dart · seat_map.dart · bus_ticket.dart
domain/repositories/bus_repository.dart
data/              bus_api.dart · dto/ · bus_repository_impl.dart · mock_bus_data.dart
presentation/
  providers/bus_booking_providers.dart
  bus_search_form.dart
  bus_results_screen.dart · bus_trip_details_screen.dart
  bus_seat_selection_screen.dart · bus_summary_screen.dart · bus_ticket_screen.dart
  bus_routes.dart
  widgets/ trip_card.dart · stop_selector.dart · segment_fare_bar.dart
           seat_grid.dart · seat_legend.dart · amenity_chip.dart
```

## Data inventory — nothing from the legacy screens is dropped

| Legacy field | New placement |
|--------------|---------------|
| Operator + logo, class | Results card + summary |
| Depart/arrive time, duration, #stops | Results card + trip detail |
| Amenities (AC, wifi, WC…) | Results card (compact) + trip detail |
| Boarding stops (October…) | **Trip detail — Board at** |
| Drop-off stops (Ras Sdr…) | **Trip detail — Drop off at** |
| Price (changes with stops) | Results "from EGP X" → **live segment fare** on detail → seat total |
| See Routing | Trip detail route timeline |
| Time/price/operator/station filters, sort | Results filter sheet (station → trip-detail stops) |
| Seat map, legend, reserved/available/selected, WC, driver | Seat selection |
| Passengers (1 adult, 1 kid) | Search stepper (count only) + summary |
| Departure/arrival stations + times | Summary (from the chosen stops) |
| After-discount, promo code, tax, total | Summary |
| Terms & conditions, Pay Now | Summary |
| "Bus Booked" success | Success overlay → e-ticket |

## Error / empty / loading

- Trip search: skeleton cards → results / empty / error+retry.
- Seat load: spinner; `reserved` seats non-selectable; Continue disabled at 0 seats.
- Promo: inline invalid-code message; total unchanged on failure.
- Confirm: button spinner during `create-ticket`; failure keeps the user on
  summary with a retry-able error.

## Deferred / out of scope

- Round trip (two-leg booking) — next iteration.
- Real payment gateway (wallet/card selection is captured; charging is a later task).
- Multi-city / multi-passenger per-seat names (count-only this iteration).
- Live API wiring may lag behind the UI: the repository interface lands now;
  `bus_repository_impl` can serve mock data until backend integration.
