import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/flight/domain/entities/flight_order.dart';
import 'package:safaria/features/flight/domain/utils/flight_order_review.dart';

void main() {
  test('flightOrderCanRate when paid + canReview + no rating', () {
    const order = FlightOrder(
      id: '1',
      status: 'confirmed',
      orderStatus: 'confirmed',
      paymentStatus: 'success',
      totalAmount: 100,
      currency: 'EGP',
      canReview: true,
    );
    expect(flightOrderCanRate(order), isTrue);
  });

  test('flightOrderCanRate false when unpaid', () {
    const order = FlightOrder(
      id: '1',
      status: 'pending',
      orderStatus: 'PendingPayment',
      paymentStatus: 'pending',
      totalAmount: 100,
      currency: 'EGP',
      canReview: true,
    );
    expect(flightOrderCanRate(order), isFalse);
  });
}
