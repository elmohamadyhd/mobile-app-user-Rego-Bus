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
