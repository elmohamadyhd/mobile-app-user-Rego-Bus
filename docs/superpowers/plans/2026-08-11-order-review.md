# Order Review (Bus / Flight / Private Car) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let riders rate successful bus, flight, and private-car orders (1–5 stars + optional comment) from My Tickets cards and order detail sheets via Wadeny `POST …/orders/:id/review`.

**Architecture:** Shared presentational widgets (`OrderReviewSheet`, `OrderRateTripButton`, `OrderRatedBadge`) plus a shared `parseOrderReviewRating` helper. Each transport feature maps `can_review` / `review`, implements `submitReview` on its repository, and wires CTAs when confirmed/success **and** `canReview` **and** no existing rating.

**Tech Stack:** Flutter, Riverpod, Dio, Freezed (bus/flight entities), Skyline tokens, Phosphor Light, ARB/`flutter gen-l10n`, `flutter_test`.

**Spec:** [`docs/superpowers/specs/2026-08-11-order-review-design.md`](../specs/2026-08-11-order-review-design.md)

## Global Constraints

- Shared UI only in `lib/shared/widgets/` + `lib/shared/utils/` — no Dio, no mode enums
- No cross-imports between `bus` / `flight` / `car`
- Eligibility: confirmed/success **and** `canReview == true` **and** `reviewRating == null`
- After submit: hide CTA, show compact Rated ★x — **never** show the comment
- Comment optional; rating required (submit disabled until star chosen)
- API body: `{ "rating": "<1-5>", "comment": "…" }` — omit `comment` when empty/null
- Package imports `package:safaria/...`; Phosphor Light; Skyline tokens; directional insets
- All user-facing strings via `AppLocalizations` (both ARB files)
- After Freezed field changes: `dart run build_runner build --delete-conflicting-outputs`
- One task → one commit; run relevant tests before each commit

## File map

| File | Role |
|------|------|
| `lib/shared/utils/order_review_mapping.dart` | `parseOrderReviewRating(dynamic)` |
| `lib/shared/widgets/order_rated_badge.dart` | Compact Rated ★x |
| `lib/shared/widgets/order_rate_trip_button.dart` | Rate CTA |
| `lib/shared/widgets/order_review_sheet.dart` | Sheet + `showOrderReviewSheet` |
| `lib/l10n/app_en.arb` / `app_ar.arb` | Strings |
| `lib/features/bus/domain/entities/bus_order.dart` | `canReview`, `reviewRating` |
| `lib/features/bus/domain/utils/bus_order_review.dart` | `busOrderCanRate` |
| `lib/features/bus/data/bus_dto_mapper.dart` | Map review fields |
| `lib/features/bus/data/bus_api.dart` | `submitReview` |
| `lib/features/bus/domain/repositories/bus_repository.dart` | Interface |
| `lib/features/bus/data/bus_repository_impl.dart` | Impl |
| `lib/features/bus/presentation/widgets/bus_order_card.dart` | CTA / badge |
| `lib/features/bus/presentation/widgets/bus_order_detail_sheet.dart` | CTA / badge |
| `lib/features/bus/presentation/widgets/bus_orders_section.dart` | Wire `onRate` |
| Same pattern under `car/` and `flight/` | Map + submit + UI |
| Matching `test/...` files | TDD |

---

### Task 1: Shared rating parser + l10n

**Files:**
- Create: `lib/shared/utils/order_review_mapping.dart`
- Create: `test/shared/utils/order_review_mapping_test.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ar.arb`

**Interfaces:**
- Produces: `int? parseOrderReviewRating(dynamic review)`

- [ ] **Step 1: Write failing parser tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/shared/utils/order_review_mapping.dart';

void main() {
  group('parseOrderReviewRating', () {
    test('null → null', () {
      expect(parseOrderReviewRating(null), isNull);
    });

    test('int in range', () {
      expect(parseOrderReviewRating(4), 4);
    });

    test('string numeric', () {
      expect(parseOrderReviewRating('5'), 5);
    });

    test('map with rating', () {
      expect(parseOrderReviewRating({'rating': '3', 'comment': 'ok'}), 3);
    });

    test('out of range → null', () {
      expect(parseOrderReviewRating(0), isNull);
      expect(parseOrderReviewRating(6), isNull);
    });

    test('garbage → null', () {
      expect(parseOrderReviewRating('abc'), isNull);
      expect(parseOrderReviewRating(<String, dynamic>{}), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test — expect FAIL (library missing)**

```bash
flutter test test/shared/utils/order_review_mapping_test.dart
```

- [ ] **Step 3: Implement parser**

```dart
/// Extracts a 1–5 rating from Wadeny `review` field variants.
int? parseOrderReviewRating(dynamic review) {
  if (review == null) return null;
  if (review is num) return _inRange(review.toInt());
  if (review is String) {
    final parsed = int.tryParse(review.trim());
    return parsed == null ? null : _inRange(parsed);
  }
  if (review is Map) {
    return parseOrderReviewRating(review['rating']);
  }
  return null;
}

int? _inRange(int value) => (value >= 1 && value <= 5) ? value : null;
```

- [ ] **Step 4: Re-run parser tests — expect PASS**

- [ ] **Step 5: Add ARB keys**

In `app_en.arb` (near other order/ticket keys), add:

```json
  "orderRateTripCta": "Rate trip",
  "@orderRateTripCta": {
    "description": "CTA on a successful ticket card/detail to open the review sheet."
  },
  "orderReviewSheetTitle": "Rate your trip",
  "@orderReviewSheetTitle": {
    "description": "Title of the order review bottom sheet."
  },
  "orderReviewCommentHint": "Comment (optional)",
  "@orderReviewCommentHint": {
    "description": "Optional comment field hint on the review sheet."
  },
  "orderReviewSubmit": "Submit review",
  "@orderReviewSubmit": {
    "description": "Primary submit button on the review sheet."
  },
  "orderRatedLabel": "Rated ★{rating}",
  "@orderRatedLabel": {
    "description": "Compact badge after the rider has rated an order.",
    "placeholders": {
      "rating": { "type": "int" }
    }
  },
  "orderReviewSubmitError": "Could not submit your review. Please try again.",
  "@orderReviewSubmitError": {
    "description": "Generic snackbar when review POST fails."
  },
  "orderReviewNotAllowedError": "This order cannot be reviewed yet.",
  "@orderReviewNotAllowedError": {
    "description": "Snackbar when API returns order-must-be-completed / not allowed."
  }
```

Arabic (`app_ar.arb`) — same keys, no `@` metadata:

```json
  "orderRateTripCta": "قيّم الرحلة",
  "orderReviewSheetTitle": "قيّم رحلتك",
  "orderReviewCommentHint": "تعليق (اختياري)",
  "orderReviewSubmit": "إرسال التقييم",
  "orderRatedLabel": "التقييم ★{rating}",
  "orderReviewSubmitError": "تعذر إرسال التقييم. حاول مرة أخرى.",
  "orderReviewNotAllowedError": "لا يمكن تقييم هذا الطلب حالياً."
```

- [ ] **Step 6: Generate l10n**

```bash
flutter gen-l10n
```

- [ ] **Step 7: Commit**

```bash
git add lib/shared/utils/order_review_mapping.dart \
  test/shared/utils/order_review_mapping_test.dart \
  lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "$(cat <<'EOF'
feat: add order review rating parser and l10n keys

EOF
)"
```

---

### Task 2: Shared review widgets (badge, CTA, sheet)

**Files:**
- Create: `lib/shared/widgets/order_rated_badge.dart`
- Create: `lib/shared/widgets/order_rate_trip_button.dart`
- Create: `lib/shared/widgets/order_review_sheet.dart`
- Create: `test/shared/widgets/order_rated_badge_test.dart`
- Create: `test/shared/widgets/order_review_sheet_test.dart`

**Interfaces:**
- Consumes: l10n keys from Task 1
- Produces:
  - `OrderRatedBadge({required int rating})`
  - `OrderRateTripButton({required VoidCallback onPressed})`
  - `Future<void> showOrderReviewSheet(BuildContext context, {required Future<void> Function(int rating, String? comment) onSubmit})`

- [ ] **Step 1: Failing badge test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/order_rated_badge.dart';

void main() {
  testWidgets('shows rated label with rating', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: OrderRatedBadge(rating: 4)),
      ),
    );
    expect(find.textContaining('4'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

```bash
flutter test test/shared/widgets/order_rated_badge_test.dart
```

- [ ] **Step 3: Implement `OrderRatedBadge`**

```dart
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/l10n/app_localizations.dart';

class OrderRatedBadge extends StatelessWidget {
  const OrderRatedBadge({super.key, required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            PhosphorIconsLight.star,
            size: 16,
            color: AppColors.secondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            l10n.orderRatedLabel(rating),
            style: AppTypography.caption.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Implement `OrderRateTripButton`**

Use compact ghost `PrimaryButton` (or outlined style matching card stubs):

```dart
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

class OrderRateTripButton extends StatelessWidget {
  const OrderRateTripButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PrimaryButton(
      label: l10n.orderRateTripCta,
      icon: PhosphorIconsLight.star,
      variant: PrimaryButtonVariant.ghost,
      compact: true,
      onPressed: onPressed,
    );
  }
}
```

- [ ] **Step 5: Failing sheet tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/order_review_sheet.dart';

void main() {
  testWidgets('submit disabled until a star is chosen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showOrderReviewSheet(
                context,
                onSubmit: (_, __) async {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final submit = find.text('Submit review');
    expect(submit, findsOneWidget);
    // PrimaryButton disabled → Opacity 0.6; tapping must not call onSubmit.
  });

  testWidgets('submit calls onSubmit with rating and trimmed comment',
      (tester) async {
    int? gotRating;
    String? gotComment;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showOrderReviewSheet(
                context,
                onSubmit: (rating, comment) async {
                  gotRating = rating;
                  gotComment = comment;
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('order-review-star-5')));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '  great  ');
    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();

    expect(gotRating, 5);
    expect(gotComment, 'great');
  });
}
```

- [ ] **Step 6: Implement `order_review_sheet.dart`**

Requirements:
- `showModalBottomSheet` with `AppRadius.sheet`, `isScrollControlled: true`, `useRootNavigator: true`
- SafeArea + SingleChildScrollView; pad for `viewInsets.bottom`
- 5 star `IconButton`s with keys `order-review-star-1`…`5`; filled star when selected (`PhosphorIconsFill.star` only if package exports Fill — otherwise Light star + amber color for selected)
- Optional `TextField` for comment
- Submit via `PrimaryButton`; `loading` while `onSubmit` runs; on success `Navigator.pop`; on error show `SnackBar` with `orderReviewSubmitError` (caller may throw `ApiException` — catch and show message; if message contains "completed" use `orderReviewNotAllowedError`)
- Max content width `AppBreakpoints.maxContentWidth` when wide

Use `PhosphorIconsLight.star` for unselected and selected with `AppColors.secondary` tint if Fill is unavailable in this package — check `phosphoricons_flutter` exports; prefer Light for both to match project rules unless Fill is already used elsewhere for selected states.

- [ ] **Step 7: Run shared widget tests — expect PASS**

```bash
flutter test test/shared/widgets/order_rated_badge_test.dart \
  test/shared/widgets/order_review_sheet_test.dart
```

- [ ] **Step 8: Commit**

```bash
git add lib/shared/widgets/order_rated_badge.dart \
  lib/shared/widgets/order_rate_trip_button.dart \
  lib/shared/widgets/order_review_sheet.dart \
  test/shared/widgets/order_rated_badge_test.dart \
  test/shared/widgets/order_review_sheet_test.dart
git commit -m "$(cat <<'EOF'
feat: add shared order review sheet, rate CTA, and rated badge

EOF
)"
```

---

### Task 3: Bus — entity, mapper, eligibility, API, repository

**Files:**
- Modify: `lib/features/bus/domain/entities/bus_order.dart`
- Create: `lib/features/bus/domain/utils/bus_order_review.dart`
- Modify: `lib/features/bus/data/bus_dto_mapper.dart`
- Modify: `lib/features/bus/data/bus_api.dart`
- Modify: `lib/features/bus/domain/repositories/bus_repository.dart`
- Modify: `lib/features/bus/data/bus_repository_impl.dart`
- Modify: `test/features/bus/fake_bus_repository.dart` (+ all `BusOrder(` call sites)
- Create or extend: `test/features/bus/data/bus_order_mapper_review_test.dart`
- Create: `test/features/bus/domain/bus_order_review_test.dart`
- Extend bus repository tests / add `test/features/bus/data/bus_submit_review_test.dart`

**Interfaces:**
- Consumes: `parseOrderReviewRating`
- Produces:
  - `BusOrder.canReview` (`bool`, default `false`), `BusOrder.reviewRating` (`int?`)
  - `bool busOrderCanRate(BusOrder order)`
  - `Future<dynamic> BusApi.submitReview({required String orderId, required int rating, String? comment})`
  - `Future<void> BusRepository.submitReview({required String orderId, required int rating, String? comment})`

- [ ] **Step 1: Failing eligibility + mapper tests**

```dart
// test/features/bus/domain/bus_order_review_test.dart
test('eligible when confirmed, canReview, no rating', () {
  expect(
    busOrderCanRate(const BusOrder(
      // …minimal required fields…
      statusKind: BusOrderStatusKind.confirmed,
      canReview: true,
      reviewRating: null,
    )),
    isTrue,
  );
});

test('not eligible when canReview false', () { … });
test('not eligible when already rated', () { … });
test('not eligible when pending', () { … });
```

```dart
// mapper
test('maps can_review and review rating', () {
  final order = BusDtoMapper.orderFromJson({
    …minimal bus order json…,
    'can_review': true,
    'review': {'rating': '4'},
    'status_code': 'success',
    'is_confirmed': 1,
  });
  expect(order.canReview, isTrue);
  expect(order.reviewRating, 4);
});
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Extend `BusOrder` Freezed fields**

```dart
@Default(false) bool canReview,
int? reviewRating,
```

- [ ] **Step 4: Codegen**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 5: Mapper + eligibility**

In `orderFromJson`:

```dart
canReview: json['can_review'] == true,
reviewRating: parseOrderReviewRating(json['review']),
```

```dart
// bus_order_review.dart
bool busOrderCanRate(BusOrder order) =>
    order.statusKind == BusOrderStatusKind.confirmed &&
    order.canReview &&
    order.reviewRating == null;
```

- [ ] **Step 6: API + repository `submitReview`**

```dart
// BusApi
Future<dynamic> submitReview({
  required String orderId,
  required int rating,
  String? comment,
}) async {
  final body = <String, dynamic>{'rating': '$rating'};
  final trimmed = comment?.trim();
  if (trimmed != null && trimmed.isNotEmpty) {
    body['comment'] = trimmed;
  }
  final res = await _dio.post(
    '/profile/buses/orders/$orderId/review',
    data: body,
  );
  return res.data;
}
```

```dart
// BusRepositoryImpl
@override
Future<void> submitReview({
  required String orderId,
  required int rating,
  String? comment,
}) {
  return _guard(() async {
    final body = await _api.submitReview(
      orderId: orderId,
      rating: rating,
      comment: comment,
    );
    BusDtoMapper.ensureSuccess(body as Map<String, dynamic>);
  });
}
```

- [ ] **Step 7: Update fakes/fixtures** — add `canReview: false` (or omit if `@Default`) and leave `reviewRating` null on all `BusOrder(` constructors; implement `submitReview` on `FakeBusRepository` (track calls / throw on demand).

- [ ] **Step 8: Repo test — posts expected body** (fake API capturing args)

- [ ] **Step 9: Run bus review-related tests — PASS**

- [ ] **Step 10: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(bus): map can_review and submit order reviews

EOF
)"
```

---

### Task 4: Bus — card + detail UI wiring

**Files:**
- Modify: `lib/features/bus/presentation/widgets/bus_order_card.dart`
- Modify: `lib/features/bus/presentation/widgets/bus_orders_section.dart`
- Modify: `lib/features/bus/presentation/widgets/bus_order_detail_sheet.dart`
- Modify: `test/features/bus/presentation/widgets/bus_order_card_test.dart`
- Modify: `test/features/bus/presentation/widgets/bus_order_detail_sheet_test.dart`

**Interfaces:**
- Consumes: `busOrderCanRate`, `showOrderReviewSheet`, `BusRepository.submitReview`, shared widgets
- Produces: Rate CTA / Rated badge on card stub and detail sheet

- [ ] **Step 1: Failing card tests**

- Confirmed + `canReview` → finds Rate trip
- `reviewRating: 5` → finds Rated badge, no Rate trip
- Pending → neither

- [ ] **Step 2: Extend `BusOrderCard`**

Add optional `VoidCallback? onRate`. Include rate row in stub height when `busOrderCanRate(order)` **or** `order.reviewRating != null`.

In `_OrderActions`:
- If `busOrderCanRate(order)` → `OrderRateTripButton(onPressed: onRate!)` (require non-null onRate when eligible — section always passes it)
- Else if `order.reviewRating != null` → `OrderRatedBadge(rating: order.reviewRating!)`
- Keep existing pay / e-ticket / cancel layout; rate/badge as an extra row (update `_stubHeightFor` accordingly — one extra `_cardActionHeight` + gap when review UI shown)

Wrap rate button so card `InkWell.onTap` does not fire: use a button (already stops propagation).

- [ ] **Step 3: Wire `BusOrdersSection`**

```dart
Future<void> _rate(BuildContext context, WidgetRef ref, BusOrder order) async {
  await showOrderReviewSheet(
    context,
    onSubmit: (rating, comment) async {
      await ref.read(busRepositoryProvider).submitReview(
            orderId: order.orderId,
            rating: rating,
            comment: comment,
          );
      await ref.read(busOrdersProvider.notifier).refresh();
      ref.invalidate(busOrderDetailProvider(order.orderId));
    },
  );
}
```

Pass `onRate: () => _rate(context, ref, order)` into the card.

- [ ] **Step 4: Detail sheet** — same eligibility; place CTA/badge below status / above actions; same `showOrderReviewSheet` + refresh.

- [ ] **Step 5: Run bus widget tests — PASS**

- [ ] **Step 6: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(bus): wire rate trip CTA on order card and detail sheet

EOF
)"
```

---

### Task 5: Car — data + UI

**Files:**
- Modify: `lib/features/car/domain/entities/car_order.dart` — add `canReview`, `reviewRating`; add `copyWith` including new fields
- Create: `lib/features/car/domain/utils/car_order_review.dart` — `carOrderCanRate`
- Modify: `lib/features/car/data/car_dto_mapper.dart`
- Modify: `lib/features/car/data/car_api.dart`
- Modify: `lib/features/car/domain/repositories/car_repository.dart`
- Modify: `lib/features/car/data/car_repository_impl.dart`
- Modify: `lib/features/car/presentation/widgets/car_order_card.dart`
- Modify: `lib/features/car/presentation/widgets/car_orders_section.dart`
- Modify: `lib/features/car/presentation/widgets/car_order_detail_sheet.dart`
- Modify: `test/features/car/fake_car_repository.dart` + fixtures/tests

**Interfaces:**
- Produces:
  - `bool carOrderCanRate(CarOrder order)` → confirmed && canReview && reviewRating == null
  - `Future<void> CarRepository.submitReview({required int orderId, required int rating, String? comment})`
  - Path: `POST /profile/private/orders/$orderId/review`

- [ ] **Step 1: Failing mapper + eligibility + submit tests** (mirror bus)

- [ ] **Step 2: Implement entity/mapper/API/repo**

```dart
canReview: json['can_review'] == true,
reviewRating: parseOrderReviewRating(json['review']),
```

- [ ] **Step 3: Update all `CarOrder(` constructions** in tests/fakes

- [ ] **Step 4: Wire card + detail** same pattern as bus (`orderId` is `int` → `order.id`)

- [ ] **Step 5: Run car tests — PASS**

```bash
flutter test test/features/car/
```

- [ ] **Step 6: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(car): add order review mapping, API, and ticket UI

EOF
)"
```

---

### Task 6: Flight — data + UI (card only)

**Files:**
- Modify: `lib/features/flight/domain/entities/flight_order.dart` — `@Default(false) bool canReview`, `int? reviewRating`
- Create: `lib/features/flight/domain/utils/flight_order_review.dart`

```dart
bool flightOrderCanRate(FlightOrder order) =>
    isFlightOrderPaid(order) &&
    order.canReview &&
    order.reviewRating == null;
```

- Modify: `lib/features/flight/data/flight_dto_mapper.dart` — `_orderFromJson`
- Modify: `lib/features/flight/data/flight_api.dart`
- Modify: `lib/features/flight/domain/repositories/flight_repository.dart`
- Modify: `lib/features/flight/data/flight_repository_impl.dart`
- Modify: `lib/features/flight/presentation/widgets/flight_orders_section.dart` (`_FlightOrderCard`)
- Modify: fakes/fixtures/`flight_order_status_test` constructions
- Create: mapper/eligibility/submit tests under `test/features/flight/`

**Interfaces:**
- Produces: `FlightRepository.submitReview({required String orderId, required int rating, String? comment})`
- Path: `POST /profile/flights/orders/$orderId/review`
- UI: Rate / Rated on My Tickets flight card only (no new detail sheet)

- [ ] **Step 1: Failing tests** (mapper defaults missing keys to `canReview: false`; eligibility uses `isFlightOrderPaid`)

- [ ] **Step 2: Freezed fields + codegen**

- [ ] **Step 3: Mapper + API + repo**

- [ ] **Step 4: Wire `_FlightOrderCard`** — convert to `ConsumerWidget` if needed for `ref`; add rate/badge row; `ref.invalidate(flightOrdersProvider)` after success

- [ ] **Step 5: Run flight + shared tests — PASS**

```bash
flutter test test/features/flight/ test/shared/
```

- [ ] **Step 6: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(flight): add order review mapping, API, and tickets card CTA

EOF
)"
```

---

### Task 7: Full verification

- [ ] **Step 1: Analyze**

```bash
flutter analyze
```

Expected: no issues in touched files.

- [ ] **Step 2: Run focused suites**

```bash
flutter test \
  test/shared/utils/order_review_mapping_test.dart \
  test/shared/widgets/ \
  test/features/bus/domain/bus_order_review_test.dart \
  test/features/bus/presentation/widgets/bus_order_card_test.dart \
  test/features/bus/presentation/widgets/bus_order_detail_sheet_test.dart \
  test/features/car/ \
  test/features/flight/domain/ \
  test/features/flight/data/flight_order_mapper_test.dart \
  test/features/tickets/
```

Expected: all PASS (update any broken constructors from new Freezed defaults).

- [ ] **Step 3: Spec compliance self-check**

- [ ] Card + detail entry for bus/car; flight card
- [ ] Eligibility = success/confirmed ∧ canReview ∧ no rating
- [ ] Optional comment; required stars
- [ ] After submit: Rated ★x only
- [ ] No comment display; no edit/delete; no `/profile/tickets` support tickets
- [ ] Shared widgets have no feature imports

- [ ] **Step 4: Final commit if any analyze/test fixes remain**

```bash
git commit -m "$(cat <<'EOF'
fix: finish order review analyze and test fallout

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Shared sheet / CTA / badge | 2 |
| `parseOrderReviewRating` defensive mapping | 1 |
| l10n AR+EN | 1 |
| Bus map + submit + eligibility | 3 |
| Bus card + detail | 4 |
| Car map + submit + card + detail | 5 |
| Flight map + submit + card | 6 |
| No comment after submit; no edit | 2, 4–6 |
| Refresh + local consistency | 4–6 |
| Out of scope honored | 7 |

## Self-review notes

- No TBD placeholders; signatures aligned across tasks (`rating` int in Dart, string in JSON).
- Car uses `int orderId`; bus/flight use `String` — matches existing repos.
- Flight detail sheet deferred per spec (card-only v1).
- Phosphor: stick to Light stars; amber color for selected state to avoid Fill unless already used in repo.
