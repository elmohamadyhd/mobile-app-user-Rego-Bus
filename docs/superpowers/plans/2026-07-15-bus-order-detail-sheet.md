# Bus Order Detail Sheet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tapping a `BusOrderCard` on the My Tickets tab opens a bottom sheet showing everything `GET /profile/buses/orders/:id` returns that the card doesn't already surface — per-seat prices, the full fare breakdown, payment metadata, and order/trip identifiers.

**Architecture:** Extend the existing `BusOrder` entity with the previously-unmapped fields (same JSON shape as the list endpoint), add one mapper function that serves both List and Show endpoints, and a `FutureProvider.family` that the sheet seeds from the tapped card's already-in-memory data while it silently refreshes via the `:id` endpoint underneath.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), Freezed, Dio — all existing project dependencies, no new packages.

**Spec:** `docs/superpowers/specs/2026-07-15-bus-order-detail-sheet-design.md`

---

## Before you start

Run `./tool/pub-get.ps1` (or `./tool/pub-get.sh`) once if you haven't already this session — **never** bare `flutter pub get` (see `tool/README.md`; it wipes an Android build patch).

Several early tasks intentionally leave the *rest* of the project non-compiling — e.g. after Task 1 changes `BusOrder`'s fields, `fake_bus_repository.dart` and four test files that still build the old shape will fail to compile. This is expected. Each task's own test commands are scoped to only the files that task touches, so they give a true signal in isolation (Dart/Flutter compiles each test file's own import graph, not the whole package). Task 2 fixes every other broken call site, and Task 10 runs the full suite at the end.

---

## Task 1: `BusOrderFare` entity + mapper (`orderFromJson`, `orderFromEnvelope`, `ticketLinesFromJson`)

**Files:**
- Modify: `lib/features/bus/domain/entities/bus_order.dart`
- Modify: `lib/features/bus/data/bus_dto_mapper.dart`
- Modify: `test/features/bus/data/bus_fixtures.dart`
- Modify: `test/features/bus/data/bus_dto_mapper_test.dart`

- [ ] **Step 1: Add the Show-endpoint fixtures**

In `test/features/bus/data/bus_fixtures.dart`, add these two constants at the end of the file (after `busOrdersEnvelope`'s closing `};`):

```dart

/// Real `GET /profile/buses/orders/:id` response for order 1475 — see
/// docs/wadeny-apis.md → Orders > Buses > Show. Field-for-field identical to
/// the matching element in `busOrdersEnvelope.data[]`, plus the fare
/// breakdown / payment / identifier fields the list fixture above omits.
const busOrderShowEnvelope = {
  'status': 200,
  'message': 'Bus order',
  'errors': <String, dynamic>{},
  'data': {
    'number': '000001475',
    'id': 1475,
    'trip_id': '145261',
    'gateway_order_id': '5077099',
    'parent_order_id': null,
    'company_data': {
      'name': 'SuperJet',
      'avatar': '',
      'bus_image': '',
      'pin': '',
    },
    'status': 'Pending',
    'status_code': 'pending',
    'gateway_id': 'SuperJet',
    'company_name': 'SuperJet',
    'category': 'Five stars',
    'can_be_cancel': true,
    'trip_type': 'Buses',
    'is_confirmed': 0,
    'review': null,
    'can_review': false,
    'payment_data': {
      'status': 'Pending',
      'status_code': 'pending',
      'invoice_id': 6956732,
      'gateway': 'Myfatoorah',
      'invoice_url': 'https://demo.MyFatoorah.com/KWT/ia/010726954',
      'data': {'notes': ''},
    },
    'invoice_url': 'https://portal.wdenytravel.com/orders/1475/invoice',
    'station_from': null,
    'station_to': null,
    'tickets': [
      {'id': 2076, 'seat_number': '1', 'price': '205.00'},
    ],
    'date': '2026-07-30',
    'date_time': '2026-07-30 08:45 AM',
    'payment_url': 'https://demo.safaria.travel/api/v1/buses/orders/1475/pay',
    'cancel_url':
        'https://demo.safaria.travel/api/v1/buses/orders/1475/cancel',
    'original_tickets_totals': 'EGP 205.00',
    'discount': 'EGP 0.00',
    'wallet_discount': 'EGP 0.00',
    'tickets_totals_after_discount': 'EGP 205.00',
    'payment_fees': 'EGP 14.35',
    'total': 'EGP 219.35',
    'currency': 'EGP',
  },
};

/// Real 404 for an unknown/foreign order id — docs/wadeny-apis.md → Orders >
/// Buses > Show. In production Dio throws before the mapper ever sees this
/// body (see `bus_api.dart` — no `validateStatus` override, so a real HTTP
/// 404 raises `DioException` first); this fixture exercises `orderFromEnvelope`
/// / `ensureSuccess`'s own defensive contract directly.
const busOrderNotFoundEnvelope = {
  'status': 404,
  'message': 'Bus order not found',
  'errors': <String, dynamic>{},
  'data': <String, dynamic>{},
};
```

- [ ] **Step 2: Write the new/updated mapper tests**

In `test/features/bus/data/bus_dto_mapper_test.dart`, add the import (after the existing `bus_order.dart` import):

```dart
import 'package:rego/core/network/api_exception.dart';
```

Replace the `seats` assertion in the existing `ordersFromEnvelope` test:

```dart
        expect(pending.seats, ['1']);
```

with:

```dart
        expect(pending.ticketLines, hasLength(1));
        expect(pending.ticketLines.first.seatNumber, '1');
```

Then add a new group right after the `ordersFromEnvelope` group (before `group('orderStatusKind', ...)`):

```dart
    group('orderFromEnvelope', () {
      test('maps the full Show response including fare, seats, and payment',
          () {
        final order = BusDtoMapper.orderFromEnvelope(busOrderShowEnvelope);

        expect(order.orderId, '1475');
        expect(order.bookingNumber, '000001475');
        expect(order.operatorName, 'SuperJet');
        expect(order.category, 'Five stars');
        expect(order.statusKind, BusOrderStatusKind.pending);
        expect(order.ticketLines, hasLength(1));
        expect(order.ticketLines.first.seatNumber, '1');
        expect(order.ticketLines.first.price, '205.00');
        expect(order.fare.originalTicketsTotal, 'EGP 205.00');
        expect(order.fare.discount, 'EGP 0.00');
        expect(order.fare.walletDiscount, 'EGP 0.00');
        expect(order.fare.ticketsTotalAfterDiscount, 'EGP 205.00');
        expect(order.fare.paymentFees, 'EGP 14.35');
        expect(order.fare.total, 'EGP 219.35');
        expect(order.fare.currency, 'EGP');
        expect(order.paymentGateway, 'Myfatoorah');
        expect(order.paymentStatusText, 'Pending');
        expect(order.paymentInvoiceId, '6956732');
        expect(order.tripId, '145261');
        expect(order.gatewayOrderId, '5077099');
        expect(order.tripType, 'Buses');
      });

      test('throws ApiException for the documented not-found envelope', () {
        expect(
          () => BusDtoMapper.orderFromEnvelope(busOrderNotFoundEnvelope),
          throwsA(isA<ApiException>()),
        );
      });
    });
```

- [ ] **Step 3: Run the mapper tests and confirm they fail**

Run: `flutter test test/features/bus/data/bus_dto_mapper_test.dart`
Expected: FAIL to compile — `orderFromEnvelope` isn't defined, `BusOrder` has no `ticketLines`/`fare`/`paymentGateway`/etc. constructor parameters.

- [ ] **Step 4: Add `BusOrderFare` and extend `BusOrder`**

Replace the full contents of `lib/features/bus/domain/entities/bus_order.dart` with:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';

part 'bus_order.freezed.dart';

/// Derived from `status_code` + `is_confirmed` on a bus order (see
/// [BusDtoMapper.orderStatusKind]). Backend vocabulary beyond `pending` is
/// inferred, not documented — unrecognized codes render as [unknown] rather
/// than being guessed into a destructive/positive bucket.
enum BusOrderStatusKind { pending, confirmed, cancelled, unknown }

/// The fare breakdown carried by every bus order (List and Show endpoints
/// return the same fields). All money fields are preformatted strings (e.g.
/// `"EGP 205.00"`), matching every other money field in this codebase — no
/// numeric parsing, no new currency-formatting logic.
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

/// One booked bus trip from `GET /profile/buses/orders` (list) or
/// `GET /profile/buses/orders/:id` (show) — both endpoints return this same
/// shape, mapped by the same `BusDtoMapper.orderFromJson`. Distinct from
/// [BusTicket] (the post-booking confirmation entity) and `BusOrderStatus`
/// (the payment-verify result).
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
    String? pickupStopLabel,
    String? dropoffStopLabel,
    required List<BusTicketLine> ticketLines,
    required String total,
    required bool canCancel,
    String? gatewayCheckoutUrl,
    String? invoiceUrl,
    required BusOrderFare fare,
    String? paymentGateway,
    String? paymentStatusText,
    String? paymentInvoiceId,
    String? tripId,
    String? gatewayOrderId,
    String? tripType,
  }) = _BusOrder;
}
```

Note: `total` (used by `BusOrderCard`) and `fare.total` (used by the detail sheet's breakdown) intentionally hold the same value — kept both because the card only needs one flat field, while the sheet's fare breakdown reads it as part of the grouped `fare` object.

- [ ] **Step 5: Regenerate Freezed code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes with `bus_order.freezed.dart` regenerated (it's gitignored — never edit it by hand).

- [ ] **Step 6: Update the mapper**

In `lib/features/bus/data/bus_dto_mapper.dart`, insert a new shared helper right before `static BusTicket ticketFromEnvelope({`:

```dart
  static List<BusTicketLine> ticketLinesFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map((t) {
      return BusTicketLine(
        id: _int(t['id']) ?? 0,
        seatNumber: _string(t['seat_number']) ?? '',
        price: _string(t['price']) ?? '0',
      );
    }).toList();
  }

```

Then, inside `ticketFromEnvelope`, replace:

```dart
    final ticketsRaw = data['tickets'];
    final lines = ticketsRaw is List
        ? ticketsRaw.whereType<Map<String, dynamic>>().map((t) {
            return BusTicketLine(
              id: _int(t['id']) ?? 0,
              seatNumber: _string(t['seat_number']) ?? '',
              price: _string(t['price']) ?? '0',
            );
          }).toList()
        : <BusTicketLine>[];
```

with:

```dart
    final lines = ticketLinesFromJson(data['tickets']);
```

Then replace the whole `ordersFromEnvelope` + `orderFromJson` block:

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

    final pickupStopLabel = _stationName(json['station_from']);
    final dropoffStopLabel = _stationName(json['station_to']);

    return BusOrder(
      orderId: _string(json['id']) ?? '',
      bookingNumber: _string(json['number']) ?? '',
      operatorName: _string(json['company_name']) ?? companyName ?? '',
      operatorLogoUrl: logo,
      category: _string(json['category']) ?? '',
      statusText: _string(json['status']) ?? '',
      statusKind: orderStatusKind(statusCode, isConfirmedFlag),
      dateTimeLabel: _string(json['date_time']) ?? _string(json['date']) ?? '',
      pickupStopLabel: pickupStopLabel,
      dropoffStopLabel: dropoffStopLabel,
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
```

with:

```dart
  static List<BusOrder> ordersFromEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    ensureSuccess(envelope);
    final data = envelope['data'];
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().map(orderFromJson).toList();
  }

  /// Maps `GET /profile/buses/orders/:id` — the Show endpoint returns the
  /// exact same object shape as one element of the List endpoint's `data[]`,
  /// so this delegates to the same [orderFromJson] used by
  /// [ordersFromEnvelope].
  static BusOrder orderFromEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    ensureSuccess(envelope);
    final data = envelope['data'];
    if (data is Map<String, dynamic>) return orderFromJson(data);
    return orderFromJson(const <String, dynamic>{});
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

    final paymentData = json['payment_data'];
    String? gatewayCheckoutUrl;
    String? paymentGateway;
    String? paymentStatusText;
    String? paymentInvoiceId;
    if (paymentData is Map<String, dynamic>) {
      gatewayCheckoutUrl = _string(paymentData['invoice_url']);
      paymentGateway = _string(paymentData['gateway']);
      paymentStatusText = _string(paymentData['status']);
      paymentInvoiceId = _string(paymentData['invoice_id']);
    }

    final pickupStopLabel = _stationName(json['station_from']);
    final dropoffStopLabel = _stationName(json['station_to']);

    return BusOrder(
      orderId: _string(json['id']) ?? '',
      bookingNumber: _string(json['number']) ?? '',
      operatorName: _string(json['company_name']) ?? companyName ?? '',
      operatorLogoUrl: logo,
      category: _string(json['category']) ?? '',
      statusText: _string(json['status']) ?? '',
      statusKind: orderStatusKind(statusCode, isConfirmedFlag),
      dateTimeLabel: _string(json['date_time']) ?? _string(json['date']) ?? '',
      pickupStopLabel: pickupStopLabel,
      dropoffStopLabel: dropoffStopLabel,
      ticketLines: ticketLinesFromJson(json['tickets']),
      total: _string(json['total']) ?? '',
      canCancel: json['can_be_cancel'] == true,
      gatewayCheckoutUrl:
          (gatewayCheckoutUrl != null && gatewayCheckoutUrl.isNotEmpty)
              ? gatewayCheckoutUrl
              : null,
      invoiceUrl: _string(json['invoice_url']),
      fare: BusOrderFare(
        originalTicketsTotal: _string(json['original_tickets_totals']) ?? '',
        discount: _string(json['discount']) ?? '',
        walletDiscount: _string(json['wallet_discount']) ?? '',
        ticketsTotalAfterDiscount:
            _string(json['tickets_totals_after_discount']) ?? '',
        paymentFees: _string(json['payment_fees']) ?? '',
        total: _string(json['total']) ?? '',
        currency: _string(json['currency']) ?? '',
      ),
      paymentGateway: paymentGateway,
      paymentStatusText: paymentStatusText,
      paymentInvoiceId: paymentInvoiceId,
      tripId: _string(json['trip_id']),
      gatewayOrderId: _string(json['gateway_order_id']),
      tripType: _string(json['trip_type']),
    );
  }
```

- [ ] **Step 7: Run the mapper tests and confirm they pass**

Run: `flutter test test/features/bus/data/bus_dto_mapper_test.dart`
Expected: PASS — all tests green, including the two new `orderFromEnvelope` tests.

- [ ] **Step 8: Commit**

```bash
git add lib/features/bus/domain/entities/bus_order.dart lib/features/bus/domain/entities/bus_order.freezed.dart lib/features/bus/data/bus_dto_mapper.dart test/features/bus/data/bus_fixtures.dart test/features/bus/data/bus_dto_mapper_test.dart
git commit -m "feat(bus): map fare breakdown and payment fields on BusOrder

Extends BusOrder with the previously-unmapped fields the Wadeny API
already returns (fare breakdown, per-seat prices via ticketLines,
payment metadata, trip identifiers) and adds orderFromEnvelope for
GET /profile/buses/orders/:id, which shares orderFromJson with the
list endpoint since both return the identical shape."
```

---

## Task 2: Fix call sites broken by the `BusOrder` shape change

**Files:**
- Modify: `test/features/bus/fake_bus_repository.dart`
- Modify: `test/features/bus/presentation/widgets/bus_order_card_test.dart`
- Modify: `test/features/bus/presentation/bus_orders_section_test.dart`
- Modify: `test/features/bus/presentation/bus_orders_notifier_test.dart`
- Modify: `test/features/tickets/tickets_screen_test.dart`

- [ ] **Step 1: Confirm the breakage**

Run: `flutter test test/features/bus/presentation/ test/features/tickets/`
Expected: FAIL to compile — every file below still constructs `BusOrder(seats: [...])` without the now-required `fare:` argument.

- [ ] **Step 2: Fix `bus_order_card_test.dart`**

Add this import right after the existing `bus_order.dart` import:

```dart
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';
```

Replace:

```dart
    pickupStopLabel: pickupStopLabel,
    dropoffStopLabel: dropoffStopLabel,
    seats: const ['1', '2'],
    total: 'EGP 219.35',
    canCancel: canCancel,
    gatewayCheckoutUrl: gatewayCheckoutUrl,
    invoiceUrl: invoiceUrl,
  );
}
```

with:

```dart
    pickupStopLabel: pickupStopLabel,
    dropoffStopLabel: dropoffStopLabel,
    ticketLines: const [
      BusTicketLine(id: 2076, seatNumber: '1', price: '110.00'),
      BusTicketLine(id: 2077, seatNumber: '2', price: '109.35'),
    ],
    total: 'EGP 219.35',
    canCancel: canCancel,
    gatewayCheckoutUrl: gatewayCheckoutUrl,
    invoiceUrl: invoiceUrl,
    fare: const BusOrderFare(
      originalTicketsTotal: 'EGP 205.00',
      discount: 'EGP 0.00',
      walletDiscount: 'EGP 0.00',
      ticketsTotalAfterDiscount: 'EGP 205.00',
      paymentFees: 'EGP 14.35',
      total: 'EGP 219.35',
      currency: 'EGP',
    ),
  );
}
```

- [ ] **Step 3: Fix `bus_orders_section_test.dart`**

Add this import right after the existing `bus_order.dart` import:

```dart
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';
```

Replace:

```dart
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
```

with:

```dart
BusOrder _order() => const BusOrder(
      orderId: '1475',
      bookingNumber: '000001475',
      operatorName: 'SuperJet',
      category: 'Five stars',
      statusText: 'Pending',
      statusKind: BusOrderStatusKind.pending,
      dateTimeLabel: '2026-07-30 08:45 AM',
      ticketLines: [BusTicketLine(id: 2076, seatNumber: '1', price: '205.00')],
      total: 'EGP 219.35',
      canCancel: true,
      gatewayCheckoutUrl: 'https://demo.MyFatoorah.com/pay',
      invoiceUrl: 'https://portal.wdenytravel.com/orders/1475/invoice',
      fare: BusOrderFare(
        originalTicketsTotal: 'EGP 205.00',
        discount: 'EGP 0.00',
        walletDiscount: 'EGP 0.00',
        ticketsTotalAfterDiscount: 'EGP 205.00',
        paymentFees: 'EGP 14.35',
        total: 'EGP 219.35',
        currency: 'EGP',
      ),
    );
```

- [ ] **Step 4: Fix `bus_orders_notifier_test.dart`**

Add this import right after the existing `bus_order.dart` import:

```dart
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';
```

Replace:

```dart
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
```

with:

```dart
  return BusOrder(
    orderId: orderId,
    bookingNumber: '000001475',
    operatorName: 'SuperJet',
    category: 'Five stars',
    statusText: 'Pending',
    statusKind: statusKind,
    dateTimeLabel: '2026-07-30 08:45 AM',
    ticketLines: const [
      BusTicketLine(id: 2076, seatNumber: '1', price: '205.00'),
    ],
    total: 'EGP 219.35',
    canCancel: canCancel,
    gatewayCheckoutUrl: 'https://demo.MyFatoorah.com/pay',
    invoiceUrl: 'https://portal.wdenytravel.com/orders/1475/invoice',
    fare: const BusOrderFare(
      originalTicketsTotal: 'EGP 205.00',
      discount: 'EGP 0.00',
      walletDiscount: 'EGP 0.00',
      ticketsTotalAfterDiscount: 'EGP 205.00',
      paymentFees: 'EGP 14.35',
      total: 'EGP 219.35',
      currency: 'EGP',
    ),
  );
}
```

- [ ] **Step 5: Fix `tickets_screen_test.dart`**

Add this import right after the existing `bus_order.dart` import:

```dart
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';
```

Replace:

```dart
BusOrder _pendingOrder() => const BusOrder(
      orderId: '1475',
      bookingNumber: '000001475',
      operatorName: 'SuperJet',
      category: 'Five stars',
      statusText: 'Pending',
      statusKind: BusOrderStatusKind.pending,
      dateTimeLabel: '2026-07-30 08:45 AM',
      pickupStopLabel: 'Cairo Main Station',
      dropoffStopLabel: 'Alexandria Terminal',
      seats: ['1'],
      total: 'EGP 219.35',
      canCancel: true,
      gatewayCheckoutUrl: 'https://demo.MyFatoorah.com/pay',
      invoiceUrl: 'https://portal.wdenytravel.com/orders/1475/invoice',
    );
```

with:

```dart
BusOrder _pendingOrder() => const BusOrder(
      orderId: '1475',
      bookingNumber: '000001475',
      operatorName: 'SuperJet',
      category: 'Five stars',
      statusText: 'Pending',
      statusKind: BusOrderStatusKind.pending,
      dateTimeLabel: '2026-07-30 08:45 AM',
      pickupStopLabel: 'Cairo Main Station',
      dropoffStopLabel: 'Alexandria Terminal',
      ticketLines: [BusTicketLine(id: 2076, seatNumber: '1', price: '205.00')],
      total: 'EGP 219.35',
      canCancel: true,
      gatewayCheckoutUrl: 'https://demo.MyFatoorah.com/pay',
      invoiceUrl: 'https://portal.wdenytravel.com/orders/1475/invoice',
      fare: BusOrderFare(
        originalTicketsTotal: 'EGP 205.00',
        discount: 'EGP 0.00',
        walletDiscount: 'EGP 0.00',
        ticketsTotalAfterDiscount: 'EGP 205.00',
        paymentFees: 'EGP 14.35',
        total: 'EGP 219.35',
        currency: 'EGP',
      ),
    );
```

- [ ] **Step 6: Fix `fake_bus_repository.dart`**

This file implements `BusRepository` and will fail to compile once Task 4 adds `orderById` to the interface — add it now so both changes land together conceptually, even though the interface method itself is added in Task 4. Add `import 'dart:async';` as the first line, then add fields to the constructor and class body.

Replace:

```dart
class FakeBusRepository implements BusRepository {
  FakeBusRepository({
    this.tripsPage,
    this.tripByIdResult,
    this.seatMapResult,
    this.ticketResult,
    this.orderStatusResult,
    this.ordersResult,
  });

  BusTripsPage? tripsPage;
  BusTripSummary? tripByIdResult;
  SeatMap? seatMapResult;
  BusTicket? ticketResult;
  BusOrderStatus? orderStatusResult;
  List<BusLocation>? locationsResult;
  int createTicketCallCount = 0;
  List<BusOrder>? ordersResult;
  int listOrdersCallCount = 0;
  bool listOrdersShouldThrow = false;
  List<String> cancelOrderCalls = [];
  bool cancelOrderShouldThrow = false;
```

with:

```dart
class FakeBusRepository implements BusRepository {
  FakeBusRepository({
    this.tripsPage,
    this.tripByIdResult,
    this.seatMapResult,
    this.ticketResult,
    this.orderStatusResult,
    this.ordersResult,
    this.orderByIdResult,
  });

  BusTripsPage? tripsPage;
  BusTripSummary? tripByIdResult;
  SeatMap? seatMapResult;
  BusTicket? ticketResult;
  BusOrderStatus? orderStatusResult;
  List<BusLocation>? locationsResult;
  int createTicketCallCount = 0;
  List<BusOrder>? ordersResult;
  int listOrdersCallCount = 0;
  bool listOrdersShouldThrow = false;
  List<String> cancelOrderCalls = [];
  bool cancelOrderShouldThrow = false;
  BusOrder? orderByIdResult;
  Completer<BusOrder>? orderByIdCompleter;
  bool orderByIdShouldThrow = false;
  List<String> orderByIdCalls = [];
```

Then add the new method right after `cancelOrder`'s closing brace:

```dart

  @override
  Future<BusOrder> orderById(String orderId) async {
    orderByIdCalls.add(orderId);
    if (orderByIdCompleter != null) return orderByIdCompleter!.future;
    if (orderByIdShouldThrow) {
      throw const ApiException('Order not found', statusCode: 404);
    }
    return orderByIdResult ?? sampleOrder;
  }
```

Then add a `sampleOrder` default next to the existing `sampleTrip`/`sampleSeatMap` statics, right after `sampleTrip`'s closing `);`:

```dart

  static const sampleOrder = BusOrder(
    orderId: '1475',
    bookingNumber: '000001475',
    operatorName: 'SuperJet',
    category: 'Five stars',
    statusText: 'Pending',
    statusKind: BusOrderStatusKind.pending,
    dateTimeLabel: '2026-07-30 08:45 AM',
    pickupStopLabel: 'Cairo Main Station',
    dropoffStopLabel: 'Alexandria Terminal',
    ticketLines: [BusTicketLine(id: 2076, seatNumber: '1', price: '205.00')],
    total: 'EGP 219.35',
    canCancel: true,
    gatewayCheckoutUrl: 'https://demo.MyFatoorah.com/pay',
    invoiceUrl: 'https://portal.wdenytravel.com/orders/1475/invoice',
    fare: BusOrderFare(
      originalTicketsTotal: 'EGP 205.00',
      discount: 'EGP 0.00',
      walletDiscount: 'EGP 0.00',
      ticketsTotalAfterDiscount: 'EGP 205.00',
      paymentFees: 'EGP 14.35',
      total: 'EGP 219.35',
      currency: 'EGP',
    ),
    paymentGateway: 'Myfatoorah',
    paymentStatusText: 'Pending',
    paymentInvoiceId: '6956732',
    tripId: '145261',
    gatewayOrderId: '5077099',
    tripType: 'Buses',
  );
```

This won't compile yet — `BusRepository.orderById` doesn't exist on the interface until Task 4. That's expected; Task 4 makes this file compile again.

- [ ] **Step 7: Commit**

```bash
git add test/features/bus/fake_bus_repository.dart test/features/bus/presentation/widgets/bus_order_card_test.dart test/features/bus/presentation/bus_orders_section_test.dart test/features/bus/presentation/bus_orders_notifier_test.dart test/features/tickets/tickets_screen_test.dart
git commit -m "test(bus): migrate BusOrder test fixtures to ticketLines/fare

Follow-up to the BusOrder shape change: every test that constructed
a BusOrder now supplies ticketLines instead of the removed seats
field, plus the newly-required fare breakdown."
```

(This commit still won't leave the project fully compiling — `fake_bus_repository.dart`'s new `orderById` override references `BusRepository.orderById`, which lands in Task 4. Task 4's own commit is what restores a clean `flutter analyze`.)

---

## Task 3: Localization keys

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ar.arb`

- [ ] **Step 1: Add English keys**

In `lib/l10n/app_en.arb`, find this line:

```json
  "ticketResumePendingToast": "We couldn't confirm the payment yet. It may take a moment.",
```

Insert immediately after it (before the blank line that precedes `"paymentTitle"`):

```json
  "ticketResumePendingToast": "We couldn't confirm the payment yet. It may take a moment.",

  "orderDetailTitle": "Order details",
  "orderDetailRouteSection": "Route",
  "orderDetailFareSection": "Fare breakdown",
  "orderDetailSubtotal": "Subtotal",
  "orderDetailDiscount": "Discount",
  "orderDetailWalletDiscount": "Wallet discount",
  "orderDetailAfterDiscount": "Total after discount",
  "orderDetailFees": "Payment fees",
  "orderDetailSeatLabel": "Seat {number}",
  "@orderDetailSeatLabel": {
    "description": "Per-seat price row label in the order detail sheet.",
    "placeholders": {
      "number": {
        "type": "String"
      }
    }
  },
  "orderDetailPaymentProvider": "Payment provider",
  "orderDetailPaymentStatus": "Payment status",
  "orderDetailInvoiceId": "Invoice ID",
  "orderDetailReferenceSection": "Reference details",
  "orderDetailTripId": "Trip ID",
  "orderDetailGatewayOrderId": "Gateway order ID",
  "orderDetailTripType": "Trip type",
```

- [ ] **Step 2: Add Arabic keys**

In `lib/l10n/app_ar.arb`, find this line:

```json
  "ticketResumePendingToast": "لم نتمكن من تأكيد الدفع بعد، قد يستغرق الأمر بعض الوقت.",
```

Insert immediately after it (before the blank line that precedes `"paymentTitle"`):

```json
  "ticketResumePendingToast": "لم نتمكن من تأكيد الدفع بعد، قد يستغرق الأمر بعض الوقت.",

  "orderDetailTitle": "تفاصيل الطلب",
  "orderDetailRouteSection": "المسار",
  "orderDetailFareSection": "تفاصيل السعر",
  "orderDetailSubtotal": "الإجمالي قبل الخصم",
  "orderDetailDiscount": "الخصم",
  "orderDetailWalletDiscount": "خصم المحفظة",
  "orderDetailAfterDiscount": "الإجمالي بعد الخصم",
  "orderDetailFees": "رسوم الدفع",
  "orderDetailSeatLabel": "مقعد {number}",
  "orderDetailPaymentProvider": "مزوّد الدفع",
  "orderDetailPaymentStatus": "حالة الدفع",
  "orderDetailInvoiceId": "رقم الفاتورة",
  "orderDetailReferenceSection": "تفاصيل مرجعية",
  "orderDetailTripId": "رقم الرحلة",
  "orderDetailGatewayOrderId": "رقم طلب البوابة",
  "orderDetailTripType": "نوع الرحلة",
```

- [ ] **Step 3: Regenerate localization code**

Run: `flutter gen-l10n`
Expected: completes with no errors; `lib/l10n/app_localizations.dart` (gitignored) now has `orderDetailTitle`, `orderDetailSeatLabel(String number)`, etc.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "feat(l10n): add order detail sheet strings"
```

---

## Task 4: `BusApi.orderById` + `BusRepository.orderById`

**Files:**
- Modify: `lib/features/bus/data/bus_api.dart`
- Modify: `lib/features/bus/domain/repositories/bus_repository.dart`
- Modify: `lib/features/bus/data/bus_repository_impl.dart`

This layer has no dedicated unit tests anywhere in the codebase today (`BusApi` and `BusRepositoryImpl` are thin Dio/mapper pass-throughs, exercised indirectly through `FakeBusRepository` in widget/provider tests) — this task follows that existing convention rather than introducing new Dio-mocking test infrastructure.

- [ ] **Step 1: Add `BusApi.orderById`**

In `lib/features/bus/data/bus_api.dart`, add this method right after `listOrders()`:

```dart

  Future<dynamic> orderById(String orderId) async {
    final res = await _dio.get('/profile/buses/orders/$orderId');
    return res.data;
  }
```

- [ ] **Step 2: Add `orderById` to the `BusRepository` interface**

In `lib/features/bus/domain/repositories/bus_repository.dart`, add this method right after `listOrders()`'s declaration (`Future<List<BusOrder>> listOrders();`):

```dart

  /// Fetches a single order by id (My Tickets detail sheet). Returns the
  /// same shape as one element of [listOrders] — see
  /// `BusDtoMapper.orderFromJson`.
  Future<BusOrder> orderById(String orderId);
```

- [ ] **Step 3: Implement it in `BusRepositoryImpl`**

In `lib/features/bus/data/bus_repository_impl.dart`, add this method right after `listOrders()`'s implementation:

```dart

  @override
  Future<BusOrder> orderById(String orderId) {
    return _guard(() async {
      final body = await _api.orderById(orderId);
      return BusDtoMapper.orderFromEnvelope(body);
    });
  }
```

- [ ] **Step 4: Confirm the whole bus feature compiles again**

Run: `flutter analyze lib/features/bus test/features/bus test/features/tickets`
Expected: `No issues found!` — this is the point where `fake_bus_repository.dart`'s `orderById` override (added in Task 2) finally satisfies the interface.

- [ ] **Step 5: Run the bus and tickets test suites**

Run: `flutter test test/features/bus test/features/tickets`
Expected: PASS — every test fixed in Task 2 is green now that the interface exists.

- [ ] **Step 6: Commit**

```bash
git add lib/features/bus/data/bus_api.dart lib/features/bus/domain/repositories/bus_repository.dart lib/features/bus/data/bus_repository_impl.dart
git commit -m "feat(bus): add BusRepository.orderById for GET /profile/buses/orders/:id"
```

---

## Task 5: `busOrderDetailProvider`

**Files:**
- Modify: `lib/features/bus/presentation/providers/bus_orders_provider.dart`
- Create: `test/features/bus/presentation/bus_order_detail_provider_test.dart`

- [ ] **Step 1: Write the failing provider test**

Create `test/features/bus/presentation/bus_order_detail_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/providers/bus_orders_provider.dart';

import '../fake_bus_repository.dart';

void main() {
  ProviderContainer makeContainer(FakeBusRepository repo) {
    final container = ProviderContainer(
      overrides: [busRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('busOrderDetailProvider', () {
    test('fetches the order by id from the repository', () async {
      final repo = FakeBusRepository(
        orderByIdResult: FakeBusRepository.sampleOrder,
      );
      final container = makeContainer(repo);

      final order =
          await container.read(busOrderDetailProvider('1475').future);

      expect(order.orderId, '1475');
      expect(repo.orderByIdCalls, ['1475']);
    });

    test('surfaces a repository failure as a provider error', () async {
      final repo = FakeBusRepository()..orderByIdShouldThrow = true;
      final container = makeContainer(repo);

      await expectLater(
        container.read(busOrderDetailProvider('1475').future),
        throwsA(anything),
      );
    });
  });
}
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/features/bus/presentation/bus_order_detail_provider_test.dart`
Expected: FAIL to compile — `busOrderDetailProvider` isn't defined.

- [ ] **Step 3: Add the provider**

In `lib/features/bus/presentation/providers/bus_orders_provider.dart`, add this right after the existing `busOrdersProvider` declaration (at the end of the file):

```dart

/// Fetches one order by id for the order detail sheet. `autoDispose` because
/// it's sheet-scoped (unlike the tab-lifetime `busOrdersProvider`) — closing
/// the sheet frees it, and reopening always re-fetches fresh.
final busOrderDetailProvider =
    FutureProvider.autoDispose.family<BusOrder, String>(
  (ref, orderId) => ref.read(busRepositoryProvider).orderById(orderId),
);
```

- [ ] **Step 4: Run the test and confirm it passes**

Run: `flutter test test/features/bus/presentation/bus_order_detail_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bus/presentation/providers/bus_orders_provider.dart test/features/bus/presentation/bus_order_detail_provider_test.dart
git commit -m "feat(bus): add busOrderDetailProvider"
```

---

## Task 6: Extract `OrderInfoRow`

**Files:**
- Create: `lib/features/bus/presentation/widgets/order_info_row.dart`
- Modify: `lib/features/bus/presentation/widgets/bus_order_card.dart`

**Purpose:** `BusOrderCard` has a private `_InfoRow` widget that the detail sheet (Task 8) also needs. Promote it to a shared widget first, with a pure rename, before either file changes behavior — keeps this diff reviewable on its own.

- [ ] **Step 1: Create the shared widget**

Create `lib/features/bus/presentation/widgets/order_info_row.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/shared/widgets/ltr_text.dart';

/// Label/value row shared by [BusOrderCard] and the order detail sheet:
/// label on the leading edge, value on the trailing edge. [valueLtr] forces
/// LTR layout for money/reference values inside RTL text. [emphasized] bumps
/// the value to `title` weight for total-style rows.
class OrderInfoRow extends StatelessWidget {
  const OrderInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueLtr = false,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool valueLtr;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final baseStyle = emphasized ? AppTypography.title : AppTypography.body;
    final valueStyle = baseStyle.copyWith(
      color: AppColors.textPrimary,
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: valueLtr
                ? LtrText(value, style: valueStyle, textAlign: TextAlign.end)
                : Text(
                    value,
                    textAlign: TextAlign.end,
                    style: valueStyle,
                  ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Use it from `BusOrderCard`**

In `lib/features/bus/presentation/widgets/bus_order_card.dart`, add the import (after the `order_status_badge.dart` import):

```dart
import 'package:rego/features/bus/presentation/widgets/order_info_row.dart';
```

Replace every `_InfoRow(` call with `OrderInfoRow(` (4 occurrences, inside the `build` method). Then delete the entire `_InfoRow` class definition (the block starting `class _InfoRow extends StatelessWidget {` through its closing `}`, right before `class _OrderActions extends StatelessWidget {`).

- [ ] **Step 3: Run the card test and confirm it still passes**

Run: `flutter test test/features/bus/presentation/widgets/bus_order_card_test.dart`
Expected: PASS — pure rename, no behavior change.

- [ ] **Step 4: Commit**

```bash
git add lib/features/bus/presentation/widgets/order_info_row.dart lib/features/bus/presentation/widgets/bus_order_card.dart
git commit -m "refactor(bus): extract OrderInfoRow from BusOrderCard

Pure extraction, no behavior change — the order detail sheet
(next commit) needs the same label/value row."
```

---

## Task 7: `BusOrderCard` — tappable card opens the detail sheet

**Files:**
- Modify: `lib/features/bus/presentation/widgets/bus_order_card.dart`
- Modify: `test/features/bus/presentation/widgets/bus_order_card_test.dart`

- [ ] **Step 1: Write the failing tests**

In `test/features/bus/presentation/widgets/bus_order_card_test.dart`, update `_pumpCard` — replace:

```dart
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
```

with:

```dart
Future<void> _pumpCard(
  WidgetTester tester,
  BusOrder order, {
  VoidCallback? onTap,
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
          onTap: onTap ?? () {},
          onPay: onPay ?? () {},
          onOpenETicket: onOpenETicket ?? () {},
          onCancel: onCancel ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
```

Then add two new tests at the end of `main()`, right before its closing `}`:

```dart

  testWidgets('tapping the card body invokes onTap', (tester) async {
    var tapped = 0;
    await _pumpCard(tester, _order(), onTap: () => tapped++);

    await tester.tap(find.text('SuperJet'));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('tapping Complete payment does not also invoke onTap',
      (tester) async {
    var cardTapped = 0;
    var payTapped = 0;
    await _pumpCard(
      tester,
      _order(),
      onTap: () => cardTapped++,
      onPay: () => payTapped++,
    );

    await tester.tap(find.text('Complete payment'));
    await tester.pump();
    expect(payTapped, 1);
    expect(cardTapped, 0);
  });
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/bus/presentation/widgets/bus_order_card_test.dart`
Expected: FAIL to compile — `BusOrderCard` has no `onTap` parameter yet.

- [ ] **Step 3: Add `onTap` to `BusOrderCard`**

In `lib/features/bus/presentation/widgets/bus_order_card.dart`, replace the constructor and fields:

```dart
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
```

with:

```dart
  const BusOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    required this.onPay,
    required this.onOpenETicket,
    required this.onCancel,
  });

  final BusOrder order;
  final VoidCallback onTap;
  final VoidCallback onPay;
  final VoidCallback onOpenETicket;
  final VoidCallback onCancel;
```

Then wrap the card's `Column` in an `InkWell`. Replace:

```dart
      child: Material(
        color: AppColors.bgCard,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
```

with:

```dart
      child: Material(
        color: AppColors.bgCard,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
```

And replace the matching closing tail:

```dart
                  child: _OrderActions(
                    order: order,
                    onPay: onPay,
                    onOpenETicket: onOpenETicket,
                    onCancel: onCancel,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
```

with:

```dart
                  child: _OrderActions(
                    order: order,
                    onPay: onPay,
                    onOpenETicket: onOpenETicket,
                    onCancel: onCancel,
                  ),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
```

The indentation is intentionally off after this edit (the `InkWell` wrapper was inserted without reflowing everything beneath it) — that's fixed in the next step.

- [ ] **Step 4: Reformat**

Run: `dart format lib/features/bus/presentation/widgets/bus_order_card.dart`
Expected: reports 1 file changed — indentation now consistent.

- [ ] **Step 5: Run the card tests and confirm they pass**

Run: `flutter test test/features/bus/presentation/widgets/bus_order_card_test.dart`
Expected: PASS, including the two new tests.

- [ ] **Step 6: `BusOrderCard` now has a required `onTap` its only current caller doesn't supply**

`lib/features/bus/presentation/widgets/bus_orders_section.dart`'s `_OrdersList` constructs `BusOrderCard` without `onTap` — this won't compile until Task 9. Confirm that's the *only* remaining break:

Run: `flutter analyze lib/features/bus`
Expected: exactly one error, in `bus_orders_section.dart`, about a missing `onTap` argument.

- [ ] **Step 7: Commit**

```bash
git add lib/features/bus/presentation/widgets/bus_order_card.dart test/features/bus/presentation/widgets/bus_order_card_test.dart
git commit -m "feat(bus): make BusOrderCard tappable via a new onTap callback

The card's action buttons (pay/e-ticket/cancel) keep their own tap
targets and do not also trigger onTap — covered by a dedicated test."
```

---

## Task 8: `BusOrderDetailSheet`

**Files:**
- Create: `lib/features/bus/presentation/widgets/bus_order_detail_sheet.dart`
- Create: `test/features/bus/presentation/widgets/bus_order_detail_sheet_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/features/bus/presentation/widgets/bus_order_detail_sheet_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/widgets/bus_order_detail_sheet.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../../fake_bus_repository.dart';

BusOrder _seedOrder() => const BusOrder(
      orderId: '1475',
      bookingNumber: '000001475',
      operatorName: 'SuperJet',
      category: 'Five stars',
      statusText: 'Pending',
      statusKind: BusOrderStatusKind.pending,
      dateTimeLabel: '2026-07-30 08:45 AM',
      pickupStopLabel: 'Cairo Main Station',
      dropoffStopLabel: 'Alexandria Terminal',
      ticketLines: [BusTicketLine(id: 2076, seatNumber: '1', price: '205.00')],
      total: 'EGP 219.35',
      canCancel: true,
      gatewayCheckoutUrl: 'https://demo.MyFatoorah.com/pay',
      invoiceUrl: 'https://portal.wdenytravel.com/orders/1475/invoice',
      fare: BusOrderFare(
        originalTicketsTotal: 'EGP 205.00',
        discount: 'EGP 0.00',
        walletDiscount: 'EGP 0.00',
        ticketsTotalAfterDiscount: 'EGP 205.00',
        paymentFees: 'EGP 14.35',
        total: 'EGP 219.35',
        currency: 'EGP',
      ),
      paymentGateway: 'Myfatoorah',
      paymentStatusText: 'Pending',
      paymentInvoiceId: '6956732',
      tripId: '145261',
      gatewayOrderId: '5077099',
      tripType: 'Buses',
    );

Future<void> _pumpSheet(
  WidgetTester tester, {
  required FakeBusRepository repo,
  BusOrder? seed,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [busRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () =>
                  showBusOrderDetailSheet(context, seed ?? _seedOrder()),
              child: const Text('Open sheet'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open sheet'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('paints the seed immediately with no spinner', (tester) async {
    final repo = FakeBusRepository()
      ..orderByIdCompleter = Completer<BusOrder>();
    await _pumpSheet(tester, repo: repo);

    expect(find.text('SuperJet'), findsOneWidget);
    expect(find.text('EGP 219.35'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('replaces seed once the refresh call resolves', (tester) async {
    final completer = Completer<BusOrder>();
    final repo = FakeBusRepository()..orderByIdCompleter = completer;
    await _pumpSheet(tester, repo: repo);

    completer.complete(
      _seedOrder().copyWith(statusKind: BusOrderStatusKind.confirmed),
    );
    await tester.pumpAndSettle();

    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('keeps the seed when the refresh call fails', (tester) async {
    final repo = FakeBusRepository()..orderByIdShouldThrow = true;
    await _pumpSheet(tester, repo: repo);
    await tester.pumpAndSettle();

    expect(find.text('SuperJet'), findsOneWidget);
    expect(find.text('EGP 219.35'), findsWidgets);
  });

  testWidgets('hides zero-value discount rows', (tester) async {
    final repo = FakeBusRepository()
      ..orderByIdCompleter = Completer<BusOrder>();
    await _pumpSheet(tester, repo: repo);

    expect(find.text('Discount'), findsNothing);
    expect(find.text('Wallet discount'), findsNothing);
  });

  testWidgets('shows non-zero discount rows', (tester) async {
    final seed = _seedOrder().copyWith(
      fare: const BusOrderFare(
        originalTicketsTotal: 'EGP 250.00',
        discount: 'EGP 12.00',
        walletDiscount: 'EGP 5.00',
        ticketsTotalAfterDiscount: 'EGP 233.00',
        paymentFees: 'EGP 14.35',
        total: 'EGP 247.35',
        currency: 'EGP',
      ),
    );
    final repo = FakeBusRepository()
      ..orderByIdCompleter = Completer<BusOrder>();
    await _pumpSheet(tester, repo: repo, seed: seed);

    expect(find.text('Discount'), findsOneWidget);
    expect(find.text('EGP 12.00'), findsOneWidget);
    expect(find.text('Wallet discount'), findsOneWidget);
    expect(find.text('EGP 5.00'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/bus/presentation/widgets/bus_order_detail_sheet_test.dart`
Expected: FAIL to compile — `bus_order_detail_sheet.dart` doesn't exist yet.

- [ ] **Step 3: Create the sheet**

Create `lib/features/bus/presentation/widgets/bus_order_detail_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/presentation/providers/bus_orders_provider.dart';
import 'package:rego/features/bus/presentation/widgets/operator_mark.dart';
import 'package:rego/features/bus/presentation/widgets/order_info_row.dart';
import 'package:rego/features/bus/presentation/widgets/order_status_badge.dart';
import 'package:rego/l10n/app_localizations.dart';

/// Opens the order-detail sheet, seeded instantly from [order] (the row
/// already in memory from the My Tickets list) while `GET
/// /profile/buses/orders/:id` refreshes it in the background — see
/// `docs/superpowers/specs/2026-07-15-bus-order-detail-sheet-design.md`.
Future<void> showBusOrderDetailSheet(BuildContext context, BusOrder order) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (context) => _BusOrderDetailSheet(seed: order),
  );
}

bool _hasLabel(String? value) => value != null && value.trim().isNotEmpty;

bool _hasPaymentInfo(BusOrder order) =>
    _hasLabel(order.paymentGateway) ||
    _hasLabel(order.paymentStatusText) ||
    _hasLabel(order.paymentInvoiceId);

bool _hasReferenceInfo(BusOrder order) =>
    _hasLabel(order.bookingNumber) ||
    _hasLabel(order.tripId) ||
    _hasLabel(order.gatewayOrderId) ||
    _hasLabel(order.tripType);

class _BusOrderDetailSheet extends ConsumerWidget {
  const _BusOrderDetailSheet({required this.seed});

  final BusOrder seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final order =
        ref.watch(busOrderDetailProvider(seed.orderId)).value ?? seed;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final hasRoute = _hasLabel(order.pickupStopLabel) ||
        _hasLabel(order.dropoffStopLabel) ||
        order.dateTimeLabel.trim().isNotEmpty;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.orderDetailTitle,
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.close),
                    color: AppColors.textMuted,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.hairline, height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeaderSection(order: order),
                    if (hasRoute) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _RouteSection(order: order, l10n: l10n),
                    ],
                    if (order.ticketLines.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _SeatsSection(order: order, l10n: l10n),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _FareSection(order: order, l10n: l10n),
                    if (_hasPaymentInfo(order)) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _PaymentSection(order: order, l10n: l10n),
                    ],
                    if (_hasReferenceInfo(order)) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _ReferenceSection(order: order, l10n: l10n),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.order});

  final BusOrder order;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        OperatorMark(name: order.operatorName, logoUrl: order.operatorLogoUrl),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.operatorName,
                style: AppTypography.title.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (order.category.trim().isNotEmpty)
                Text(
                  order.category,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        OrderStatusBadge(statusKind: order.statusKind),
      ],
    );
  }
}

class _RouteSection extends StatelessWidget {
  const _RouteSection({required this.order, required this.l10n});

  final BusOrder order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void addRow(String label, String? value) {
      if (!_hasLabel(value)) return;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.xs));
      rows.add(OrderInfoRow(label: label, value: value!));
    }

    addRow(l10n.eTicketFrom, order.pickupStopLabel);
    addRow(l10n.eTicketTo, order.dropoffStopLabel);
    if (order.dateTimeLabel.trim().isNotEmpty) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.xs));
      rows.add(
        OrderInfoRow(label: l10n.eTicketDate, value: order.dateTimeLabel),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.orderDetailRouteSection),
        ...rows,
      ],
    );
  }
}

class _SeatsSection extends StatelessWidget {
  const _SeatsSection({required this.order, required this.l10n});

  final BusOrder order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final lines = order.ticketLines;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.eTicketSeats),
        for (var i = 0; i < lines.length; i++) ...[
          OrderInfoRow(
            label: l10n.orderDetailSeatLabel(lines[i].seatNumber),
            value: lines[i].price,
            valueLtr: true,
          ),
          if (i != lines.length - 1) const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _FareSection extends StatelessWidget {
  const _FareSection({required this.order, required this.l10n});

  final BusOrder order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final fare = order.fare;
    final rows = <Widget>[
      OrderInfoRow(
        label: l10n.orderDetailSubtotal,
        value: fare.originalTicketsTotal,
        valueLtr: true,
      ),
    ];
    if (!_isZeroAmount(fare.discount)) {
      rows.add(const SizedBox(height: AppSpacing.xs));
      rows.add(
        OrderInfoRow(
          label: l10n.orderDetailDiscount,
          value: fare.discount,
          valueLtr: true,
        ),
      );
    }
    if (!_isZeroAmount(fare.walletDiscount)) {
      rows.add(const SizedBox(height: AppSpacing.xs));
      rows.add(
        OrderInfoRow(
          label: l10n.orderDetailWalletDiscount,
          value: fare.walletDiscount,
          valueLtr: true,
        ),
      );
    }
    rows.addAll([
      const SizedBox(height: AppSpacing.xs),
      OrderInfoRow(
        label: l10n.orderDetailAfterDiscount,
        value: fare.ticketsTotalAfterDiscount,
        valueLtr: true,
      ),
      const SizedBox(height: AppSpacing.xs),
      OrderInfoRow(
        label: l10n.orderDetailFees,
        value: fare.paymentFees,
        valueLtr: true,
      ),
      const SizedBox(height: AppSpacing.sm),
      const Divider(color: AppColors.hairline, height: 1),
      const SizedBox(height: AppSpacing.sm),
      OrderInfoRow(
        label: l10n.confirmTotal,
        value: fare.total,
        valueLtr: true,
        emphasized: true,
      ),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.orderDetailFareSection),
        ...rows,
      ],
    );
  }

  static bool _isZeroAmount(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9.]'), '');
    if (digits.isEmpty) return false;
    final parsed = double.tryParse(digits);
    if (parsed == null) return false;
    return parsed == 0;
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({required this.order, required this.l10n});

  final BusOrder order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void addRow(String label, String? value) {
      if (!_hasLabel(value)) return;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.xs));
      rows.add(OrderInfoRow(label: label, value: value!, valueLtr: true));
    }

    addRow(l10n.orderDetailPaymentProvider, order.paymentGateway);
    addRow(l10n.orderDetailPaymentStatus, order.paymentStatusText);
    addRow(l10n.orderDetailInvoiceId, order.paymentInvoiceId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.paymentTitle),
        ...rows,
      ],
    );
  }
}

class _ReferenceSection extends StatelessWidget {
  const _ReferenceSection({required this.order, required this.l10n});

  final BusOrder order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void addRow(String label, String? value) {
      if (!_hasLabel(value)) return;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.xs));
      rows.add(OrderInfoRow(label: label, value: value!, valueLtr: true));
    }

    addRow(l10n.eTicketRef, order.bookingNumber);
    addRow(l10n.orderDetailTripId, order.tripId);
    addRow(l10n.orderDetailGatewayOrderId, order.gatewayOrderId);
    addRow(l10n.orderDetailTripType, order.tripType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.orderDetailReferenceSection),
        ...rows,
      ],
    );
  }
}
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test test/features/bus/presentation/widgets/bus_order_detail_sheet_test.dart`
Expected: PASS — all 5 tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bus/presentation/widgets/bus_order_detail_sheet.dart test/features/bus/presentation/widgets/bus_order_detail_sheet_test.dart
git commit -m "feat(bus): add BusOrderDetailSheet

Bottom sheet seeded instantly from the tapped card's BusOrder while
GET /profile/buses/orders/:id refreshes it silently underneath — no
loading spinner, seed stays put if the refresh fails. Not yet wired
to BusOrderCard's onTap (next commit)."
```

---

## Task 9: Wire the sheet into `BusOrdersSection`

**Files:**
- Modify: `lib/features/bus/presentation/widgets/bus_orders_section.dart`

- [ ] **Step 1: Add the import and wire `onTap`**

In `lib/features/bus/presentation/widgets/bus_orders_section.dart`, add this import (after the `bus_order_card.dart` import):

```dart
import 'package:rego/features/bus/presentation/widgets/bus_order_detail_sheet.dart';
```

Replace:

```dart
        for (final order in orders)
          BusOrderCard(
            order: order,
            onPay: () => context.push(
```

with:

```dart
        for (final order in orders)
          BusOrderCard(
            order: order,
            onTap: () => showBusOrderDetailSheet(context, order),
            onPay: () => context.push(
```

- [ ] **Step 2: Confirm the whole bus feature compiles**

Run: `flutter analyze lib/features/bus`
Expected: `No issues found!`

- [ ] **Step 3: Run the section test**

Run: `flutter test test/features/bus/presentation/bus_orders_section_test.dart`
Expected: PASS — existing tests don't exercise `onTap`, so this is a compile-fix-only change from their perspective.

- [ ] **Step 4: Commit**

```bash
git add lib/features/bus/presentation/widgets/bus_orders_section.dart
git commit -m "feat(bus): open the order detail sheet from My Tickets

Tapping a BusOrderCard now opens BusOrderDetailSheet, seeded from
the tapped card's already-loaded BusOrder."
```

---

## Task 10: Full-suite verification

**Files:** none (verification only)

- [ ] **Step 1: Static analysis**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: all tests pass, 0 failures.

- [ ] **Step 3: Manual verification in a running app**

Per this project's CLAUDE.md, use the `/run` skill (or `flutter run`) to launch the app, sign in, open the My Tickets tab, and tap a bus order card. Confirm:
- The sheet opens instantly showing the card's data (no spinner).
- Seats show individual prices; the fare breakdown shows subtotal → fees → total, with any zero-value discount rows hidden.
- Payment and reference sections show gateway/status/ids when present.
- Tapping "Complete payment" / the e-ticket download / cancel on the card itself does **not** also open the sheet.
- The sheet's close button and swipe-down both dismiss it.
- Test in Arabic (RTL) too — money values (`valueLtr: true` rows) should stay left-to-right inside the RTL layout, matching how the card already renders totals.

- [ ] **Step 4: Report**

Summarize pass/fail for each of the above. If manual verification isn't possible in this environment, say so explicitly rather than claiming the feature works end-to-end — `flutter analyze` and `flutter test` verify correctness, not that the sheet actually looks and feels right.
