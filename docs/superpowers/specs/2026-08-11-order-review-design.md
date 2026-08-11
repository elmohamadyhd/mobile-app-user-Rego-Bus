# Order Review (Bus / Flight / Private Car) — Design Spec
_Date: 2026-08-11 | Status: approved_

## Scope

Add rider review (1–5 star rating + optional comment) for **successful /
confirmed** transport orders across all three My Tickets modes: bus, flight,
and private car. Entry points are both the **ticket card** and the **order
detail sheet** (where a detail sheet exists). After a successful submit, hide
the rate CTA and show a compact **Rated ★x** badge — do **not** display the
written comment.

Supersedes the earlier “explicitly dropped” callouts for `review` /
`can_review` in:

- `2026-07-15-bus-order-detail-sheet-design.md`
- `2026-07-28-bus-order-detail-route-timeline-design.md`

Those fields were deferred because they belong to a review-writing feature,
not a static detail row. This spec is that feature.

### In scope

- Map `can_review` + `review` onto `BusOrder`, `FlightOrder`, and `CarOrder`
- Shared presentational UI in `shared/widgets/`
- Per-mode `POST /profile/{buses|flights|private}/orders/:id/review`
- Card + detail entry when eligible
- Compact post-submit “Rated ★x” (no comment shown)
- Localized strings (AR + EN), Phosphor icons, Skyline tokens

### Out of scope

- Editing or deleting a review after submit
- Displaying the submitted comment in the UI
- Support tickets under `/profile/tickets` (different product surface)
- Auto-prompt immediately after payment success
- A new top-level `reviews` feature package

## Approach

**Shared review UI + per-mode API wiring** (chosen over full duplication and
over a central `reviews` feature).

- `shared/widgets` owns mode-agnostic atoms: review sheet, rate CTA, rated
  badge. No Dio, no mode enums, no repository imports.
- Each transport feature owns: DTO mapping, `submitReview` on its repository,
  eligibility helper, and wiring on its card / detail UI.
- Matches multi-vehicle architecture: no `bus` ↔ `flight` ↔ `car` imports.

## API (Wadeny)

Identical contract for all three modes (`docs/wadeny-apis.md`):

| Mode | Method | Path |
|------|--------|------|
| Flight | `POST` | `/profile/flights/orders/:id/review` |
| Bus | `POST` | `/profile/buses/orders/:id/review` |
| Private | `POST` | `/profile/private/orders/:id/review` |

**Body:**

```json
{
  "rating": "1",
  "comment": "optional text"
}
```

- `rating` — required string `"1"`…`"5"`
- `comment` — nullable / optional; omit or send empty when unused

**Auth:** Bearer required.  
**Known errors:** `400` “Order must be completed to review”; `404` order not
found (bus/private samples).

List/show order payloads already include `can_review` (bool) and `review`
(null when none). Bus samples document this clearly. Flight/private samples
in the doc may omit the keys — mappers **default** `canReview` to `false` and
`reviewRating` to `null` when absent.

### `review` payload shape (defensive mapping)

Saved responses only show `"review": null`. When non-null, the mapper must
accept common variants without crashing:

| Shape | Extracted rating |
|-------|------------------|
| `int` / `num` | that value clamped/validated to 1–5 |
| `String` numeric | parsed int 1–5 |
| `Map` with `rating` | parse `rating` as above |
| Anything else / out of range | treat as no review (`null`) |

Comment inside a review object is **not** mapped into the entity for display.

## Data model

Add to each of `BusOrder`, `FlightOrder`, `CarOrder`:

| Field | Type | Source | Notes |
|-------|------|--------|-------|
| `canReview` | `bool` | `can_review` | default `false` |
| `reviewRating` | `int?` | `review` | `null` if none / unparsable |

No separate Freezed “Review” entity unless a mode already uses Freezed and
needs a nested type — prefer the two flat fields above for YAGNI.

### Eligibility

Show the rate CTA only when **all** are true:

1. Order is success / confirmed (mode-specific — see below)
2. `canReview == true`
3. `reviewRating == null` (not already rated)

Show the rated badge when `reviewRating != null` (1–5).

Otherwise show neither.

**Success / confirmed per mode:**

| Mode | Rule |
|------|------|
| Bus | `statusKind == BusOrderStatusKind.confirmed` (mapper already treats `success` / paid codes as confirmed) |
| Car | `statusKind == CarOrderStatusKind.confirmed` |
| Flight | `isFlightOrderPaid(order)` from existing `flight_order_status.dart` |

Helper name suggestion (per feature, not shared): e.g.
`bool busOrderCanRate(BusOrder o)` — keeps mode status knowledge inside the
feature.

## UI / UX

### Shared widgets (`lib/shared/widgets/`)

| Widget | Role |
|--------|------|
| `OrderReviewSheet` | Modal bottom sheet: 5 tappable stars (required), optional comment field, submit button disabled until a star is selected; calls `Future<void> Function(int rating, String? comment)` |
| `OrderRateTripButton` | Secondary / outline CTA labeled via l10n |
| `OrderRatedBadge` | Compact “Rated ★x” (or localized equivalent); no comment |

Skyline: `AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`. Icons:
`PhosphorIconsLight.*` only. RTL: `EdgeInsetsDirectional`, mirrored carets if
any. Sheet body scrollable; respect keyboard insets.

### Entry points

| Surface | Behavior |
|---------|----------|
| Bus `BusOrderCard` | Rate CTA or rated badge in action stub area |
| Bus `BusOrderDetailSheet` | Same, below primary actions / near status |
| Car `CarOrderCard` | Same |
| Car `CarOrderDetailSheet` | Same |
| Flight My Tickets card | Same |
| Flight detail | Wire if a detail sheet/screen already exists for profile orders; otherwise card-only is acceptable for v1 (do not invent a new flight detail sheet solely for review) |

Tapping Rate opens `OrderReviewSheet`. Card `onTap` (open detail) must not
fire when tapping the CTA (stop propagation / separate button).

### After successful submit

1. Close the sheet
2. Refresh the mode’s orders list (and detail provider if open) so
   `canReview` / `reviewRating` come from the server
3. If the list refresh is slow or the show endpoint still returns
   `review: null`, apply a local patch on the in-memory order
   (`canReview = false`, `reviewRating = n`) so the badge appears immediately
4. Replace CTA with `OrderRatedBadge` on card and detail once those fields update

### Errors

| Case | UI |
|------|----|
| Validation (no star) | Submit stays disabled |
| `400` / `404` / Dio failure | Localized snackbar; sheet remains open |
| Unknown | Generic error snackbar |

Do not swallow errors. Do not navigate away on failure.

## Repository / presentation

Per mode:

```dart
Future<void> submitReview({
  required String orderId, // or int for car — match existing id type
  required int rating,
  String? comment,
});
```

- API client posts JSON with string `rating` and optional `comment`
- Presentation notifier or inline async on the sheet caller handles loading
  flag + snackbar
- On success: invalidate / refresh list + detail providers for that order

No cross-feature review service.

## Localization

Add keys to **both** `app_en.arb` (with `@key` descriptions) and `app_ar.arb`,
then `flutter gen-l10n`. Suggested keys (exact names may be adjusted for
consistency with existing `ticket*` / `order*` prefixes):

- Rate trip CTA
- Review sheet title
- Comment field hint (optional)
- Submit review
- Rated label with rating placeholder (ICU)
- Review submit error (generic)
- Review not allowed / order not completed (optional specific copy)

No hardcoded user-facing English in widgets.

## Testing

TDD for business logic; widget tests for shared sheet/badge.

1. **Mapper** — `can_review` / `review` variants → entity fields; missing keys → defaults
2. **Eligibility** — confirmed+canReview+no rating → rate; has rating → badge; pending → neither; confirmed but `canReview` false → neither
3. **Repository** — `submitReview` sends expected path + body
4. **`OrderReviewSheet`** — submit disabled without rating; invokes callback with rating + trimmed comment
5. **`OrderRatedBadge`** — shows the rating value

Update fakes/fixtures used by bus/car/flight order tests to include the new
fields.

## File layout (expected)

```
lib/shared/widgets/order_review_sheet.dart
lib/shared/widgets/order_rate_trip_button.dart
lib/shared/widgets/order_rated_badge.dart

lib/features/bus/domain/entities/bus_order.dart          # +fields
lib/features/bus/data/bus_dto_mapper.dart                # map review
lib/features/bus/data/bus_api.dart / repository*         # submitReview
lib/features/bus/presentation/widgets/bus_order_card.dart
lib/features/bus/presentation/widgets/bus_order_detail_sheet.dart

lib/features/car/domain/entities/car_order.dart
lib/features/car/data/…                                 # map + submit
lib/features/car/presentation/widgets/car_order_card.dart
lib/features/car/presentation/widgets/car_order_detail_sheet.dart

lib/features/flight/domain/entities/flight_order.dart
lib/features/flight/data/…                              # map + submit
lib/features/flight/presentation/widgets/flight_orders_section.dart
  (+ detail surface if already present)

lib/l10n/app_en.arb
lib/l10n/app_ar.arb

test/shared/widgets/…
test/features/bus/…
test/features/car/…
test/features/flight/…
```

Exact API client file names follow each feature’s existing pattern
(`bus_api.dart`, car/flight equivalents).

## Decisions log

| Decision | Choice |
|----------|--------|
| Entry points | Card **and** detail (C) |
| After submit | Compact Rated ★x; no comment shown (A) |
| Eligibility | Confirmed/success **and** `can_review` (C) |
| Comment | Optional (A) |
| Architecture | Shared UI + per-mode wiring (1) |
