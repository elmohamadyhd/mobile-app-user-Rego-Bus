# Bus Live API — Gaps, Resolved Decisions & Open Questions

> **النسخة العربية:** [2026-07-08-bus-live-api-gaps-ar.md](2026-07-08-bus-live-api-gaps-ar.md)

_Date: 2026-07-08 | Status: resolved for this iteration; open items flagged for backend follow-up_

## Purpose

`docs/superpowers/specs/2026-07-08-bus-flow-redesign-design.md` was approved before
the real `/buses/*` response examples existed in `docs/wadeny-apis.md`. Once those
examples landed (see the `Buses` section there, and the raw saved responses in
`api postman collection/Wadeny.postman_collection.....v2.json`), several of that
spec's assumptions didn't match the real payloads. This doc records what's
actually missing from the API, what was decided instead (with the user, in this
session), and what still needs backend confirmation. It amends the redesign
spec — read it alongside that doc, not instead of it.

Feeds directly into the implementation plan: `docs/superpowers/plans/2026-07-08-bus-live-api-wiring.md`.

---

## 1. Data the API does not provide at all

These aren't things to "wire up differently" — they simply don't exist in any
real response, across the full documented collection (46 saved examples) or
the raw Postman file:

| Assumed by the redesign spec | Reality | Resolution |
|---|---|---|
| Per-seat / per-category pricing (`SeatCell.priceEgp`, `seat_type_id` → price) | No seat cell in any `seats_map` example carries a price. The one field that could theoretically hold it — `stations_to[].categories` — is an **empty array in every single example** (checked every saved response in the whole collection, not just Buses). | **Flat fare per stop-pair.** Total = chosen `stations_to[].final_price` × seat count. `category` on a seat cell (e.g. "كرسي درجة أولى") is a **visual-only legend**, not a price driver. |
| Amenities per trip (AC/WiFi/WC icons on results card + detail) | `/buses/trips` response has no amenities field anywhere. | Static placeholder amenity set in the UI, explicitly documented as a stand-in — not derived from any API field. Swap for a real field if/when the backend adds one. |
| Multi-class "range" per trip (e.g. "Economy – VIP") | Each trip result has exactly **one** `category`/`bus.salon` string (e.g. `"VIP"`, `"first8"`, `"FARE-1"`). | Results card shows a single category chip, not a range. |
| Promo code / coupon validation | No coupon/discount/promo endpoint exists anywhere in the **full** API (checked all 60 documented endpoints, not just Buses). `discount`/`wallet_discount` only appear as pre-computed fields on the create-ticket response — there's no way to submit a code. | Promo-code entry field **dropped** from the summary screen this iteration. |
| A "primary"/"default" flag on a boarding or drop-off station | No such flag in any `stations_from`/`stations_to` entry. | Default boarding = first `stations_from` entry. Default dropoff = the `stations_to` entry matching the trip's `price_start_with` (falls back to first entry). Documented assumption, not a confirmed contract. |
| An "is primary" or featured carrier list for filters | N/A — never assumed a list existed, but confirming `/buses/carriers` (paginated, all carriers across the platform) isn't referenced by any screen in the approved spec. | Operator filter is derived client-side from `company_data` on already-loaded trips. `/buses/carriers` and `/buses/stations` stay unused this iteration. |

## 2. Backend behavior that contradicts the original design's assumptions

| Assumed | What the real payload/Postman comments actually show |
|---|---|
| `GET /buses/trips/{id}` returns full trip detail (stations, pricing) for a "trip detail" step. | The only real saved example for this endpoint returns **empty** `cities_from/to` and `stations_from/to` — and critically, the **same trip id (`236510`) returns full station data when it appears inside a `/buses/trips` search-list response**, proving this is a backend bug on the by-id endpoint, not stale/missing data for that trip. A second saved example is a stale 404 HTML page. |
| `seat_type_id` and `seat_id` are independent identifiers (a seat's physical id vs. its class/type id). | Every `create-ticket` sample sends them **equal**, with an explicit Postman comment: `"seat_type_id": "16", // same value like seat_id`. |
| Wallet vs. Card is a real backend choice (`payment_method` varies). | Every `create-ticket` sample hardcodes `"payment_method": "myfatoorah"` with the comment `"fixed only one payment method"`. Per the user: **`myfatoorah` is the Visa/card gateway internally — never show that name in the UI.** There is currently no documented wallet-specific value. |
| Currency is user-selectable per search. | `currency` is a plain query param the client supplies (`EGP` in the Postman defaults; both `EGP` and `SAR` appear across different saved examples). No endpoint suggests a currency needs to be resolved server-side; there's no existing currency infrastructure in the app (`grep -ri currency lib/` found nothing). |
| Boarding-stop choice affects price like dropoff-stop choice does. | Every `stations_from[]` entry across every real example has `price`, `original_price`, `final_price` all `= 0`. Only `stations_to[]` carries a non-zero fare. So the "live segment fare" only needs to recompute on **dropoff** changes, not boarding changes. |

## 3. Resolved decisions (this session) — authoritative for implementation

1. **Seat pricing:** flat fare per stop-pair (`stations_to[selected].final_price × seat count`). Seat category is a visual legend only.
2. **Trip detail:** show the cached object from the `/buses/trips` search response **immediately** (it already has full stations/pricing), then call `GET /buses/trips/{id}` in the **background** and merge any additional non-empty fields from that response onto the cached object — field-by-field, cached data wins wherever the detail response comes back empty (today's bug). This keeps the screen instant and correct today, and automatically benefits from richer/fresher data if the backend ever fixes that endpoint or adds fields the list response lacks. `BusTripDetail` entity is still removed; `BusTripSummary` carries everything and gains a `mergeEnrichment()` helper.
3. **Amenities:** static placeholder set, not a live field.
4. **`seat_type_id`:** always send equal to the seat's own `id` at `create-ticket` time.
5. **Operator filter:** derived client-side from loaded results, no `/buses/carriers` call.
6. **`/buses/stations`:** unused this iteration.
7. **Currency:** hardcoded to `EGP` for now — no picker.
8. **Promo code:** dropped from the summary screen this iteration.
9. **Payment method:** UI keeps both **Visa** and **Wallet** options (never show the literal string "myfatoorah" — that's the internal gateway id for the Visa/card path). Visa is wired to `create-ticket` (`payment_method: "myfatoorah"`); Wallet is shown but disabled/"coming soon" until the backend documents a wallet value.
10. **Default stops:** first `stations_from` entry + the `stations_to` entry matching `price_start_with` (fallback: first entry).
11. **Bus city picker:** replaces the static 4-city `HomeCity` stub in `lib/features/home/presentation/widgets/home_city_picker.dart` with a live search against `GET /buses/locations`, carrying the real numeric id required by `city_from`/`city_to`.

## 4. Open items — need backend/product confirmation, not blocking this iteration

- **Wallet `payment_method` value for bus `create-ticket` is undocumented.** Every sample only shows `"myfatoorah"`. Needed before the Wallet option can actually submit a booking. *Action: ask backend what value (if any) triggers a wallet-funded booking, and whether wallet balance is checked automatically or needs a flag.*
- **`stations_to[].categories` is always empty.** If per-seat/category pricing is ever intended (the field's presence suggests it was designed for that), the backend needs to actually populate it, and the seat-map response needs the seat's `category` label to match the categories key so the client can look up a price. *Action: confirm with backend whether this is planned, or whether pricing is intentionally always flat.*
- **`GET /buses/trips/{id}` returning empty stations for an id that has full data via the search-list endpoint** — this is a genuine backend bug (proven by comparing the two saved examples for the same id `236510`), not a "don't call this directly" contract. The app works around it (cached-first, merge-on-top, ignore empty fields) regardless of whether it's fixed, but it's worth a bug report since deep-link/"refresh a trip" flows would benefit from it actually working.
- **Currency being a free-form client-supplied query param** with no validation visible — confirm `EGP` is an accepted value for all routes/carriers, and whether unsupported currencies degrade gracefully.

---

_Cross-reference: `docs/superpowers/specs/2026-07-08-bus-flow-redesign-design.md` (screen-by-screen design, superseded on the points above), `docs/superpowers/specs/2026-07-08-multi-vehicle-architecture-design.md` (feature-slice architecture), `docs/wadeny-apis.md` (API reference)._
