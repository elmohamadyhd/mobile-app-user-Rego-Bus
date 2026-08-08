# Flight Order and Payment Implementation Plan (Phase 4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn a filled-in booking into a paid ticket, and make an unpaid one resumable.

**Architecture:** Order creation closes the offer id relay — the id from adding passengers is the last hop. Payment reuses the bus WebView pattern unchanged, including its pure navigation classifier. The one genuinely unknown thing, which status values mean "ticketed", is confined to a single predicate so the answer is a two-line change rather than a rewrite of three screens.

**Tech Stack:** Flutter, Riverpod (`Notifier`), Freezed, Dio, `webview_flutter`, go_router, ARB codegen.

**Scope:** Phase 4 of [`2026-08-08-flight-booking-screens-design.md`](../specs/2026-08-08-flight-booking-screens-design.md) — the last phase. Ends when a rider can pay and see their ticket, and find an unpaid booking again in My Tickets.

**Depends on:** Phase 3, merged.

---

## What is still unknown

Open question 1 in the flow spec: which `order_status` / `payment_status` values mean ticketed. Every saved sample shows an unpaid order (`PendingPayment` / `pending`), so the paid state has never been observed.

Unlike the spikes that opened Phases 2 and 3, **this one does not block the build**. Task 3 defines the predicate with the safest possible reading — treat as paid only on an explicitly known-paid signal, and route everything else to the pending screen. A booking wrongly shown as pending is a support call; a booking wrongly shown as ticketed is a rider at an airport without a seat.

Task 9 verifies it for real. Do the rest of the plan first.

> The same gap already exists in the bus flow — see the `project-bus-payment-order-status-gap` note. Whatever Task 9 establishes should be checked against bus's predicate too, though changing bus is out of scope here.

---

## File Structure

**Create:**

| File | Responsibility |
|------|----------------|
| `lib/features/flight/domain/entities/flight_settings.dart` | Booking currency and gateway |
| `lib/features/flight/domain/entities/flight_order.dart` | A created order, its transaction and passengers |
| `lib/features/flight/domain/utils/flight_order_status.dart` | The paid predicate — pure |
| `lib/features/flight/presentation/flight_pay_screen.dart` | Step 4: final review and order creation |
| `lib/features/flight/presentation/flight_payment_webview_screen.dart` | Hosted checkout |
| `lib/features/flight/presentation/flight_pending_screen.dart` | Unpaid outcome |
| `lib/features/flight/presentation/flight_ticket_screen.dart` | Paid outcome |
| `lib/features/flight/presentation/providers/flight_orders_provider.dart` | My Tickets list and detail |

**Modify:**

| File | Change |
|------|--------|
| `lib/features/flight/data/flight_api.dart` | `settings`, order list and detail |
| `lib/features/flight/data/flight_dto_mapper.dart` | Settings and orders |
| `lib/features/flight/domain/repositories/flight_repository.dart` | Four new methods |
| `lib/features/flight/data/flight_repository_impl.dart` | Their implementations |
| `lib/features/flight/presentation/providers/flight_booking_providers.dart` | Order creation |
| `lib/features/flight/presentation/flight_routes.dart` | Four new routes |
| `lib/features/flight/presentation/flight_passengers_screen.dart` | Continue reaches pay |
| `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` | New strings |

---

## Task 1: Settings

**Files:**
- Create: `lib/features/flight/domain/entities/flight_settings.dart`
- Modify: `flight_api.dart`, `flight_dto_mapper.dart`, `flight_repository.dart`, `flight_repository_impl.dart`
- Test: `test/features/flight/data/flight_settings_mapper_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/data/flight_dto_mapper.dart';

void main() {
  test('reads the booking currency and gateway', () {
    final settings = FlightDtoMapper.settingsFromEnvelope({
      'status': 200,
      'data': {
        'default_booking_currency': 'EGP',
        'payment_gateway': 'myfatoorah',
      },
    });
    expect(settings.bookingCurrency, 'EGP');
    expect(settings.paymentGateway, 'myfatoorah');
  });

  test('falls back to EGP when the field is missing', () {
    final settings = FlightDtoMapper.settingsFromEnvelope({'data': {}});
    expect(settings.bookingCurrency, 'EGP');
  });

  test('a malformed envelope yields defaults rather than throwing', () {
    expect(FlightDtoMapper.settingsFromEnvelope(null).bookingCurrency, 'EGP');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight/data/flight_settings_mapper_test.dart`
Expected: FAIL — `settingsFromEnvelope` is not defined.

- [ ] **Step 3: Write the entity, call, and mapper**

Create `lib/features/flight/domain/entities/flight_settings.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'flight_settings.freezed.dart';

/// The slice of `GET /settings` the booking flow needs.
///
/// There is one gateway and one booking currency, so neither is presented as
/// a choice — no payment-method picker, no currency picker.
@freezed
abstract class FlightSettings with _$FlightSettings {
  const factory FlightSettings({
    @Default('EGP') String bookingCurrency,
    @Default('') String paymentGateway,
  }) = _FlightSettings;
}
```

Add to `flight_api.dart`:

```dart
  /// `GET /settings` — booking currency and the single payment gateway.
  Future<dynamic> settings() async {
    final res = await _dio.get('/settings');
    return res.data;
  }
```

Add to `flight_dto_mapper.dart`:

```dart
  /// Defaults to EGP rather than failing: a missing currency should not stop
  /// a rider booking, and EGP is the only value the backend has ever sent.
  static FlightSettings settingsFromEnvelope(dynamic body) {
    final data = body is Map ? body['data'] : null;
    if (data is! Map) return const FlightSettings();
    return FlightSettings(
      bookingCurrency: _string(data['default_booking_currency']) ?? 'EGP',
      paymentGateway: _string(data['payment_gateway']) ?? '',
    );
  }
```

Add to the repository interface and implementation:

```dart
  Future<FlightSettings> settings();
```

```dart
  @override
  Future<FlightSettings> settings() {
    return _guard(() async {
      final body = await _api.settings();
      return FlightDtoMapper.settingsFromEnvelope(body);
    });
  }
```

- [ ] **Step 4: Add the provider**

In `flight_booking_providers.dart`:

```dart
/// Settings are static for a session; the pay screen reads the currency from
/// here rather than hardcoding it.
final flightSettingsProvider = FutureProvider<FlightSettings>((ref) {
  return ref.watch(flightRepositoryProvider).settings();
});
```

- [ ] **Step 5: Run codegen and the test**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/features/flight/data/flight_settings_mapper_test.dart`
Expected: PASS — 3 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/features/flight test/features/flight/data/flight_settings_mapper_test.dart
git commit -m "Read Booking Currency And Gateway From Settings"
```

---

## Task 2: The order entity and mapper

**Files:**
- Create: `lib/features/flight/domain/entities/flight_order.dart`
- Modify: `flight_dto_mapper.dart`
- Test: `test/features/flight/data/flight_order_mapper_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/data/flight_dto_mapper.dart';

const _envelope = {
  'status': 200,
  'message': 'Booking pending payment',
  'data': {
    'id': 76,
    'provider': 'flywt',
    'airline_pnr': null,
    'offer_id': 'OFFER_D',
    'status': 'pending',
    'order_status': 'PendingPayment',
    'total_amount': 13048.86,
    'currency': 'EGP',
    'passengers': [
      {
        'id': 81,
        'passenger_type_code': 'ADT',
        'first_name': 'Ahmed',
        'last_name': 'Mostafa',
      },
    ],
    'segments': [
      {
        'id': 105,
        'origin': 'CAI',
        'destination': 'MED',
        'departure_datetime': '2026-08-30T16:30:00+03:00',
        'arrival_datetime': '2026-08-30T18:20:00+03:00',
        'marketing_carrier_code': 'XY',
        'marketing_flight_number': '575',
      },
    ],
    'transaction': {
      'id': 120,
      'gateway': 'myfatoorah',
      'status': 'pending',
      'paid_at': null,
      'invoice_url': 'https://eg.myfatoorah.com/EGY/ia/050714540828552362',
    },
    'can_be_cancel': true,
    'invoice_url': 'https://demo.safaria.travel/flight-orders/76/invoice',
  },
};

void main() {
  test('maps the order header', () {
    final order = FlightDtoMapper.orderFromEnvelope(_envelope)!;
    expect(order.id, '76');
    expect(order.orderStatus, 'PendingPayment');
    expect(order.totalAmount, 13048.86);
    expect(order.currency, 'EGP');
    expect(order.airlinePnr, isNull);
  });

  test('checkoutUrl is the transaction invoice, not the receipt', () {
    final order = FlightDtoMapper.orderFromEnvelope(_envelope)!;
    expect(order.checkoutUrl, contains('myfatoorah.com'));
    expect(order.receiptUrl, contains('safaria.travel'));
  });

  test('maps passengers and segments', () {
    final order = FlightDtoMapper.orderFromEnvelope(_envelope)!;
    expect(order.passengers.single.firstName, 'Ahmed');
    expect(order.segments.single.marketingFlightNumber, '575');
  });

  test('an envelope with no data maps to null', () {
    expect(FlightDtoMapper.orderFromEnvelope({'data': null}), isNull);
  });

  test('a list envelope maps every order', () {
    final orders = FlightDtoMapper.ordersFromEnvelope({
      'data': [_envelope['data'], _envelope['data']],
    });
    expect(orders, hasLength(2));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight/data/flight_order_mapper_test.dart`
Expected: FAIL — `orderFromEnvelope` is not defined.

- [ ] **Step 3: Write the entity**

Create `lib/features/flight/domain/entities/flight_order.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'flight_order.freezed.dart';

@freezed
abstract class FlightOrderPassenger with _$FlightOrderPassenger {
  const factory FlightOrderPassenger({
    required String id,
    required String passengerTypeCode,
    String? firstName,
    String? lastName,
  }) = _FlightOrderPassenger;
}

@freezed
abstract class FlightOrderSegment with _$FlightOrderSegment {
  const factory FlightOrderSegment({
    required String id,
    required String origin,
    required String destination,
    DateTime? departureDateTime,
    DateTime? arrivalDateTime,
    String? marketingCarrierCode,
    String? marketingFlightNumber,
  }) = _FlightOrderSegment;
}

/// A created flight order.
///
/// [checkoutUrl] is the gateway's hosted payment page. It comes from
/// `transaction.invoice_url` — **not** the top-level `invoice_url`, which is
/// a receipt on the REGO site and will not take a payment.
@freezed
abstract class FlightOrder with _$FlightOrder {
  const factory FlightOrder({
    required String id,
    required String status,
    required String orderStatus,
    String? paymentStatus,
    String? airlinePnr,
    String? gdsPnr,
    DateTime? paidAt,
    required double totalAmount,
    required String currency,
    String? checkoutUrl,
    String? receiptUrl,
    @Default(false) bool canBeCancelled,
    @Default([]) List<FlightOrderPassenger> passengers,
    @Default([]) List<FlightOrderSegment> segments,
  }) = _FlightOrder;
}
```

- [ ] **Step 4: Write the mapper**

Add to `flight_dto_mapper.dart`:

```dart
  static List<FlightOrder> ordersFromEnvelope(dynamic body) {
    final data = body is Map ? body['data'] : null;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(_orderFromJson)
        .toList(growable: false);
  }

  static FlightOrder? orderFromEnvelope(dynamic body) {
    final data = body is Map ? body['data'] : null;
    return data is Map ? _orderFromJson(data) : null;
  }

  static FlightOrder _orderFromJson(Map json) {
    final transaction = json['transaction'];
    final passengers = json['passengers'];
    final segments = json['segments'];

    return FlightOrder(
      id: _string(json['id']) ?? '',
      status: _string(json['status']) ?? '',
      orderStatus: _string(json['order_status']) ?? '',
      paymentStatus: transaction is Map
          ? _string(transaction['status'])
          : _string(json['payment_status']),
      airlinePnr: _string(json['airline_pnr']),
      gdsPnr: _string(json['gds_pnr']),
      paidAt: transaction is Map ? _dateTime(transaction['paid_at']) : null,
      totalAmount: _double(json['total_amount']) ?? 0,
      currency: _string(json['currency']) ?? 'EGP',
      checkoutUrl:
          transaction is Map ? _string(transaction['invoice_url']) : null,
      receiptUrl: _string(json['invoice_url']),
      canBeCancelled: json['can_be_cancel'] == true,
      passengers: passengers is List
          ? passengers.whereType<Map>().map(_orderPassengerFromJson).toList()
          : const [],
      segments: segments is List
          ? segments.whereType<Map>().map(_orderSegmentFromJson).toList()
          : const [],
    );
  }

  static FlightOrderPassenger _orderPassengerFromJson(Map json) {
    return FlightOrderPassenger(
      id: _string(json['id']) ?? '',
      passengerTypeCode: _string(json['passenger_type_code']) ?? 'ADT',
      firstName: _string(json['first_name']),
      lastName: _string(json['last_name']),
    );
  }

  static FlightOrderSegment _orderSegmentFromJson(Map json) {
    return FlightOrderSegment(
      id: _string(json['id']) ?? '',
      origin: _string(json['origin']) ?? '',
      destination: _string(json['destination']) ?? '',
      departureDateTime: _dateTime(json['departure_datetime']),
      arrivalDateTime: _dateTime(json['arrival_datetime']),
      marketingCarrierCode: _string(json['marketing_carrier_code']),
      marketingFlightNumber: _string(json['marketing_flight_number']),
    );
  }
```

If the mapper has no `_dateTime` helper yet, add one beside `_double`:

```dart
  static DateTime? _dateTime(dynamic v) {
    final raw = _string(v);
    return raw == null ? null : DateTime.tryParse(raw);
  }
```

- [ ] **Step 5: Run codegen and the test**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/features/flight/data/flight_order_mapper_test.dart`
Expected: PASS — 5 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/features/flight test/features/flight/data/flight_order_mapper_test.dart
git commit -m "Map Flight Orders And Their Checkout Url"
```

---

## Task 3: The paid predicate

The one unknown in this phase, isolated so the answer costs two lines.

**Files:**
- Create: `lib/features/flight/domain/utils/flight_order_status.dart`
- Test: `test/features/flight/domain/flight_order_status_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_order.dart';
import 'package:safaria/features/flight/domain/utils/flight_order_status.dart';

FlightOrder _order({
  String status = 'pending',
  String orderStatus = 'PendingPayment',
  String? paymentStatus = 'pending',
  String? airlinePnr,
  DateTime? paidAt,
}) {
  return FlightOrder(
    id: '76',
    status: status,
    orderStatus: orderStatus,
    paymentStatus: paymentStatus,
    airlinePnr: airlinePnr,
    paidAt: paidAt,
    totalAmount: 100,
    currency: 'EGP',
  );
}

void main() {
  test('the documented unpaid shape is not paid', () {
    expect(isFlightOrderPaid(_order()), isFalse);
  });

  test('a paid transaction timestamp counts as paid', () {
    expect(isFlightOrderPaid(_order(paidAt: DateTime(2026, 8, 30))), isTrue);
  });

  test('an airline PNR counts as paid', () {
    expect(isFlightOrderPaid(_order(airlinePnr: 'ABC123')), isTrue);
  });

  test('a known paid status counts as paid', () {
    expect(isFlightOrderPaid(_order(paymentStatus: 'paid')), isTrue);
    expect(isFlightOrderPaid(_order(orderStatus: 'Confirmed')), isTrue);
    expect(isFlightOrderPaid(_order(orderStatus: 'Ticketed')), isTrue);
  });

  test('an unrecognised status is treated as unpaid', () {
    expect(isFlightOrderPaid(_order(orderStatus: 'SomethingNew')), isFalse);
  });

  test('case does not matter', () {
    expect(isFlightOrderPaid(_order(paymentStatus: 'PAID')), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight/domain/flight_order_status_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Write the predicate**

Create `lib/features/flight/domain/utils/flight_order_status.dart`:

```dart
import 'package:safaria/features/flight/domain/entities/flight_order.dart';

/// Status values the backend is known to use for a completed payment.
///
/// This list is provisional — no paid order has been observed yet (open
/// question 1 in the flow spec). Phase 4 Task 9 replaces it with the real
/// set.
const _paidOrderStatuses = {'confirmed', 'ticketed', 'completed', 'paid'};
const _paidPaymentStatuses = {'paid', 'success', 'successful', 'completed'};

/// Whether [order] has actually been paid for.
///
/// Deliberately conservative: anything not positively recognised as paid is
/// treated as unpaid. Showing a paid booking as pending costs a support call;
/// showing an unpaid one as ticketed puts a rider at an airport without a
/// seat.
///
/// The strongest signals come first — a settlement timestamp or a PNR issued
/// by the airline are facts, whereas the status strings are vocabulary that
/// can change.
bool isFlightOrderPaid(FlightOrder order) {
  if (order.paidAt != null) return true;
  if ((order.airlinePnr ?? '').trim().isNotEmpty) return true;
  if ((order.gdsPnr ?? '').trim().isNotEmpty) return true;
  if (_paidPaymentStatuses.contains(
    (order.paymentStatus ?? '').trim().toLowerCase(),
  )) {
    return true;
  }
  return _paidOrderStatuses.contains(order.orderStatus.trim().toLowerCase());
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/flight/domain/flight_order_status_test.dart`
Expected: PASS — 6 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/flight/domain/utils/flight_order_status.dart test/features/flight/domain/flight_order_status_test.dart
git commit -m "Isolate The Flight Order Paid Test"
```

---

## Task 4: Create the order

**Files:**
- Modify: `flight_dto_mapper.dart`, `flight_repository.dart`, `flight_repository_impl.dart`
- Modify: `flight_booking_providers.dart`
- Test: `test/features/flight/data/flight_order_body_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/data/flight_dto_mapper.dart';

void main() {
  test('sends the chosen bundle per leg', () {
    final body = FlightDtoMapper.createOrderBody(
      selectedBundleCodes: {'journey-1': 'RCAI', 'journey-2': 'FCAI'},
      currency: 'EGP',
    );
    expect(body['selectedBundles'], [
      {'journeyKey': 'journey-1', 'selectedBundleCode': 'RCAI'},
      {'journeyKey': 'journey-2', 'selectedBundleCode': 'FCAI'},
    ]);
    expect(body['currency'], 'EGP');
  });

  test('an offer with no bundles sends an empty array, not a missing key', () {
    final body = FlightDtoMapper.createOrderBody(
      selectedBundleCodes: const {},
      currency: 'EGP',
    );
    expect(body['selectedBundles'], isEmpty);
    expect(body.containsKey('selectedBundles'), isTrue);
  });

  test('this endpoint spells currency correctly, unlike search', () {
    final body = FlightDtoMapper.createOrderBody(
      selectedBundleCodes: const {},
      currency: 'EGP',
    );
    expect(body.containsKey('currency'), isTrue);
    expect(body.containsKey('curreny'), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight/data/flight_order_body_test.dart`
Expected: FAIL — `createOrderBody` is not defined.

- [ ] **Step 3: Write the body builder**

Add to `flight_dto_mapper.dart`:

```dart
  /// Builds the `POST /flights/{offer_id}` body that creates the order.
  ///
  /// An offer without bundles sends `selectedBundles: []` — confirmed by
  /// product. Do not omit the key.
  ///
  /// Note this endpoint takes `currency` spelled correctly, while
  /// `POST /flights/search` takes `curreny`. The two genuinely disagree.
  static Map<String, dynamic> createOrderBody({
    required Map<String, String> selectedBundleCodes,
    required String currency,
  }) {
    return {
      'selectedBundles': [
        for (final entry in selectedBundleCodes.entries)
          {'journeyKey': entry.key, 'selectedBundleCode': entry.value},
      ],
      'currency': currency,
    };
  }
```

- [ ] **Step 4: Add the repository method**

Interface:

```dart
  /// Creates the order. [offerId] must be the id returned by
  /// [addPassengers] — the last hop of the relay.
  Future<FlightOrder> createOrder({
    required String offerId,
    required Map<String, String> selectedBundleCodes,
    required String currency,
  });

  Future<List<FlightOrder>> orders();

  Future<FlightOrder?> order(String id);
```

Implementation:

```dart
  @override
  Future<FlightOrder> createOrder({
    required String offerId,
    required Map<String, String> selectedBundleCodes,
    required String currency,
  }) {
    return _guard(() async {
      final body = await _api.pending(
        offerId: offerId,
        body: FlightDtoMapper.createOrderBody(
          selectedBundleCodes: selectedBundleCodes,
          currency: currency,
        ),
      );
      final order = FlightDtoMapper.orderFromEnvelope(body);
      if (order == null) {
        throw const ApiException(
          'The booking was not created. Please try again.',
        );
      }
      return order;
    });
  }

  @override
  Future<List<FlightOrder>> orders() {
    return _guard(() async {
      final body = await _api.orders();
      return FlightDtoMapper.ordersFromEnvelope(body);
    });
  }

  @override
  Future<FlightOrder?> order(String id) {
    return _guard(() async {
      final body = await _api.order(id);
      return FlightDtoMapper.orderFromEnvelope(body);
    });
  }
```

Add the two profile calls to `flight_api.dart`:

```dart
  /// `GET /profile/flights/orders`
  Future<dynamic> orders() async {
    final res = await _dio.get('/profile/flights/orders');
    return res.data;
  }

  /// `GET /profile/flights/orders/{id}` — the source of truth for whether an
  /// order was actually paid. Never trust the WebView redirect alone.
  Future<dynamic> order(String id) async {
    final res = await _dio.get('/profile/flights/orders/$id');
    return res.data;
  }
```

Replace the stale doc comment on `pending` in `flight_api.dart` — it says the route 404'd, which predates the offer id relay being understood:

```dart
  /// `POST /flights/{offer_id}` — creates the order and returns it with a
  /// payment transaction.
  ///
  /// [offerId] must be the id returned by adding passengers. The 404 recorded
  /// here previously came from sending an earlier id in the relay.
```

- [ ] **Step 5: Add the notifier action**

```dart
  /// Creates the order. Uses [FlightBookingState.activeOfferId], which by
  /// this point is the id minted when passengers were added.
  Future<FlightOrder?> createOrder({required String currency}) async {
    final offerId = state.activeOfferId;
    if (offerId == null) return null;
    state = state.copyWith(
      status: FlightBookingStatus.creatingOrder,
      error: null,
    );
    try {
      final order = await _repo.createOrder(
        offerId: offerId,
        selectedBundleCodes: state.selectedBundleCodes,
        currency: currency,
      );
      state = state.copyWith(
        status: FlightBookingStatus.idle,
        order: order,
      );
      return order;
    } catch (e) {
      state = state.copyWith(
        status: FlightBookingStatus.error,
        error: e.toString(),
      );
      return null;
    }
  }
```

Add `FlightOrder? order` to the state and `creatingOrder` to the status enum.

- [ ] **Step 6: Run codegen and the test**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/features/flight/data/flight_order_body_test.dart`
Expected: PASS — 3 tests.

- [ ] **Step 7: Commit**

```bash
git add lib/features/flight test/features/flight/data/flight_order_body_test.dart
git commit -m "Create Flight Orders From The Passenger Offer Id"
```

---

## Task 5: The pay screen

**Files:**
- Create: `lib/features/flight/presentation/flight_pay_screen.dart`
- Modify: `flight_routes.dart`, `flight_passengers_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`

- [ ] **Step 1: Add the strings**

In `lib/l10n/app_en.arb`:

```json
  "flightPayTitle": "Review and pay",
  "flightPayItinerary": "Itinerary",
  "flightPayTravellers": "Travellers",
  "flightPayBundles": "Selected bundles",
  "flightPayNow": "Pay now",
```

In `lib/l10n/app_ar.arb`:

```json
  "flightPayTitle": "المراجعة والدفع",
  "flightPayItinerary": "خط السير",
  "flightPayTravellers": "المسافرين",
  "flightPayBundles": "الحزم المختارة",
  "flightPayNow": "ادفع دلوقتي",
```

- [ ] **Step 2: Write the screen**

Create `lib/features/flight/presentation/flight_pay_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/domain/entities/flight_wizard_step.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_booking_step_bar.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/booking_terms_checkbox.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Wizard step 4 — the last screen before money moves.
class FlightPayScreen extends ConsumerStatefulWidget {
  const FlightPayScreen({super.key});

  @override
  ConsumerState<FlightPayScreen> createState() => _FlightPayScreenState();
}

class _FlightPayScreenState extends ConsumerState<FlightPayScreen> {
  bool _termsAccepted = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(flightBookingProvider);
    final confirmed = state.confirmedOrder;
    final settings = ref.watch(flightSettingsProvider);

    if (confirmed == null || state.passengersOfferId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(FlightRoutes.results);
      });
      return const SizedBox.shrink();
    }

    final currency = settings.valueOrNull?.bookingCurrency ??
        confirmed.priceDetails.currency;

    return Scaffold(
      appBar: BookingAppBar(title: l10n.flightPayTitle),
      body: Column(
        children: [
          FlightBookingStepBar(
            current: FlightWizardStep.pay,
            haveBundles: state.selectedOffer?.haveBundles ?? false,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _Section(
                  title: l10n.flightPayItinerary,
                  children: [
                    for (final segment in confirmed.segments)
                      Text(
                        '${segment.origin} → ${segment.destination}'
                        '  ·  ${segment.marketingCarrierCode}'
                        '${segment.marketingFlightNumber}',
                        style: AppTypography.body,
                      ),
                  ],
                ),
                _Section(
                  title: l10n.flightPayTravellers,
                  children: [
                    for (final passenger in state.passengerDrafts)
                      Text(
                        [passenger.firstName, passenger.lastName]
                            .whereType<String>()
                            .join(' '),
                        style: AppTypography.body,
                      ),
                  ],
                ),
                if (state.selectedBundleCodes.isNotEmpty)
                  _Section(
                    title: l10n.flightPayBundles,
                    children: [
                      for (final code in state.selectedBundleCodes.values)
                        Text(code, style: AppTypography.body),
                    ],
                  ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.flightPriceTotal, style: AppTypography.body),
                    Text(
                      '${confirmed.priceDetails.totalAmount.toStringAsFixed(0)}'
                      ' $currency',
                      style: AppTypography.h2,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                BookingTermsCheckbox(
                  value: _termsAccepted,
                  onChanged: (value) =>
                      setState(() => _termsAccepted = value),
                  onOpenTerms: () => context.push(CmsPagePaths.terms),
                ),
                const SizedBox(height: AppSpacing.sm),
                PrimaryButton(
                  label: l10n.flightPayNow,
                  loading:
                      state.status == FlightBookingStatus.creatingOrder,
                  onPressed: _termsAccepted
                      ? () async {
                          final order = await ref
                              .read(flightBookingProvider.notifier)
                              .createOrder(currency: currency);
                          if (!context.mounted) return;
                          final url = order?.checkoutUrl;
                          if (url == null || url.isEmpty) return;
                          context.push(FlightRoutes.pay, extra: order);
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.caption
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...children,
        ],
      ),
    );
  }
}
```

`BookingTermsCheckbox` requires all three parameters — `value`, `onChanged`, and `onOpenTerms`. The terms destination matches bus's usage at `lib/features/bus/presentation/passenger_confirm_screen.dart:140`, so import `CmsPagePaths` from wherever that screen imports it.

**A failure here leaves the rider on this screen with the message.** The passengers and bundles are already committed server-side, so there is nothing for them to re-enter — retrying the same button is the correct recovery.

- [ ] **Step 3: Register the route and reach it**

In `flight_routes.dart`:

```dart
  static const payReview = '/flight/pay-review';
  static const pay = '/flight/pay';
  static const pending = '/flight/pending';
  static const ticket = '/flight/ticket';
```

`payReview` is the wizard's step 4; `pay` is the checkout WebView. Keeping them distinct matters because the WebView must not be reachable without a created order.

```dart
      GoRoute(
        path: FlightRoutes.payReview,
        builder: (context, state) => const FlightPayScreen(),
      ),
```

In `flight_passengers_screen.dart`, replace the success destination:

```dart
                      if (ok && context.mounted) {
                        context.push(FlightRoutes.payReview);
                      }
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/flight lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "Add Flight Review And Pay Step"
```

---

## Task 6: Payment WebView

**Files:**
- Create: `lib/features/flight/presentation/flight_payment_webview_screen.dart`

- [ ] **Step 1: Write the screen**

Model it directly on `lib/features/bus/presentation/payment_webview_screen.dart`, reusing its two exported pure helpers rather than reimplementing them:

```dart
import 'package:safaria/features/bus/presentation/payment_webview_screen.dart'
    show classifyPaymentNav, confirmLeavePayment, PaymentNavResult;
```

`classifyPaymentNav` keys off `success-payment` / `failed-payment` in the redirect path, which is independent of locale and gateway subdomain — the same contract applies to flight checkouts, so duplicating it would only create drift.

The screen takes the created `FlightOrder`, loads `order.checkoutUrl`, and:

1. Prevents navigation to the terminal redirect — classify first, then `NavigationDecision.prevent`.
2. On `success` or `failure`, calls the verify step rather than trusting the redirect.
3. Intercepts back-press with `confirmLeavePayment`.

```dart
class FlightPaymentWebViewScreen extends ConsumerStatefulWidget {
  const FlightPaymentWebViewScreen({super.key, required this.order});

  final FlightOrder order;

  @override
  ConsumerState<FlightPaymentWebViewScreen> createState() =>
      _FlightPaymentWebViewScreenState();
}

class _FlightPaymentWebViewScreenState
    extends ConsumerState<FlightPaymentWebViewScreen> {
  WebViewController? _controller;
  bool _loading = true;
  bool _verifyTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (request) =>
              _handleNavigation(request.url),
        ),
      )
      ..loadRequest(Uri.parse(widget.order.checkoutUrl!));
  }

  NavigationDecision _handleNavigation(String url) {
    final result = classifyPaymentNav(Uri.parse(url));
    if (result == PaymentNavResult.pending) {
      return NavigationDecision.navigate;
    }
    // The redirect target is a REGO page we never want to render — it says
    // nothing the server has not already recorded. Verify instead.
    _verify();
    return NavigationDecision.prevent;
  }

  /// The redirect is a hint, not proof. Only the order endpoint decides.
  Future<void> _verify() async {
    if (_verifyTriggered) return;
    _verifyTriggered = true;
    final order = await ref
        .read(flightRepositoryProvider)
        .order(widget.order.id);
    if (!mounted) return;
    final paid = order != null && isFlightOrderPaid(order);
    context.go(
      paid ? FlightRoutes.ticket : FlightRoutes.pending,
      extra: order ?? widget.order,
    );
  }
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = _controller;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Abandoning mid-checkout leaves a real, resumable order behind, so
        // make it a deliberate choice rather than a stray back-swipe.
        if (await confirmLeavePayment(context) && context.mounted) {
          context.go(FlightRoutes.pending, extra: widget.order);
        }
      },
      child: Scaffold(
        appBar: BookingAppBar(title: l10n.flightPayTitle),
        body: Stack(
          children: [
            if (controller != null) WebViewWidget(controller: controller),
            if (_loading)
              const ColoredBox(
                color: AppColors.bgElevated,
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
```

This mirrors `payment_webview_screen.dart` so the two checkouts behave identically. Compare against it before committing — if the bus screen has since gained handling this one lacks, port it rather than letting the two drift.

- [ ] **Step 2: Register the route**

```dart
      GoRoute(
        path: FlightRoutes.pay,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! FlightOrder) return const FlightResultsScreen();
          return FlightPaymentWebViewScreen(order: extra);
        },
      ),
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/flight/presentation
git commit -m "Add Flight Payment Webview"
```

---

## Task 7: Outcome screens

**Files:**
- Create: `lib/features/flight/presentation/flight_ticket_screen.dart`
- Create: `lib/features/flight/presentation/flight_pending_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`

- [ ] **Step 1: Add the strings**

In `lib/l10n/app_en.arb`:

```json
  "flightTicketTitle": "Your booking is confirmed",
  "flightTicketPnr": "Booking reference",
  "flightPendingTitle": "Payment not completed",
  "flightPendingBody": "Your booking is held but not paid. You can finish paying from My Tickets.",
  "flightPendingRetry": "Try paying again",
  "flightGoToTickets": "Go to My Tickets",
```

In `lib/l10n/app_ar.arb`:

```json
  "flightTicketTitle": "حجزك اتأكد",
  "flightTicketPnr": "رقم الحجز",
  "flightPendingTitle": "الدفع ما تمّش",
  "flightPendingBody": "الحجز محجوز بس لسه ما اتدفعش. تقدر تكمّل الدفع من تذاكري.",
  "flightPendingRetry": "جرّب تدفع تاني",
  "flightGoToTickets": "روح لتذاكري",
```

- [ ] **Step 2: Write both screens**

`flight_ticket_screen.dart` takes the verified `FlightOrder` and shows a success mark, `flightTicketTitle`, the PNR when present (`airlinePnr ?? gdsPnr`), the itinerary from `order.segments`, the passenger names, the total, and a button to My Tickets.

`flight_pending_screen.dart` takes the same order and shows `flightPendingTitle` and `flightPendingBody`, a `flightPendingRetry` button that pushes the WebView again with `order.checkoutUrl`, and a secondary button to My Tickets.

Both use `BookingAppBar` and the shared `PrimaryButton`, matching the bus equivalents in `eticket_screen.dart` and `payment_pending_screen.dart`.

```dart
class FlightTicketScreen extends StatelessWidget {
  const FlightTicketScreen({super.key, required this.order});

  final FlightOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pnr = order.airlinePnr ?? order.gdsPnr;

    return Scaffold(
      appBar: BookingAppBar(title: l10n.flightTicketTitle),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Icon(
            PhosphorIconsLight.checkCircle,
            size: 56,
            color: AppColors.success,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.flightTicketTitle,
            textAlign: TextAlign.center,
            style: AppTypography.h2,
          ),
          if (pnr != null && pnr.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.flightTicketPnr,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
            Text(pnr, style: AppTypography.h2),
          ],
          const SizedBox(height: AppSpacing.lg),
          for (final segment in order.segments)
            Text(
              '${segment.origin} → ${segment.destination}',
              style: AppTypography.body,
            ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: l10n.flightGoToTickets,
            onPressed: () => context.go(AppRoutes.tickets),
          ),
        ],
      ),
    );
  }
}
```

The My Tickets tab is `AppRoutes.tickets` (`'/tickets'`) in `lib/core/router/app_router.dart:42`. Use `context.go`, not `push` — the booking flow is finished and its stack should not remain behind the tab.

Now the pending screen, `flight_pending_screen.dart`:

```dart
class FlightPendingScreen extends StatelessWidget {
  const FlightPendingScreen({super.key, required this.order});

  final FlightOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final checkoutUrl = order.checkoutUrl;

    return Scaffold(
      appBar: BookingAppBar(title: l10n.flightPendingTitle),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Icon(
            PhosphorIconsLight.clock,
            size: 56,
            color: AppColors.warning,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.flightPendingTitle,
            textAlign: TextAlign.center,
            style: AppTypography.h2,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.flightPendingBody,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (checkoutUrl != null && checkoutUrl.isNotEmpty)
            PrimaryButton(
              label: l10n.flightPendingRetry,
              onPressed: () =>
                  context.push(FlightRoutes.pay, extra: order),
            ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: l10n.flightGoToTickets,
            variant: PrimaryButtonVariant.ghost,
            onPressed: () => context.go(AppRoutes.tickets),
          ),
        ],
      ),
    );
  }
}
```

The order already exists server-side, so retrying reopens the same checkout rather than creating a second booking.

- [ ] **Step 3: Register both routes**

```dart
      GoRoute(
        path: FlightRoutes.ticket,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! FlightOrder) return const FlightResultsScreen();
          return FlightTicketScreen(order: extra);
        },
      ),
      GoRoute(
        path: FlightRoutes.pending,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! FlightOrder) return const FlightResultsScreen();
          return FlightPendingScreen(order: extra);
        },
      ),
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/flight lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "Add Flight Ticket And Pending Outcome Screens"
```

---

## Task 8: Flight orders in My Tickets

**Files:**
- Create: `lib/features/flight/presentation/providers/flight_orders_provider.dart`
- Modify: the My Tickets screen that already lists bus and private orders

- [ ] **Step 1: Add the providers**

```dart
/// Flight orders for My Tickets. Refreshed after a payment returns so a
/// newly paid booking appears without a restart.
final flightOrdersProvider = FutureProvider<List<FlightOrder>>((ref) {
  return ref.watch(flightRepositoryProvider).orders();
});

final flightOrderProvider =
    FutureProvider.family<FlightOrder?, String>((ref, id) {
  return ref.watch(flightRepositoryProvider).order(id);
});
```

- [ ] **Step 2: Render a flight orders section**

Locate the My Tickets screen by finding where `lib/features/bus/presentation/widgets/bus_orders_section.dart` is used:

```bash
grep -rn "BusOrdersSection" lib/features --include=*.dart
```

Add `FlightOrdersSection` beside it, mirroring that widget's structure — a section header, a card per order, and an empty state. Create it at `lib/features/flight/presentation/widgets/flight_orders_section.dart`:

```dart
class FlightOrdersSection extends ConsumerWidget {
  const FlightOrdersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final orders = ref.watch(flightOrdersProvider);

    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(l10n.flightOrdersSection, style: AppTypography.h2),
            ),
            for (final order in list)
              _FlightOrderCard(
                order: order,
                onResume: isFlightOrderPaid(order)
                    ? null
                    : () => context.push(FlightRoutes.pay, extra: order),
              ),
          ],
        );
      },
    );
  }
}
```

`_FlightOrderCard` shows the first segment's route, its departure date, the total, and a status badge driven by `isFlightOrderPaid` — paid renders the success token, unpaid renders the warning token and the resume action. Model its visual structure on `bus_order_card.dart` so both order types read the same in the list.

Add the section string. In `lib/l10n/app_en.arb`: `"flightOrdersSection": "Flights",`
In `lib/l10n/app_ar.arb`: `"flightOrdersSection": "الطيران",`

Resuming pushes the same checkout URL rather than creating a new order — the booking already exists server-side.

- [ ] **Step 3: Verify and commit**

Run: `flutter gen-l10n && flutter analyze && flutter test`
Expected: clean.

```bash
git add lib/features
git commit -m "List Flight Orders In My Tickets"
```

---

## Task 9: Verify the paid state for real

Do this **after** the rest of the plan. Until it lands, a paid booking may show as pending — which is the safe direction to be wrong in.

- [ ] **Step 1: Ask the backend team first**

Product is already collecting the status list. The values needed are: what `order_status` and `transaction.status` become after a successful payment, and whether `airline_pnr` is populated at that point or later.

If the answer arrives, go straight to step 3.

- [ ] **Step 2: Otherwise, observe one sandbox payment**

On the demo environment only, complete a booking through the gateway's own sandbox using **its published test card details** — never a real card, and never on production. Then read the order back:

```bash
curl -s "https://demo.safaria.travel/api/v1/profile/flights/orders/PASTE_ORDER_ID" \
  -H "Accept: application/json" -H "Authorization: Bearer PASTE_TOKEN"
```

Record `status`, `order_status`, `transaction.status`, `transaction.paid_at`, `airline_pnr`, and `gds_pnr`.

- [ ] **Step 3: Update the predicate**

Replace the two provisional sets in `lib/features/flight/domain/utils/flight_order_status.dart` with the observed values, and update the doc comment to say they are confirmed rather than provisional. Add a test case using the exact values seen.

Keep the conservative default: unrecognised means unpaid.

- [ ] **Step 4: Close the open question**

In `docs/superpowers/specs/2026-08-08-flight-booking-flow-design.md`, move item 1 out of "Still open" into the resolved table.

Check whether the bus flow's equivalent predicate agrees. Fixing bus is out of scope for this plan — if it disagrees, raise it as its own task rather than changing it here.

- [ ] **Step 5: Commit**

```bash
git add lib/features/flight/domain/utils/flight_order_status.dart test/features/flight/domain/flight_order_status_test.dart docs/superpowers/specs/2026-08-08-flight-booking-flow-design.md
git commit -m "Confirm Flight Order Paid Statuses"
```

---

## Done when

- [ ] `flutter analyze` is clean and `flutter test` passes
- [ ] A booking completes end to end on demo and reaches the ticket screen
- [ ] Abandoning the checkout leaves a resumable order in My Tickets
- [ ] The success screen is driven only by the order endpoint, never the redirect
- [ ] `isFlightOrderPaid` uses observed values and unrecognised statuses read as unpaid
- [ ] The stale `pending` doc comment in `flight_api.dart` is replaced
