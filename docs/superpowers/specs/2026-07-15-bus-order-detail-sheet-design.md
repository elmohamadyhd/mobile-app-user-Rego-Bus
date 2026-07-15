# Bus Order Detail Sheet — Design Spec
_Date: 2026-07-15 | Status: approved_

## Scope

Adds order-detail viewing to the My Tickets tab, sourced from
`GET /profile/buses/orders/:id`. Supersedes the "out of scope" call in
`2026-07-14-tickets-tab-design.md` (which deferred a detail view because "the
list item carries everything the card and its actions need") — that was true
for the card's existing fields, but the API returns fare-breakdown and
per-seat pricing data that `BusOrder` never mapped and the card never shows.

Tapping a `BusOrderCard` opens a bottom sheet with everything the order
response carries that the card doesn't already surface: per-seat prices, the
full fare breakdown (subtotal → discount → wallet discount → fees → total),
payment gateway metadata, and order/trip identifiers.

## Key finding: Show and List return identical shapes

The saved 200 response for `/profile/buses/orders/:id` in `docs/wadeny-apis.md`
is field-for-field identical to the matching element inside
`/profile/buses/orders`'s `data[]` array — same keys, same values, for the
same order id (1475). The `:id` endpoint adds no new fields; its only value
is **freshness** (status can flip pending → confirmed after payment,
independent of when the list was last fetched) and being independently
fetchable (id-addressable, future deep-linking).

This means one mapper function serves both endpoints, and the sheet can
render instantly from data already in memory rather than blocking on a
network call.

## Approach: seed from list, refresh by id, no loading state

The sheet opens already painted with the `BusOrder` the list already fetched
(the tapped card's data), while `GET /profile/buses/orders/:id` runs
underneath and silently replaces it if it returns something different. If
the call fails, the seeded data simply stays — no error UI, no retry button;
this is a freshness check, not the sheet's only data source.

```dart
final busOrderDetailProvider =
    FutureProvider.autoDispose.family<BusOrder, String>(
  (ref, orderId) => ref.read(busRepositoryProvider).orderById(orderId),
);

// in the sheet:
final order = ref.watch(busOrderDetailProvider(seed.orderId)).value ?? seed;
```

Rejected: a skeleton-then-fill approach (fetch-on-open) — shows a loading
state for data the app already holds, on every single open. Rejected: no
network call at all — never refreshes status, and doesn't use the endpoint
this feature is meant to wire up.

## Data model changes

### `BusOrder` — new fields

Currently 15 flat fields (`orderId` … `invoiceUrl`); several of the source
JSON's fields go unmapped. Add:

| Field | Source JSON | Notes |
|---|---|---|
| `ticketLines` | `tickets[]` | `List<BusTicketLine>` (reuses the existing entity — see below). **Replaces** the current `seats: List<String>` field, which is mapped but rendered nowhere (confirmed via grep — zero UI usages). |
| `fare` | `original_tickets_totals`, `discount`, `wallet_discount`, `tickets_totals_after_discount`, `payment_fees`, `total`, `currency` | New nested `BusOrderFare` value type — 6 related money fields grouped as one object rather than 6 more flat fields on an already-large entity. |
| `paymentGateway` | `payment_data.gateway` | e.g. `"Myfatoorah"` |
| `paymentStatusText` | `payment_data.status` | separate from the order-level `statusText`/`statusKind` |
| `paymentInvoiceId` | `payment_data.invoice_id` | stored as `String` (display-only, like other numeric ids in this entity) |
| `tripId` | `trip_id` | |
| `gatewayOrderId` | `gateway_order_id` | |
| `tripType` | `trip_type` | e.g. `"Buses"` |

`total` (the existing flat field, preformatted like `"EGP 219.35"`) stays as
is for the card; `fare.total` on the nested object holds the same value,
kept inside the fare-breakdown group rather than reading two different
fields for the same number.

**Explicitly dropped**, despite being mappable:
- `review` / `can_review` — describe a review-writing feature, not order
  detail; "Can review: false" is not information worth a row.
- `parent_order_id` — `null` in every sample, no rider-facing meaning.
- `date` — duplicates `date_time`, which `dateTimeLabel` already uses.

### `BusOrderFare` (new)

```dart
@freezed
abstract class BusOrderFare with _$BusOrderFare {
  const factory BusOrderFare({
    required String originalTicketsTotal,
    required String discount,
    required String walletDiscount,
    required String ticketsTotalAfterDiscount,
    required String paymentFees,
    required String total,
    required String currency,
  }) = _BusOrderFare;
}
```

All money fields stay preformatted strings (`"EGP 205.00"`), matching every
other money field in this codebase (`BusOrder.total`, `BusTicketLine.price`,
etc.) — no parsing into numeric types, no new currency-formatting logic.

### `BusTicketLine` — reused, not duplicated

`features/bus/domain/entities/bus_ticket.dart` already defines
`BusTicketLine { id, seatNumber, price }`, which matches `tickets[]` exactly.
`BusDtoMapper.ticketFromEnvelope` and the old `orderFromJson` each currently
loop over `tickets[]` inline with near-identical code; extract one
`ticketLinesFromJson(dynamic raw) → List<BusTicketLine>` helper and use it in
both places.

## Mapper changes (`bus_dto_mapper.dart`)

- `orderFromJson` (existing): updated to populate the new `BusOrder` fields
  above, using the extracted `ticketLinesFromJson` helper. Tolerates missing
  `payment_data`/nested maps the same way existing code does (null-safe
  reads, empty-string → null normalization for logo/URLs).
- `orderFromEnvelope(dynamic body) → BusOrder` (new): unwraps the `{status,
  message, errors, data}` envelope for the **Show** endpoint (`data` is a
  `Map`, not the `List` that `ordersFromEnvelope` expects) and delegates to
  the same `orderFromJson`. This is the direct payoff of the identical
  shapes — no separate detail-mapping code path.
- 404 handling: `ensureSuccess` throws `ApiException.fromEnvelope` when the
  envelope's inner `status` isn't 200, but only reaches that check if Dio
  doesn't already throw on the HTTP-level 404 first. Verify
  `core/network/dio_client.dart`'s `validateStatus` during implementation;
  either way `orderById` should surface a normal `ApiException` (matching
  how `tripById`/other by-id calls behave), which the sheet's provider
  naturally swallows into `AsyncValue.error` (seed stays visible, per the
  approach above).

## API / repository / provider layer

**`BusApi`** — add:
```dart
Future<dynamic> orderById(String orderId) async {
  final res = await _dio.get('/profile/buses/orders/$orderId');
  return res.data;
}
```

**`BusRepository`** (+ impl) — add:
```dart
Future<BusOrder> orderById(String orderId);
```
implemented as `BusDtoMapper.orderFromEnvelope(await _api.orderById(orderId))`.

**Provider** — `busOrderDetailProvider`, a
`FutureProvider.autoDispose.family<BusOrder, String>` in
`bus_orders_provider.dart` (alongside `busOrdersProvider`), as shown above.
`autoDispose` because it's sheet-scoped, unlike the tab-lifetime orders list.

## Presentation — the sheet

New file: `features/bus/presentation/widgets/bus_order_detail_sheet.dart`.

- Opened via `showModalBottomSheet` from `BusOrderCard`'s `onTap` (the whole
  card becomes tappable; the existing pay/e-ticket/cancel buttons keep their
  own tap targets via their `Material`/`InkWell` — tapping a button does not
  also open the sheet).
- `showModalBottomSheet` + `ConstrainedBox(maxHeight: 0.85 * screen height)` +
  `SingleChildScrollView`, rounded-top `AppRadius.sheet` — this is the one
  sheet pattern already used at every `showModalBottomSheet` call site in
  this codebase (`trip_filter_sheet.dart`, `bus_city_picker.dart`,
  `guest_gate_sheet.dart`, others), so this follows it rather than
  introducing `DraggableScrollableSheet` as a one-off.
- Sections, top to bottom:
  1. **Header** — `OperatorMark` + operator name + `category` chip +
     `OrderStatusBadge` (reused from the card).
  2. **Route & date** — pickup/dropoff stop labels (when present — both are
     `null` in every sample, so this section may not render; same
     `_hasLabel` guard the card already uses) + `dateTimeLabel`.
  3. **Seats** — one row per `BusTicketLine`: seat number + its price.
  4. **Fare breakdown** — `originalTicketsTotal` → `discount` →
     `walletDiscount` → `ticketsTotalAfterDiscount` → `paymentFees` →
     `total`, total row emphasized (bold/larger, matching how the card
     emphasizes its total row today). Zero-value discount rows
     (`"EGP 0.00"`) are hidden rather than shown as noise — a "Discount:
     EGP 0.00" row tells the rider nothing. Since these fields are
     preformatted strings, zero-detection strips everything except digits
     and `.` and checks for `0`/`0.00`/empty; if that parse is ambiguous,
     default to **showing** the row rather than risk hiding a real
     discount.
  5. **Payment** — gateway (`paymentGateway`), payment status
     (`paymentStatusText`), invoice id (`paymentInvoiceId`).
  6. **Reference details** — booking number (already on the card, repeated
     here so this is a genuinely complete "everything" section), `tripId`,
     `gatewayOrderId`, `tripType`.
- No action buttons in the sheet — pay/download/cancel stay owned by the
  card, avoiding duplicate logic for the same three actions in two places.
- Row rendering reuses `BusOrderCard`'s private `_InfoRow` — promoted to a
  shared widget (`features/bus/presentation/widgets/order_info_row.dart`)
  since it's now used from two files.

## Testing

- **Mapper**: `orderFromEnvelope` against the documented Show 200 sample
  (asserting the new fields, especially `ticketLines` prices and the fare
  breakdown); a 404-envelope case; `orderFromJson` continues to pass with
  `ticketLines` replacing the deleted `seats` assertions.
- **Fixtures**: `test/features/bus/data/bus_fixtures.dart` and
  `fake_bus_repository.dart` gain `orderById`; any fixture/test referencing
  `BusOrder.seats` (list/card/section tests) moves to `.ticketLines`.
- **Sheet**: three provider-seed behaviours — renders seed immediately with
  no spinner; updates in place when the family resolves to different data;
  keeps showing seed when the family errors. Zero-discount rows hidden;
  non-zero discount rows shown.

## Files

**New:**
`features/bus/presentation/widgets/bus_order_detail_sheet.dart`,
`features/bus/presentation/widgets/order_info_row.dart` (extracted from
`bus_order_card.dart`).

**Modified:**
`features/bus/domain/entities/bus_order.dart` (+`.freezed.dart`) — new
fields, new `BusOrderFare` type;
`features/bus/data/bus_api.dart` — `orderById`;
`features/bus/data/bus_dto_mapper.dart` — `orderFromEnvelope`,
`ticketLinesFromJson` extraction, updated `orderFromJson`;
`features/bus/data/bus_repository_impl.dart` — `orderById`;
`features/bus/domain/repositories/bus_repository.dart` — `orderById`;
`features/bus/presentation/providers/bus_orders_provider.dart` —
`busOrderDetailProvider`;
`features/bus/presentation/widgets/bus_order_card.dart` — tappable card,
`_InfoRow` → shared `OrderInfoRow`;
`test/features/bus/data/bus_fixtures.dart`,
`test/features/bus/fake_bus_repository.dart`,
existing bus order/card/section tests referencing `.seats`.

## Explicitly out of scope

- The dead `BusApi.orderStatusPath` (`/buses/orders/:id`, undocumented) used
  by payment verification is a separate, pre-existing endpoint with its own
  ⚠️ caveat comment. `/profile/buses/orders/:id` (this spec) returns the same
  `status_code`/`is_confirmed` and could plausibly replace it, but that
  changes payment-verification behavior and deserves its own spec, not a
  ride-along here.
- No QR/barcode rendering — the API has no barcode field anywhere; the
  existing e-ticket PDF (`invoiceUrl`) remains the only scannable artifact.
- Flight/private-car detail views — bus-only, per the multi-vehicle
  architecture rule; each mode adds its own when it exists.

---

_Cross-reference: `2026-07-14-tickets-tab-design.md` (supersedes its
"out of scope" call on order detail), `docs/wadeny-apis.md` (API reference,
Buses > Orders > Show)._
