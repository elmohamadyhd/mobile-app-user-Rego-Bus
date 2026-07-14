# My Tickets Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the "My Tickets" (تذاكري) bottom-nav tab, replacing its `ComingSoonScreen` placeholder with a list of the rider's booked bus trips from `GET /profile/buses/orders`, with resume-payment, open-e-ticket, and cancel actions.

**Architecture:** A thin `features/tickets/` composition shell (`TicketsScreen`) renders the Skyline hero and drops in `BusOrdersSection` — a widget owned entirely by `features/bus/`, which owns the new `BusOrder` entity, mapper, repository methods, and provider. The existing `PaymentWebViewScreen` gains an optional `PaymentFlowArgs` so "Complete payment" reuses its gateway-redirect logic without touching the active booking flow.

**Tech Stack:** Flutter, Riverpod (manual `Notifier`/`AsyncNotifier` — no codegen), go_router, Freezed, Dio, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-07-14-tickets-tab-design.md`

---

## Notes for the implementing engineer

- Freezed entities require `dart run build_runner build --delete-conflicting-outputs` before they compile — Task 1 generates code before anything else can reference `BusOrder`, so its steps aren't classic red/green TDD (there's no way to get a clean assertion failure against a symbol that doesn't exist yet in a statically typed language). Real TDD starts in Task 2, against the plain-Dart mapper logic.
- Existing convention: `BusApi` (raw Dio calls) and `BusRepositoryImpl` (thin pass-through) have **no dedicated unit tests** anywhere in this codebase — coverage comes from `BusDtoMapper` tests (parsing logic) plus notifier/widget tests using `FakeBusRepository`. Task 3/4 follow that precedent; don't add `bus_api_test.dart`.
- `PaymentWebViewScreen` cannot be widget-tested end-to-end today (it creates a real `WebViewController` in `initState`, which hits a platform channel `flutter test` can't satisfy) — the existing `payment_webview_screen_test.dart` only tests the standalone `confirmLeavePayment` dialog function. Task 12 follows that same boundary; don't try to pump the full screen.
- Run `flutter analyze` after any task that touches more than one file, to catch import/type mistakes early rather than bundling them into Task 14.

---

### Task 1: `BusOrder` entity + `BusOrderStatusKind`

**Files:**
- Create: `lib/features/bus/domain/entities/bus_order.dart`

- [ ] **Step 1: Write the entity**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bus_order.freezed.dart';

/// Derived from `status_code` + `is_confirmed` on a bus order (see
/// [BusDtoMapper.orderStatusKind]). Backend vocabulary beyond `pending` is
/// inferred, not documented — unrecognized codes render as [unknown] rather
/// than being guessed into a destructive/positive bucket.
enum BusOrderStatusKind { pending, confirmed, cancelled, unknown }

/// One booked bus trip from `GET /profile/buses/orders` — the "My Tickets"
/// list-item shape. Distinct from [BusTicket] (the post-booking confirmation
/// entity) and `BusOrderStatus` (the payment-verify result).
@freezed
abstract class BusOrder with _$BusOrder {
  const factory BusOrder({
    required String orderId,
    required String bookingNumber,
    required String operatorName,
    String? operatorLogoUrl,
    required String category,
    required String statusText,
    required BusOrderStatusKind statusKind,
    required String dateTimeLabel,
    required List<String> seats,
    required String total,
    required bool canCancel,
    String? gatewayCheckoutUrl,
    String? invoiceUrl,
  }) = _BusOrder;
}
```

- [ ] **Step 2: Generate the Freezed code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/features/bus/domain/entities/bus_order.freezed.dart` is created; no errors.

- [ ] **Step 3: Confirm it compiles clean**

Run: `flutter analyze lib/features/bus/domain/entities/bus_order.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/bus/domain/entities/bus_order.dart lib/features/bus/domain/entities/bus_order.freezed.dart
git commit -m "feat(bus): add BusOrder entity for the My Tickets list"
```

---

### Task 2: `BusDtoMapper` order parsing (TDD)

**Files:**
- Modify: `lib/features/bus/data/bus_dto_mapper.dart`
- Modify: `test/features/bus/data/bus_fixtures.dart`
- Modify: `test/features/bus/data/bus_dto_mapper_test.dart`

- [ ] **Step 1: Add the fixture**

Append to `test/features/bus/data/bus_fixtures.dart`:

```dart
/// Real `GET /profile/buses/orders` response (trimmed to mapped fields).
/// See docs/wadeny-apis.md → Orders > Buses. Second entry has no
/// `payment_data` at all, to exercise a confirmed order with no checkout URL.
const busOrdersEnvelope = {
  'status': 200,
  'message': 'Bus orders',
  'errors': <String, dynamic>{},
  'data': [
    {
      'number': '000001475',
      'id': 1475,
      'company_data': {
        'name': 'SuperJet',
        'avatar': '',
        'bus_image': '',
        'pin': '',
      },
      'status': 'Pending',
      'status_code': 'pending',
      'company_name': 'SuperJet',
      'category': 'Five stars',
      'can_be_cancel': true,
      'is_confirmed': 0,
      'payment_data': {
        'status': 'Pending',
        'status_code': 'pending',
        'invoice_id': 6956732,
        'gateway': 'Myfatoorah',
        'invoice_url': 'https://demo.MyFatoorah.com/KWT/ia/010726954',
        'data': {'notes': ''},
      },
      'invoice_url': 'https://portal.wdenytravel.com/orders/1475/invoice',
      'tickets': [
        {'id': 2076, 'seat_number': '1', 'price': '205.00'},
      ],
      'date': '2026-07-30',
      'date_time': '2026-07-30 08:45 AM',
      'cancel_url':
          'https://portal.wdenytravel.com/api/v1/buses/orders/1475/cancel',
      'total': 'EGP 219.35',
      'currency': 'EGP',
    },
    {
      'number': '000001470',
      'id': 1470,
      'company_data': {
        'name': 'SuperJet',
        'avatar': '',
        'bus_image': '',
        'pin': '',
      },
      'status': 'Confirmed',
      'status_code': 'confirmed',
      'company_name': 'SuperJet',
      'category': 'VIP',
      'can_be_cancel': false,
      'is_confirmed': 1,
      'invoice_url': 'https://portal.wdenytravel.com/orders/1470/invoice',
      'tickets': [
        {'id': 2070, 'seat_number': '2', 'price': '225.00'},
      ],
      'date': '2026-07-30',
      'date_time': '2026-07-30 04:30 AM',
      'total': 'EGP 240.75',
      'currency': 'EGP',
    },
  ],
  'pagination': {
    'total': 2,
    'lastPage': 1,
    'perPage': 15,
    'currentPage': 1,
    'nextPageUrl': null,
    'previousPageUrl': null,
  },
};
```

- [ ] **Step 2: Write the failing tests**

Append to `test/features/bus/data/bus_dto_mapper_test.dart` (inside the existing `group('BusDtoMapper', () { ... })`, add a sibling `import` at the top first):

```dart
import 'package:rego/features/bus/domain/entities/bus_order.dart';
```

Then add these groups at the end of the `group('BusDtoMapper', ...)` body, before its closing `});`:

```dart
    group('ordersFromEnvelope', () {
      test('maps bus orders list with status, seats, and URLs', () {
        final orders = BusDtoMapper.ordersFromEnvelope(busOrdersEnvelope);
        expect(orders, hasLength(2));

        final pending = orders.first;
        expect(pending.orderId, '1475');
        expect(pending.bookingNumber, '000001475');
        expect(pending.operatorName, 'SuperJet');
        expect(pending.category, 'Five stars');
        expect(pending.statusKind, BusOrderStatusKind.pending);
        expect(pending.seats, ['1']);
        expect(pending.total, 'EGP 219.35');
        expect(pending.canCancel, isTrue);
        expect(pending.gatewayCheckoutUrl, isNotNull);
        expect(pending.invoiceUrl, isNotNull);
      });

      test('confirmed order without payment_data has no checkout url', () {
        final orders = BusDtoMapper.ordersFromEnvelope(busOrdersEnvelope);
        final confirmed = orders[1];
        expect(confirmed.statusKind, BusOrderStatusKind.confirmed);
        expect(confirmed.canCancel, isFalse);
        expect(confirmed.gatewayCheckoutUrl, isNull);
      });
    });

    group('orderStatusKind', () {
      test('is_confirmed flag wins regardless of status_code', () {
        expect(
          BusDtoMapper.orderStatusKind('pending', 1),
          BusOrderStatusKind.confirmed,
        );
      });

      test('maps known confirmed/cancelled codes', () {
        expect(BusDtoMapper.orderStatusKind('confirmed', 0),
            BusOrderStatusKind.confirmed);
        expect(
            BusDtoMapper.orderStatusKind('paid', 0), BusOrderStatusKind.confirmed);
        expect(BusDtoMapper.orderStatusKind('cancelled', 0),
            BusOrderStatusKind.cancelled);
        expect(BusDtoMapper.orderStatusKind('expired', 0),
            BusOrderStatusKind.cancelled);
      });

      test('pending code with no confirm flag stays pending', () {
        expect(BusDtoMapper.orderStatusKind('pending', 0),
            BusOrderStatusKind.pending);
      });

      test('unrecognized code falls back to unknown', () {
        expect(BusDtoMapper.orderStatusKind('weird_code', 0),
            BusOrderStatusKind.unknown);
      });
    });
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/features/bus/data/bus_dto_mapper_test.dart`
Expected: FAIL — compile error, `orderStatusKind`/`ordersFromEnvelope` aren't defined on `BusDtoMapper`.

- [ ] **Step 4: Implement the mapper methods**

Add to `lib/features/bus/data/bus_dto_mapper.dart`: first, add the import at the top of the file (alongside the other entity imports):

```dart
import 'package:rego/features/bus/domain/entities/bus_order.dart';
```

Then add these methods inside `abstract final class BusDtoMapper { ... }` (anywhere alongside the other `...FromEnvelope`/`...FromJson` methods, e.g. after `orderStatusFromEnvelope`):

```dart
  static List<BusOrder> ordersFromEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    ensureSuccess(envelope);
    final data = envelope['data'];
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().map(orderFromJson).toList();
  }

  static BusOrder orderFromJson(Map<String, dynamic> json) {
    final companyData = json['company_data'];
    String? logo;
    String? companyName;
    if (companyData is Map<String, dynamic>) {
      logo = _string(companyData['avatar']);
      if (logo != null && logo.isEmpty) logo = null;
      companyName = _string(companyData['name']);
    }

    final statusCode = _string(json['status_code']) ?? '';
    final isConfirmedFlag = _int(json['is_confirmed']) ?? 0;

    final ticketsRaw = json['tickets'];
    final seats = ticketsRaw is List
        ? ticketsRaw
            .whereType<Map<String, dynamic>>()
            .map((t) => _string(t['seat_number']) ?? '')
            .where((s) => s.isNotEmpty)
            .toList()
        : <String>[];

    final paymentData = json['payment_data'];
    final gatewayCheckoutUrl = paymentData is Map<String, dynamic>
        ? _string(paymentData['invoice_url'])
        : null;

    return BusOrder(
      orderId: _string(json['id']) ?? '',
      bookingNumber: _string(json['number']) ?? '',
      operatorName: _string(json['company_name']) ?? companyName ?? '',
      operatorLogoUrl: logo,
      category: _string(json['category']) ?? '',
      statusText: _string(json['status']) ?? '',
      statusKind: orderStatusKind(statusCode, isConfirmedFlag),
      dateTimeLabel: _string(json['date_time']) ?? _string(json['date']) ?? '',
      seats: seats,
      total: _string(json['total']) ?? '',
      canCancel: json['can_be_cancel'] == true,
      gatewayCheckoutUrl:
          (gatewayCheckoutUrl != null && gatewayCheckoutUrl.isNotEmpty)
              ? gatewayCheckoutUrl
              : null,
      invoiceUrl: _string(json['invoice_url']),
    );
  }

  /// Same documented-uncertainty caveat as [isPaidStatus]: only `pending`
  /// appears in the sample data. `is_confirmed == 1` always wins; unrecognized
  /// codes fall back to [BusOrderStatusKind.unknown] rather than being
  /// guessed into a destructive or positive bucket.
  static BusOrderStatusKind orderStatusKind(
    String statusCode,
    int isConfirmedFlag,
  ) {
    if (isConfirmedFlag == 1) return BusOrderStatusKind.confirmed;
    final code = statusCode.trim().toLowerCase();
    const confirmedCodes = {
      'confirmed',
      'paid',
      'success',
      'completed',
      'succeeded',
    };
    const cancelledCodes = {
      'cancelled',
      'canceled',
      'expired',
      'failed',
      'refunded',
    };
    if (confirmedCodes.contains(code)) return BusOrderStatusKind.confirmed;
    if (cancelledCodes.contains(code)) return BusOrderStatusKind.cancelled;
    if (code == 'pending') return BusOrderStatusKind.pending;
    return BusOrderStatusKind.unknown;
  }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/bus/data/bus_dto_mapper_test.dart`
Expected: PASS — all tests green, including the pre-existing ones.

- [ ] **Step 6: Commit**

```bash
git add lib/features/bus/data/bus_dto_mapper.dart test/features/bus/data/bus_fixtures.dart test/features/bus/data/bus_dto_mapper_test.dart
git commit -m "feat(bus): map GET /profile/buses/orders into BusOrder"
```

---

### Task 3: `BusApi` order endpoints

**Files:**
- Modify: `lib/features/bus/data/bus_api.dart`

- [ ] **Step 1: Add `listOrders` and `cancelOrder`**

Append to the `BusApi` class in `lib/features/bus/data/bus_api.dart` (after the existing `orderStatus` method):

```dart
  Future<dynamic> listOrders() async {
    final res = await _dio.get('/profile/buses/orders');
    return res.data;
  }

  /// ⚠️ Backend dependency: cancel endpoint path/method inferred from the
  /// `cancel_url` field returned alongside orders (e.g.
  /// `.../buses/orders/{id}/cancel`) — not separately documented in the
  /// Wadeny API reference. Same caveat as [orderStatusPath].
  static String cancelOrderPath(String orderId) =>
      '/buses/orders/$orderId/cancel';

  Future<dynamic> cancelOrder(String orderId) async {
    final res = await _dio.post(cancelOrderPath(orderId));
    return res.data;
  }
```

- [ ] **Step 2: Confirm it compiles**

Run: `flutter analyze lib/features/bus/data/bus_api.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/bus/data/bus_api.dart
git commit -m "feat(bus): add listOrders and cancelOrder to BusApi"
```

---

### Task 4: `BusRepository` + impl + fake

**Files:**
- Modify: `lib/features/bus/domain/repositories/bus_repository.dart`
- Modify: `lib/features/bus/data/bus_repository_impl.dart`
- Modify: `test/features/bus/fake_bus_repository.dart`

- [ ] **Step 1: Extend the repository interface**

In `lib/features/bus/domain/repositories/bus_repository.dart`, add the import:

```dart
import 'package:rego/features/bus/domain/entities/bus_order.dart';
```

And add two methods to `abstract interface class BusRepository { ... }` (after `orderStatus`):

```dart
  /// Lists the signed-in rider's booked bus trips (My Tickets tab).
  Future<List<BusOrder>> listOrders();

  /// Cancels a cancellable order. Throws [ApiException] on failure.
  Future<void> cancelOrder(String orderId);
```

- [ ] **Step 2: Implement in `BusRepositoryImpl`**

Add to `lib/features/bus/data/bus_repository_impl.dart` (after the existing `orderStatus` override):

```dart
  @override
  Future<List<BusOrder>> listOrders() {
    return _guard(() async {
      final body = await _api.listOrders();
      return BusDtoMapper.ordersFromEnvelope(body);
    });
  }

  @override
  Future<void> cancelOrder(String orderId) {
    return _guard(() async {
      final body = await _api.cancelOrder(orderId);
      BusDtoMapper.ensureSuccess(body as Map<String, dynamic>);
    });
  }
```

(No new import needed — `bus_order.dart` is already pulled in transitively via `bus_repository.dart`'s own import, but add `import 'package:rego/features/bus/domain/entities/bus_order.dart';` directly to `bus_repository_impl.dart` too, since Dart doesn't re-export symbols across files by default.)

- [ ] **Step 3: Extend `FakeBusRepository` for tests**

In `test/features/bus/fake_bus_repository.dart`, add imports:

```dart
import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/bus/domain/entities/bus_order.dart';
```

Add fields (in the constructor's parameter list and as class fields):

```dart
  FakeBusRepository({
    this.tripsPage,
    this.tripByIdResult,
    this.seatMapResult,
    this.ticketResult,
    this.orderStatusResult,
    this.ordersResult,
  });

  // ... existing fields unchanged ...
  List<BusOrder>? ordersResult;
  int listOrdersCallCount = 0;
  bool listOrdersShouldThrow = false;
  List<String> cancelOrderCalls = [];
  bool cancelOrderShouldThrow = false;
```

Add the method implementations (anywhere in the class body):

```dart
  @override
  Future<List<BusOrder>> listOrders() async {
    listOrdersCallCount++;
    if (listOrdersShouldThrow) {
      throw const ApiException('Failed to load orders', statusCode: 500);
    }
    return ordersResult ?? const [];
  }

  @override
  Future<void> cancelOrder(String orderId) async {
    cancelOrderCalls.add(orderId);
    if (cancelOrderShouldThrow) {
      throw const ApiException('Cannot cancel', statusCode: 422);
    }
  }
```

- [ ] **Step 4: Confirm everything compiles**

Run: `flutter analyze lib/features/bus test/features/bus`
Expected: `No issues found!`

- [ ] **Step 5: Run the full bus test suite to check nothing broke**

Run: `flutter test test/features/bus`
Expected: PASS — all existing tests still green (the fake now implements two more interface methods, which is additive).

- [ ] **Step 6: Commit**

```bash
git add lib/features/bus/domain/repositories/bus_repository.dart lib/features/bus/data/bus_repository_impl.dart test/features/bus/fake_bus_repository.dart
git commit -m "feat(bus): add listOrders/cancelOrder to BusRepository"
```

---

### Task 5: `busOrdersProvider` (TDD)

**Files:**
- Create: `lib/features/bus/presentation/providers/bus_orders_provider.dart`
- Create: `test/features/bus/presentation/bus_orders_notifier_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/providers/bus_orders_provider.dart';

import 'fake_bus_repository.dart';

BusOrder _order({
  String orderId = '1475',
  BusOrderStatusKind statusKind = BusOrderStatusKind.pending,
  bool canCancel = true,
}) {
  return BusOrder(
    orderId: orderId,
    bookingNumber: '000001475',
    operatorName: 'SuperJet',
    category: 'Five stars',
    statusText: 'Pending',
    statusKind: statusKind,
    dateTimeLabel: '2026-07-30 08:45 AM',
    seats: const ['1'],
    total: 'EGP 219.35',
    canCancel: canCancel,
    gatewayCheckoutUrl: 'https://demo.MyFatoorah.com/pay',
    invoiceUrl: 'https://portal.wdenytravel.com/orders/1475/invoice',
  );
}

void main() {
  ProviderContainer makeContainer(FakeBusRepository repo) {
    final container = ProviderContainer(
      overrides: [busRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('BusOrdersNotifier', () {
    test('build loads orders from the repository', () async {
      final repo = FakeBusRepository(ordersResult: [_order()]);
      final container = makeContainer(repo);

      final orders = await container.read(busOrdersProvider.future);

      expect(orders, hasLength(1));
      expect(orders.first.orderId, '1475');
    });

    test('refresh re-fetches and replaces the list', () async {
      final repo = FakeBusRepository(ordersResult: [_order()]);
      final container = makeContainer(repo);
      await container.read(busOrdersProvider.future);

      repo.ordersResult = [_order(orderId: '9999')];
      await container.read(busOrdersProvider.notifier).refresh();

      final orders = container.read(busOrdersProvider).value;
      expect(orders, isNotNull);
      expect(orders!.single.orderId, '9999');
    });

    test('cancel calls the repository and refreshes on success', () async {
      final repo = FakeBusRepository(ordersResult: [_order()]);
      final container = makeContainer(repo);
      await container.read(busOrdersProvider.future);

      final success =
          await container.read(busOrdersProvider.notifier).cancel('1475');

      expect(success, isTrue);
      expect(repo.cancelOrderCalls, ['1475']);
    });

    test('cancel returns false and keeps the list on repository failure',
        () async {
      final repo = FakeBusRepository(ordersResult: [_order()])
        ..cancelOrderShouldThrow = true;
      final container = makeContainer(repo);
      await container.read(busOrdersProvider.future);

      final success =
          await container.read(busOrdersProvider.notifier).cancel('1475');

      expect(success, isFalse);
      final orders = container.read(busOrdersProvider).value;
      expect(orders, hasLength(1));
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/bus/presentation/bus_orders_notifier_test.dart`
Expected: FAIL — compile error, `bus_orders_provider.dart` doesn't exist.

- [ ] **Step 3: Implement the provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';

/// Owns the "My Tickets" list of booked bus trips. A plain
/// `AsyncNotifierProvider` (not autoDispose) so state survives switching
/// bottom-nav tabs, matching `busBookingProvider`/`sessionControllerProvider`.
class BusOrdersNotifier extends AsyncNotifier<List<BusOrder>> {
  @override
  Future<List<BusOrder>> build() {
    return ref.read(busRepositoryProvider).listOrders();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(busRepositoryProvider).listOrders(),
    );
  }

  /// Cancels [orderId] and refreshes the list. Returns whether it succeeded
  /// so the caller can show the right toast.
  Future<bool> cancel(String orderId) async {
    try {
      await ref.read(busRepositoryProvider).cancelOrder(orderId);
    } catch (_) {
      return false;
    }
    await refresh();
    return true;
  }
}

final busOrdersProvider =
    AsyncNotifierProvider<BusOrdersNotifier, List<BusOrder>>(
  BusOrdersNotifier.new,
);
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/bus/presentation/bus_orders_notifier_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bus/presentation/providers/bus_orders_provider.dart test/features/bus/presentation/bus_orders_notifier_test.dart
git commit -m "feat(bus): add busOrdersProvider with refresh and cancel"
```

---

### Task 6: Localization keys

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ar.arb`

- [ ] **Step 1: Add English keys**

In `lib/l10n/app_en.arb`, insert after the `eTicketDownloadFailed` line (currently line 269, just before the `profileMenuTrips` block):

```json
  "ticketsCountLabel": "{count} tickets",
  "@ticketsCountLabel": {
    "description": "Order count caption on the My Tickets tab hero.",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "ticketsEmptyTitle": "No tickets yet",
  "ticketsEmptyBody": "Your booked trips will show up here.",
  "ticketsBookCta": "Book a trip",
  "ticketsError": "Couldn't load your tickets",
  "ticketStatusPending": "Pending",
  "ticketStatusConfirmed": "Confirmed",
  "ticketStatusCancelled": "Cancelled",
  "ticketStatusUnknown": "Unknown",
  "ticketActionPay": "Complete payment",
  "ticketActionCancel": "Cancel",
  "ticketCancelTitle": "Cancel this ticket?",
  "ticketCancelBody": "This booking will be cancelled and can't be undone.",
  "ticketCancelConfirm": "Cancel ticket",
  "ticketCancelKeep": "Keep it",
  "ticketCancelSuccess": "Ticket cancelled",
  "ticketCancelFailed": "Couldn't cancel the ticket. Please try again",
  "ticketResumePaidToast": "Payment confirmed! Your ticket is ready.",
  "ticketResumePendingToast": "We couldn't confirm the payment yet. It may take a moment.",
```

Keep the trailing `"profileMenuTrips": "My trips",` block right after it unchanged.

- [ ] **Step 2: Add matching Arabic keys**

In `lib/l10n/app_ar.arb`, insert after the `eTicketDownloadFailed` line (currently line 179, just before `profileMenuTrips`):

```json
  "ticketsCountLabel": "{count} تذكرة",
  "ticketsEmptyTitle": "لا توجد تذاكر بعد",
  "ticketsEmptyBody": "ستظهر رحلاتك المحجوزة هنا.",
  "ticketsBookCta": "احجز رحلة",
  "ticketsError": "تعذّر تحميل تذاكرك",
  "ticketStatusPending": "قيد الانتظار",
  "ticketStatusConfirmed": "مؤكدة",
  "ticketStatusCancelled": "ملغاة",
  "ticketStatusUnknown": "غير معروفة",
  "ticketActionPay": "أكمل الدفع",
  "ticketActionCancel": "إلغاء",
  "ticketCancelTitle": "إلغاء هذه التذكرة؟",
  "ticketCancelBody": "سيتم إلغاء هذا الحجز ولا يمكن التراجع عن ذلك.",
  "ticketCancelConfirm": "إلغاء التذكرة",
  "ticketCancelKeep": "احتفظ بها",
  "ticketCancelSuccess": "تم إلغاء التذكرة",
  "ticketCancelFailed": "تعذر إلغاء التذكرة، حاول مرة أخرى",
  "ticketResumePaidToast": "تم تأكيد الدفع! تذكرتك جاهزة.",
  "ticketResumePendingToast": "لم نتمكن من تأكيد الدفع بعد، قد يستغرق الأمر بعض الوقت.",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: Regenerates `lib/l10n/app_localizations*.dart` (gitignored) with no errors. If it errors, check for a trailing-comma/bracket mismatch at the insertion point in either `.arb` file.

- [ ] **Step 4: Confirm it compiles**

Run: `flutter analyze lib/l10n`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "feat(l10n): add My Tickets tab strings (en/ar)"
```

---

### Task 7: `OrderStatusBadge` widget (TDD)

**Files:**
- Create: `lib/features/bus/presentation/widgets/order_status_badge.dart`
- Create: `test/features/bus/presentation/widgets/order_status_badge_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/presentation/widgets/order_status_badge.dart';
import 'package:rego/l10n/app_localizations.dart';

Future<void> _pumpBadge(
  WidgetTester tester,
  BusOrderStatusKind kind, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Scaffold(body: OrderStatusBadge(statusKind: kind)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the localized label for each status kind',
      (tester) async {
    await _pumpBadge(tester, BusOrderStatusKind.pending);
    expect(find.text('Pending'), findsOneWidget);

    await _pumpBadge(tester, BusOrderStatusKind.confirmed);
    expect(find.text('Confirmed'), findsOneWidget);

    await _pumpBadge(tester, BusOrderStatusKind.cancelled);
    expect(find.text('Cancelled'), findsOneWidget);

    await _pumpBadge(tester, BusOrderStatusKind.unknown);
    expect(find.text('Unknown'), findsOneWidget);
  });

  testWidgets('renders in Arabic', (tester) async {
    await _pumpBadge(
      tester,
      BusOrderStatusKind.pending,
      locale: const Locale('ar'),
    );
    expect(find.text('قيد الانتظار'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/bus/presentation/widgets/order_status_badge_test.dart`
Expected: FAIL — compile error, `OrderStatusBadge` doesn't exist.

- [ ] **Step 3: Implement the widget**

```dart
import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/l10n/app_localizations.dart';

/// Colored status pill for a [BusOrder] — amber pending, green confirmed,
/// grey cancelled/unknown.
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.statusKind});

  final BusOrderStatusKind statusKind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, bg, fg) = switch (statusKind) {
      BusOrderStatusKind.pending => (
          l10n.ticketStatusPending,
          AppColors.secondaryTint,
          AppColors.onSecondary,
        ),
      BusOrderStatusKind.confirmed => (
          l10n.ticketStatusConfirmed,
          AppColors.success.withValues(alpha: 0.14),
          AppColors.success,
        ),
      BusOrderStatusKind.cancelled => (
          l10n.ticketStatusCancelled,
          AppColors.hairline,
          AppColors.textMuted,
        ),
      BusOrderStatusKind.unknown => (
          l10n.ticketStatusUnknown,
          AppColors.hairline,
          AppColors.textMuted,
        ),
    };

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style:
            AppTypography.caption.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/bus/presentation/widgets/order_status_badge_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bus/presentation/widgets/order_status_badge.dart test/features/bus/presentation/widgets/order_status_badge_test.dart
git commit -m "feat(bus): add OrderStatusBadge widget"
```

---

### Task 8: `BusOrderCard` widget (TDD)

**Files:**
- Create: `lib/features/bus/presentation/widgets/bus_order_card.dart`
- Create: `test/features/bus/presentation/widgets/bus_order_card_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/presentation/widgets/bus_order_card.dart';
import 'package:rego/l10n/app_localizations.dart';

BusOrder _order({
  BusOrderStatusKind statusKind = BusOrderStatusKind.pending,
  bool canCancel = true,
  String? gatewayCheckoutUrl = 'https://demo.MyFatoorah.com/pay',
  String? invoiceUrl = 'https://portal.wdenytravel.com/orders/1475/invoice',
}) {
  return BusOrder(
    orderId: '1475',
    bookingNumber: '000001475',
    operatorName: 'SuperJet',
    category: 'Five stars',
    statusText: 'Pending',
    statusKind: statusKind,
    dateTimeLabel: '2026-07-30 08:45 AM',
    seats: const ['1', '2'],
    total: 'EGP 219.35',
    canCancel: canCancel,
    gatewayCheckoutUrl: gatewayCheckoutUrl,
    invoiceUrl: invoiceUrl,
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  BusOrder order, {
  VoidCallback? onPay,
  VoidCallback? onOpenETicket,
  VoidCallback? onCancel,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: BusOrderCard(
          order: order,
          onPay: onPay ?? () {},
          onOpenETicket: onOpenETicket ?? () {},
          onCancel: onCancel ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders operator, category, seats and total', (tester) async {
    await _pumpCard(tester, _order());

    expect(find.text('SuperJet'), findsOneWidget);
    expect(find.text('Five stars'), findsOneWidget);
    expect(find.text('1, 2'), findsOneWidget);
    expect(find.text('EGP 219.35'), findsOneWidget);
  });

  testWidgets('pending order with checkout url shows Complete payment',
      (tester) async {
    var tapped = 0;
    await _pumpCard(tester, _order(), onPay: () => tapped++);

    final payButton = find.text('Complete payment');
    expect(payButton, findsOneWidget);

    await tester.tap(payButton);
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('confirmed order hides Complete payment', (tester) async {
    await _pumpCard(
      tester,
      _order(statusKind: BusOrderStatusKind.confirmed, canCancel: false),
    );

    expect(find.text('Complete payment'), findsNothing);
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('cancellable order shows Cancel and invokes onCancel',
      (tester) async {
    var tapped = 0;
    await _pumpCard(tester, _order(), onCancel: () => tapped++);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('order with no invoice hides the download action',
      (tester) async {
    await _pumpCard(tester, _order(invoiceUrl: null, canCancel: false));

    expect(find.text('Download'), findsNothing);
    expect(find.text('Complete payment'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/bus/presentation/widgets/bus_order_card_test.dart`
Expected: FAIL — compile error, `BusOrderCard` doesn't exist.

- [ ] **Step 3: Implement the widget**

```dart
import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/presentation/widgets/order_status_badge.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

/// Card for one [BusOrder] in the My Tickets list: operator identity, status
/// badge, key details, and the contextual pay/e-ticket/cancel actions.
class BusOrderCard extends StatelessWidget {
  const BusOrderCard({
    super.key,
    required this.order,
    required this.onPay,
    required this.onOpenETicket,
    required this.onCancel,
  });

  final BusOrder order;
  final VoidCallback onPay;
  final VoidCallback onOpenETicket;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seatsJoined = order.seats.join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _OrderAvatar(
                name: order.operatorName,
                logoUrl: order.operatorLogoUrl,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.operatorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (order.category.trim().isNotEmpty)
                      Text(
                        order.category,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OrderStatusBadge(statusKind: order.statusKind),
            ],
          ),
          if (order.dateTimeLabel.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(AppIcons.calendar,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  order.dateTimeLabel,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.hairline, height: 1),
          const SizedBox(height: AppSpacing.md),
          if (order.bookingNumber.isNotEmpty)
            _InfoRow(label: l10n.eTicketRef, value: '#${order.bookingNumber}'),
          if (seatsJoined.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            _InfoRow(label: l10n.eTicketSeats, value: seatsJoined),
          ],
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(label: l10n.tripResultsFareLabel, value: order.total),
          _OrderActions(
            order: order,
            onPay: onPay,
            onOpenETicket: onOpenETicket,
            onCancel: onCancel,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
        const Spacer(),
        Text(
          value,
          style: AppTypography.body.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _OrderAvatar extends StatelessWidget {
  const _OrderAvatar({required this.name, required this.logoUrl});

  final String name;
  final String? logoUrl;

  static const double _size = 42;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    return Container(
      width: _size,
      height: _size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: hasLogo
          ? Image.network(
              logoUrl!,
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initials(),
            )
          : _initials(),
    );
  }

  Widget _initials() {
    final trimmed = name.trim();
    final code = trimmed.isNotEmpty ? trimmed.substring(0, 1).toUpperCase() : '?';
    return Text(
      code,
      style: AppTypography.body.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
        fontSize: _size * 0.31,
      ),
    );
  }
}

class _OrderActions extends StatelessWidget {
  const _OrderActions({
    required this.order,
    required this.onPay,
    required this.onOpenETicket,
    required this.onCancel,
  });

  final BusOrder order;
  final VoidCallback onPay;
  final VoidCallback onOpenETicket;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showPay = order.statusKind == BusOrderStatusKind.pending &&
        (order.gatewayCheckoutUrl ?? '').isNotEmpty;
    final showETicket = (order.invoiceUrl ?? '').isNotEmpty;
    final showCancel = order.canCancel;

    if (!showPay && !showETicket && !showCancel) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showPay)
            PrimaryButton(label: l10n.ticketActionPay, onPressed: onPay),
          if (showPay && (showETicket || showCancel))
            const SizedBox(height: AppSpacing.sm),
          if (showETicket || showCancel)
            Row(
              children: [
                if (showETicket)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onOpenETicket,
                      icon: const Icon(AppIcons.download, size: 18),
                      label: Text(l10n.eTicketDownload),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      ),
                    ),
                  ),
                if (showETicket && showCancel)
                  const SizedBox(width: AppSpacing.sm),
                if (showCancel)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(AppIcons.close, size: 18),
                      label: Text(l10n.ticketActionCancel),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/bus/presentation/widgets/bus_order_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bus/presentation/widgets/bus_order_card.dart test/features/bus/presentation/widgets/bus_order_card_test.dart
git commit -m "feat(bus): add BusOrderCard with pay/e-ticket/cancel actions"
```

---

### Task 9: `ShellTabScrollView` optional `physics`

**Files:**
- Modify: `lib/shared/widgets/shell_tab_scroll_view.dart`

Small backward-compatible addition so `TicketsScreen` (Task 11) can wrap this in a `RefreshIndicator`, which needs `AlwaysScrollableScrollPhysics` to trigger the pull gesture when content is shorter than the viewport. Home/Profile don't pass it, so their behavior is unchanged.

- [ ] **Step 1: Add the `physics` field and forward it**

In `lib/shared/widgets/shell_tab_scroll_view.dart`, change the constructor and field list:

```dart
  const ShellTabScrollView({
    super.key,
    required this.hero,
    required this.children,
    this.cardOverlap = AppSpacing.xxl,
    this.physics,
  });

  final Widget hero;
  final List<Widget> children;
  final double cardOverlap;
  final ScrollPhysics? physics;
```

And pass it through in `build()`:

```dart
    return SingleChildScrollView(
      physics: physics,
      padding: EdgeInsetsDirectional.only(
```

(everything else in the file is unchanged)

- [ ] **Step 2: Confirm nothing broke**

Run: `flutter analyze lib/shared/widgets/shell_tab_scroll_view.dart && flutter test test/features/profile`
Expected: `No issues found!` and all profile tests still PASS (Home has no dedicated test file to check, but the change is additive/nullable so it can't regress).

- [ ] **Step 3: Commit**

```bash
git add lib/shared/widgets/shell_tab_scroll_view.dart
git commit -m "feat(shared): support scroll physics override in ShellTabScrollView"
```

---

### Task 10: `BusOrdersSection` widget (TDD)

**Files:**
- Create: `lib/features/bus/presentation/widgets/bus_orders_section.dart`
- Create: `test/features/bus/presentation/bus_orders_section_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/features/auth/domain/entities/auth_session.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/widgets/bus_order_card.dart';
import 'package:rego/features/bus/presentation/widgets/bus_orders_section.dart';
import 'package:rego/l10n/app_localizations.dart';

import 'fake_bus_repository.dart';

class _FakeSessionController extends SessionController {
  _FakeSessionController(this._initial);
  final AuthSession? _initial;
  @override
  Future<AuthSession?> build() async => _initial;
}

class _FakeGuestController extends GuestController {
  _FakeGuestController(this._value);
  final bool _value;
  @override
  Future<bool> build() async => _value;
}

BusOrder _order() => const BusOrder(
      orderId: '1475',
      bookingNumber: '000001475',
      operatorName: 'SuperJet',
      category: 'Five stars',
      statusText: 'Pending',
      statusKind: BusOrderStatusKind.pending,
      dateTimeLabel: '2026-07-30 08:45 AM',
      seats: ['1'],
      total: 'EGP 219.35',
      canCancel: true,
      gatewayCheckoutUrl: 'https://demo.MyFatoorah.com/pay',
      invoiceUrl: 'https://portal.wdenytravel.com/orders/1475/invoice',
    );

Future<void> _pumpSection(
  WidgetTester tester, {
  required bool isGuest,
  FakeBusRepository? repo,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(
          () => _FakeSessionController(
            isGuest ? null : const AuthSession(token: 't'),
          ),
        ),
        guestModeProvider.overrideWith(() => _FakeGuestController(isGuest)),
        busRepositoryProvider.overrideWithValue(repo ?? FakeBusRepository()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        locale: const Locale('en'),
        home: const Scaffold(body: BusOrdersSection()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('guest sees the sign-in card and no orders fetch',
      (tester) async {
    final repo = FakeBusRepository();
    await _pumpSection(tester, isGuest: true, repo: repo);

    expect(find.text('Sign in or create an account'), findsOneWidget);
    expect(repo.listOrdersCallCount, 0);
  });

  testWidgets('signed-in with orders renders a card per order',
      (tester) async {
    await _pumpSection(
      tester,
      isGuest: false,
      repo: FakeBusRepository(ordersResult: [_order()]),
    );

    expect(find.byType(BusOrderCard), findsOneWidget);
    expect(find.text('SuperJet'), findsOneWidget);
  });

  testWidgets('empty orders shows the empty state', (tester) async {
    await _pumpSection(
      tester,
      isGuest: false,
      repo: FakeBusRepository(ordersResult: const []),
    );

    expect(find.text('No tickets yet'), findsOneWidget);
    expect(find.text('Book a trip'), findsOneWidget);
  });

  testWidgets('repository failure shows the error state with retry',
      (tester) async {
    await _pumpSection(
      tester,
      isGuest: false,
      repo: FakeBusRepository()..listOrdersShouldThrow = true,
    );

    expect(find.text("Couldn't load your tickets"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/bus/presentation/bus_orders_section_test.dart`
Expected: FAIL — compile error, `BusOrdersSection` doesn't exist.

- [ ] **Step 3: Implement the widget**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/auth/presentation/auth_flow_args.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/bus/presentation/payment_webview_screen.dart';
import 'package:rego/features/bus/presentation/providers/bus_orders_provider.dart';
import 'package:rego/features/bus/presentation/widgets/bus_order_card.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

/// The bus-owned section dropped into the "My Tickets" tab shell
/// (`TicketsScreen`). Renders guest/loading/error/empty/list states for the
/// signed-in rider's bus orders — flight/car will add their own sibling
/// sections later, each equally self-contained.
class BusOrdersSection extends ConsumerWidget {
  const BusOrdersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(guestModeProvider).value ?? false;
    if (isGuest) return const _GuestSignInCard();

    final ordersAsync = ref.watch(busOrdersProvider);
    return ordersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) =>
          _ErrorState(onRetry: () => ref.invalidate(busOrdersProvider)),
      data: (orders) =>
          orders.isEmpty ? const _EmptyState() : _OrdersList(orders: orders),
    );
  }
}

class _GuestSignInCard extends StatelessWidget {
  const _GuestSignInCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: -12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => context.go(
            AppRoutes.login,
            extra: const AuthGateArgs(returnTo: AppRoutes.tickets),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(AppIcons.user,
                      size: 22, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.profileGuestSignInCta,
                    style: AppTypography.title.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(AppIcons.forward,
                    size: 20, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          const Icon(AppIcons.ticket, size: 40, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.ticketsEmptyTitle,
            style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.ticketsEmptyBody,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: l10n.ticketsBookCta,
            onPressed: () => context.go(AppRoutes.home),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          const Icon(AppIcons.error, size: 36, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.ticketsError,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            child: Text(l10n.tripResultsRetry),
          ),
        ],
      ),
    );
  }
}

class _OrdersList extends ConsumerWidget {
  const _OrdersList({required this.orders});

  final List<BusOrder> orders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        for (final order in orders)
          BusOrderCard(
            order: order,
            onPay: () => context.push(
              BusRoutes.pay,
              extra: PaymentFlowArgs(
                checkoutUrl: order.gatewayCheckoutUrl ?? '',
                orderId: order.orderId,
              ),
            ),
            onOpenETicket: () =>
                unawaited(_openETicket(context, order.invoiceUrl ?? '')),
            onCancel: () =>
                unawaited(_confirmCancel(context, ref, order.orderId)),
          ),
      ],
    );
  }
}

Future<void> _openETicket(BuildContext context, String invoiceUrl) async {
  final l10n = AppLocalizations.of(context);
  final uri = invoiceUrl.isEmpty ? null : Uri.tryParse(invoiceUrl);
  if (uri == null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.eTicketDownloadUnavailable)));
    return;
  }
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.eTicketDownloadFailed)));
  }
}

Future<void> _confirmCancel(
  BuildContext context,
  WidgetRef ref,
  String orderId,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      title: Text(l10n.ticketCancelTitle, style: AppTypography.h2),
      content: Text(
        l10n.ticketCancelBody,
        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            l10n.ticketCancelKeep,
            style: AppTypography.title.copyWith(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            l10n.ticketCancelConfirm,
            style: AppTypography.title.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  final success = await ref.read(busOrdersProvider.notifier).cancel(orderId);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content:
            Text(success ? l10n.ticketCancelSuccess : l10n.ticketCancelFailed),
      ),
    );
}
```

Note: `PaymentFlowArgs` doesn't exist yet — it's added in Task 12. This file won't compile until then; that's fine, Task 11 also depends on it transitively. Proceed to Step 4 anyway to lock in the test file, then treat Task 12 as unblocking compilation.

- [ ] **Step 4: Confirm the test file itself is well-formed**

Run: `flutter analyze test/features/bus/presentation/bus_orders_section_test.dart`
Expected: Errors only about `PaymentFlowArgs`/`BusOrdersSection` symbols inside `bus_orders_section.dart`, not about the test file's own syntax. This confirms the test is correctly written; full green comes after Task 12.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bus/presentation/widgets/bus_orders_section.dart test/features/bus/presentation/bus_orders_section_test.dart
git commit -m "feat(bus): add BusOrdersSection (guest/loading/error/empty/list states)"
```

---

### Task 11: `TicketsScreen` composition shell

**Files:**
- Create: `lib/features/tickets/presentation/tickets_screen.dart`
- Create: `test/features/tickets/tickets_screen_test.dart`

This screen also transitively imports `bus_orders_section.dart`, which references `PaymentFlowArgs` (not defined until Task 12). Write it now; full compilation and green tests land after Task 12.

- [ ] **Step 1: Write the tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/features/auth/domain/entities/auth_session.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/widgets/bus_order_card.dart';
import 'package:rego/features/tickets/presentation/tickets_screen.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../bus/fake_bus_repository.dart';

class _FakeSessionController extends SessionController {
  _FakeSessionController(this._initial);
  final AuthSession? _initial;
  @override
  Future<AuthSession?> build() async => _initial;
}

class _FakeGuestController extends GuestController {
  _FakeGuestController(this._value);
  final bool _value;
  @override
  Future<bool> build() async => _value;
}

BusOrder _pendingOrder() => const BusOrder(
      orderId: '1475',
      bookingNumber: '000001475',
      operatorName: 'SuperJet',
      category: 'Five stars',
      statusText: 'Pending',
      statusKind: BusOrderStatusKind.pending,
      dateTimeLabel: '2026-07-30 08:45 AM',
      seats: ['1'],
      total: 'EGP 219.35',
      canCancel: true,
      gatewayCheckoutUrl: 'https://demo.MyFatoorah.com/pay',
      invoiceUrl: 'https://portal.wdenytravel.com/orders/1475/invoice',
    );

Future<void> _pumpTickets(
  WidgetTester tester, {
  required bool isGuest,
  FakeBusRepository? repo,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(
          () => _FakeSessionController(
            isGuest ? null : const AuthSession(token: 't'),
          ),
        ),
        guestModeProvider.overrideWith(() => _FakeGuestController(isGuest)),
        busRepositoryProvider.overrideWithValue(repo ?? FakeBusRepository()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        locale: const Locale('en'),
        home: const TicketsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('guest sees sign-in CTA and no order cards', (tester) async {
    await _pumpTickets(tester, isGuest: true);

    expect(find.text('Sign in or create an account'), findsOneWidget);
    expect(find.byType(BusOrderCard), findsNothing);
  });

  testWidgets('signed-in rider sees their orders and a count in the hero',
      (tester) async {
    await _pumpTickets(
      tester,
      isGuest: false,
      repo: FakeBusRepository(ordersResult: [_pendingOrder()]),
    );

    expect(find.text('SuperJet'), findsOneWidget);
    expect(find.text('1 tickets'), findsOneWidget);
  });

  testWidgets('empty list shows the empty state with a Book a trip CTA',
      (tester) async {
    await _pumpTickets(
      tester,
      isGuest: false,
      repo: FakeBusRepository(ordersResult: const []),
    );

    expect(find.text('No tickets yet'), findsOneWidget);
    expect(find.text('Book a trip'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/tickets/tickets_screen_test.dart`
Expected: FAIL — compile error, `TicketsScreen` doesn't exist (and `bus_orders_section.dart` still references the not-yet-defined `PaymentFlowArgs`).

- [ ] **Step 3: Implement the screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/bus/presentation/providers/bus_orders_provider.dart';
import 'package:rego/features/bus/presentation/widgets/bus_orders_section.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/shell_tab_scroll_view.dart';
import 'package:rego/shared/widgets/skyline_tab_hero.dart';

/// Composition root for the "My Tickets" bottom-nav tab. Owns only the hero
/// and scroll scaffold — each transport mode contributes its own section
/// widget (currently just [BusOrdersSection]; flight/car add their own later
/// with no refactor here).
class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isGuest = ref.watch(guestModeProvider).value ?? false;
    // Guarded: guests never trigger the protected `busOrdersProvider` fetch,
    // even just to show a count in the hero.
    final count = isGuest ? null : ref.watch(busOrdersProvider).value?.length;

    return RefreshIndicator(
      onRefresh: isGuest
          ? () async {}
          : () => ref.read(busOrdersProvider.notifier).refresh(),
      child: ShellTabScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        hero: SkylineTabHero(
          child: SkylineTabHeroText(
            headline: l10n.navTickets,
            caption: count != null ? l10n.ticketsCountLabel(count) : null,
          ),
        ),
        children: const [BusOrdersSection()],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they still fail for the expected reason**

Run: `flutter test test/features/tickets/tickets_screen_test.dart`
Expected: FAIL — now only on the missing `PaymentFlowArgs` symbol in `bus_orders_section.dart`, not on `TicketsScreen`. Confirms this file is correctly written; full green comes after Task 12.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tickets/presentation/tickets_screen.dart test/features/tickets/tickets_screen_test.dart
git commit -m "feat(tickets): add TicketsScreen composition shell"
```

---

### Task 12: `PaymentFlowArgs` + resume-mode payment

**Files:**
- Modify: `lib/features/bus/presentation/payment_webview_screen.dart`
- Modify: `lib/features/bus/presentation/bus_routes.dart`

This unblocks compilation for `bus_orders_section.dart` (Task 10) and `TicketsScreen` (Task 11). `PaymentWebViewScreen` can't be widget-tested end-to-end in this codebase (see the notes at the top of this plan) — there's no new automated test here; correctness is verified by the full suite compiling/passing (Step 4) plus manual verification in Task 14.

- [ ] **Step 1: Add `PaymentFlowMode`/`PaymentFlowArgs` and thread them through the screen**

In `lib/features/bus/presentation/payment_webview_screen.dart`, add two imports at the top (alongside the existing ones):

```dart
import 'package:rego/features/bus/domain/entities/bus_search_params.dart';
import 'package:rego/features/bus/presentation/providers/bus_orders_provider.dart';
```

Then replace the `PaymentWebViewScreen` class declaration (currently just the widget + its state class start) — find this block:

```dart
class PaymentWebViewScreen extends ConsumerStatefulWidget {
  const PaymentWebViewScreen({super.key});

  @override
  ConsumerState<PaymentWebViewScreen> createState() =>
      _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends ConsumerState<PaymentWebViewScreen> {
  WebViewController? _controller;
  bool _loading = true;
  bool _verifyTriggered = false;
  bool _leavePromptOpen = false;
```

and replace it with:

```dart
enum PaymentFlowMode { booking, resume }

/// Arguments for opening the payment WebView outside the active booking flow
/// — i.e. "Complete payment" on a pending order in My Tickets. When absent,
/// the screen falls back to the booking flow's `busBookingProvider` exactly
/// as before.
class PaymentFlowArgs {
  const PaymentFlowArgs({
    required this.checkoutUrl,
    required this.orderId,
    this.mode = PaymentFlowMode.resume,
  });

  final String checkoutUrl;
  final String orderId;
  final PaymentFlowMode mode;
}

class PaymentWebViewScreen extends ConsumerStatefulWidget {
  const PaymentWebViewScreen({super.key, this.args});

  /// Set when resuming payment on an already-created order from My Tickets,
  /// rather than as part of an active `busBookingProvider` flow.
  final PaymentFlowArgs? args;

  @override
  ConsumerState<PaymentWebViewScreen> createState() =>
      _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends ConsumerState<PaymentWebViewScreen> {
  WebViewController? _controller;
  bool _loading = true;
  bool _verifyTriggered = false;
  bool _leavePromptOpen = false;
  bool _resumeVerifying = false;
```

- [ ] **Step 2: Read the checkout URL from `args` when present**

Find `Future<void> _init() async { ... }` and replace its first three lines:

```dart
  Future<void> _init() async {
    final ticket = ref.read(busBookingProvider).ticket;
    final paymentUrl = ticket?.paymentUrl ?? '';
```

with:

```dart
  Future<void> _init() async {
    final args = widget.args;
    final paymentUrl = args != null
        ? args.checkoutUrl
        : ref.read(busBookingProvider).ticket?.paymentUrl ?? '';
```

(the rest of `_init` — the `if (paymentUrl.isEmpty)` check onward — is unchanged)

- [ ] **Step 3: Branch `_verify` between booking and resume modes**

Replace the existing `_verify` method:

```dart
  Future<void> _verify() async {
    if (_verifyTriggered) return;
    _verifyTriggered = true;
    await ref.read(busBookingProvider.notifier).verifyPayment();
  }
```

with:

```dart
  Future<void> _verify() async {
    if (_verifyTriggered) return;
    _verifyTriggered = true;

    final args = widget.args;
    if (args == null) {
      await ref.read(busBookingProvider.notifier).verifyPayment();
      return;
    }
    await _verifyResume(args);
  }

  /// Resume-mode verification: reads the order's status directly (no
  /// `busBookingProvider` mutation), refreshes the My Tickets list so the
  /// card reflects the new status, then leaves this screen.
  Future<void> _verifyResume(PaymentFlowArgs args) async {
    if (mounted) setState(() => _resumeVerifying = true);
    var isConfirmed = false;
    try {
      final order = await ref.read(busRepositoryProvider).orderStatus(
            args.orderId,
            currency: BusCurrency.defaultCode,
          );
      isConfirmed = order.isConfirmed;
    } catch (_) {
      isConfirmed = false;
    }
    ref.invalidate(busOrdersProvider);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _resumeVerifying = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            isConfirmed
                ? l10n.ticketResumePaidToast
                : l10n.ticketResumePendingToast,
          ),
        ),
      );
    if (context.mounted) context.pop();
  }
```

- [ ] **Step 4: Branch navigation and the verifying-spinner flag in `build`**

Find, in `build()`:

```dart
    ref.listen<BusBookingState>(busBookingProvider, (prev, next) {
      if (next.status == BusBookingStatus.confirmed) {
        context.pushReplacement(BusRoutes.ticket);
      } else if (next.status == BusBookingStatus.paymentPending) {
        context.pushReplacement(BusRoutes.pending);
      }
    });

    final isVerifying = ref.watch(busBookingProvider).status ==
        BusBookingStatus.verifyingPayment;
```

and replace with:

```dart
    final isResume = widget.args != null;

    ref.listen<BusBookingState>(busBookingProvider, (prev, next) {
      if (isResume) return; // resume flow navigates itself in `_verifyResume`.
      if (next.status == BusBookingStatus.confirmed) {
        context.pushReplacement(BusRoutes.ticket);
      } else if (next.status == BusBookingStatus.paymentPending) {
        context.pushReplacement(BusRoutes.pending);
      }
    });

    final isVerifying = isResume
        ? _resumeVerifying
        : ref.watch(busBookingProvider).status ==
            BusBookingStatus.verifyingPayment;
```

(everything else in `build()` — the `PopScope`/`Scaffold`/`WebViewWidget` tree — is unchanged, since it already reads `isVerifying` and `_controller`/`_loading` generically)

- [ ] **Step 5: Thread `PaymentFlowArgs` through the route**

In `lib/features/bus/presentation/bus_routes.dart`, find:

```dart
      GoRoute(
        path: BusRoutes.pay,
        builder: (context, state) => const PaymentWebViewScreen(),
      ),
```

and replace with:

```dart
      GoRoute(
        path: BusRoutes.pay,
        builder: (context, state) {
          final extra = state.extra;
          return PaymentWebViewScreen(
            args: extra is PaymentFlowArgs ? extra : null,
          );
        },
      ),
```

- [ ] **Step 6: Confirm everything compiles and the full bus suite passes**

Run: `flutter analyze lib/features/bus lib/features/tickets && flutter test test/features/bus test/features/tickets`
Expected: `No issues found!` and all tests PASS — including the Task 10/11 tests that were failing on the missing `PaymentFlowArgs` symbol, and the pre-existing `payment_webview_screen_test.dart` (only tests `confirmLeavePayment`, unaffected by these changes) and `payment_nav_classify_test.dart`.

- [ ] **Step 7: Commit**

```bash
git add lib/features/bus/presentation/payment_webview_screen.dart lib/features/bus/presentation/bus_routes.dart
git commit -m "feat(bus): support resuming payment on a pending order from My Tickets"
```

---

### Task 13: Wire `/tickets` to `TicketsScreen`

**Files:**
- Modify: `lib/core/router/app_router.dart`
- Modify: `test/core/router/app_router_test.dart`

- [ ] **Step 1: Swap the route builder**

In `lib/core/router/app_router.dart`, add the import (alongside the other feature-screen imports):

```dart
import 'package:rego/features/tickets/presentation/tickets_screen.dart';
```

Find the tickets branch:

```dart
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.tickets,
                builder: (context, state) => ComingSoonScreen(
                  title: AppLocalizations.of(context).navTickets,
                  icon: AppIcons.ticket,
                ),
              ),
            ],
          ),
```

and replace with:

```dart
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.tickets,
                builder: (context, state) => const TicketsScreen(),
              ),
            ],
          ),
```

Leave the `wallet` branch's `ComingSoonScreen` usage untouched — `ComingSoonScreen` and `AppIcons` are both still needed there, so don't remove those imports.

- [ ] **Step 2: Add a router-level smoke test**

In `test/core/router/app_router_test.dart`, add this test inside `void main() { ... }`, after the existing `'guest can browse Home during the current session'` test:

```dart
  testWidgets(
    'guest can open the Tickets tab and sees a sign-in CTA, not a crash',
    (tester) async {
      await pumpApp(tester, testStorage());
      await continueAsGuest(tester);

      await tester.tap(find.text('Tickets'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in or create an account'), findsOneWidget);
    },
  );
```

This exercises the real `app_router.dart` wiring end-to-end (unlike `tickets_screen_test.dart`, which pumps `TicketsScreen` directly with overrides). It only covers the guest path — guests never call `busOrdersProvider`, so no real network/repository override is needed, matching how the file's other guest-flow tests work.

- [ ] **Step 3: Run the test to verify it fails first**

Run: `flutter test test/core/router/app_router_test.dart`
Expected: FAIL on the new test — `find.text('Sign in or create an account')` finds nothing (still shows the old Coming Soon screen).

- [ ] **Step 4: Confirm it passes after the route swap**

Run: `flutter test test/core/router/app_router_test.dart`
Expected: PASS — all tests in the file green, including the new one.

- [ ] **Step 5: Commit**

```bash
git add lib/core/router/app_router.dart test/core/router/app_router_test.dart
git commit -m "feat(tickets): wire /tickets tab to TicketsScreen"
```

---

### Task 14: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Full static analysis**

Run: `flutter analyze`
Expected: `No issues found!` across the whole project.

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: All tests PASS, including every file touched or added by Tasks 1–13.

- [ ] **Step 3: Manual verification in a running app**

Per `CLAUDE.md`, UI changes need to be exercised in a real running app, not just tests. Launch the app (`flutter run`, or the `/run` skill) and walk through:
1. As a guest: open the Tickets tab → see the sign-in card, not a crash or the old "Coming soon" screen.
2. Sign in with a test account that has at least one pending bus order → see it listed with the Pending badge, date, seats, total, and a "Complete payment" button.
3. Tap "Complete payment" → the payment WebView opens with the order's checkout URL loaded (not blank, not the booking-flow ticket screen).
4. Back out of the WebView via the leave-payment dialog → confirm it returns to the Tickets tab and the list still shows (order state unchanged if not actually paid).
5. If a confirmed order with an invoice is available: tap "Download" → an external browser/PDF viewer opens.
6. If a cancellable order is available: tap "Cancel" → confirm dialog → confirm → order disappears/updates status, with a success toast.
7. Pull down on the list → confirm the refresh spinner appears and the list re-fetches.
8. Switch to Arabic (via the profile language picker) → revisit the Tickets tab → confirm RTL layout, "تذاكري" headline, and translated statuses/actions.

Report back which of these were exercised and what was observed — if the backend has no seed data for a pending/confirmed/cancellable order to test against, say so explicitly rather than claiming full coverage.

- [ ] **Step 4: Final commit (only if Step 3 required code fixes)**

If manual verification surfaced a bug, fix it, re-run Steps 1–2, then:

```bash
git add -A
git commit -m "fix(tickets): address issues found in manual verification"
```

If no fixes were needed, there's nothing to commit here — Task 13's commit is the last one.
