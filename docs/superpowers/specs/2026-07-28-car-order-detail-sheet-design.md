# Private Car Order Detail Sheet — Design Spec
_Date: 2026-07-28 | Status: approved_

## Scope

Add a My Tickets detail bottom sheet for private-car orders
(`GET /profile/private/orders/:id`), mirroring the bus order detail sheet:
seed from the list card, refresh by id, side-by-side route with Google Maps
on tap, plus company/vehicle/payment/reference sections.

## Out of scope

- Redesigning `CarOrderCard` layout (only add body `onTap`)
- Changing pay / cancel / voucher flows
- Using top-level order `from` pin as route labels (route uses
  `trip.from_location` / `to_location`)
- Invoice download CTA inside the sheet

## Approach

Same as bus (`2026-07-15-bus-order-detail-sheet-design.md`):

```dart
final order = ref.watch(carOrderDetailProvider(seed.id)).value ?? seed;
```

`carOrderDetailProvider` = `FutureProvider.autoDispose.family` calling
`carRepository.getOrder(id)`. Failures keep the seed; no error UI on the sheet.

## Sheet sections (top → bottom)

1. **Header** — company name (+ logo when URL present) + `CarOrderStatusBadge`
2. **Route** — side-by-side `fromLocation` ↔ `toLocation` (name only);
   tap opens Maps confirm; no times (API has `departure_date` only)
3. **Trip info** — departure date; return date when present / rounded
4. **Vehicle** — name, model, year, category, seats, bags, gear
5. **Price** — `currency` + `price` (emphasized); optional round-trip note
   when `order.rounded`
6. **Payment** — gateway, transaction status, invoice id (when present)
7. **Reference** — order id; trip id when trip present

Reuse shared l10n where it already fits (`orderDetailTitle`,
`orderDetailRouteSection`, payment/reference keys). Add car-specific keys
only for vehicle/trip rows that have no existing string.

## Data model

`CarOrder` already carries most fields via `trip`. Add:

| Field | Source |
|---|---|
| `paymentGateway` | `transaction.gateway` |
| `paymentInvoiceId` | `transaction.meta_data.invoice_id` (string) |

Mapper updates `orderFromJson` accordingly. Missing `to` at top level stays
`0,0` coords (card/sheet route still use trip locations).

## Maps (cross-feature)

`core/utils/google_maps_url.dart` currently imports `BusStop` (core →
feature leak). Lift a tiny `MapLocation` into `core/utils/map_location.dart`
(`name`, `latitude?`, `longitude?`, `cityName`). Point URL builders at
`MapLocation`.

Move confirm-and-open into `shared/widgets/open_location_in_google_maps.dart`
taking `MapLocation` + existing trip-detail Maps l10n. Bus call sites adapt
`BusStop` → `MapLocation`; car uses `CarNamedLocation` → `MapLocation`.

## Card wiring

`CarOrderCard` gains optional `onTap`. Card body InkWell/Material opens the
sheet; pay / voucher / cancel buttons do not bubble `onTap`.
`CarOrdersSection` passes the sheet opener.

## Testing

- Mapper: show fixture asserts gateway + invoice id; locations unchanged
- Sheet: paints company, Cairo/Alexandria, vehicle, price; tap Cairo opens
  Maps confirm dialog
- Google Maps URL tests updated to `MapLocation`
- Card: body tap fires `onTap`; pay button does not

## Self-review

- No bus←→car imports; Maps shared via core/shared only
- No invoice/status remapping scope creep
- Matches approved full-sheet option A
