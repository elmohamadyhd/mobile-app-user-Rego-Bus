import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/bus/domain/entities/bus_order.dart';
import 'package:safaria/features/bus/domain/entities/bus_ticket.dart';
import 'package:safaria/features/bus/domain/utils/bus_order_review.dart';

BusOrder _order({
  BusOrderStatusKind statusKind = BusOrderStatusKind.confirmed,
  bool canReview = false,
  int? reviewRating,
}) {
  return BusOrder(
    orderId: '1',
    bookingNumber: '1',
    operatorName: 'Op',
    category: 'VIP',
    statusText: 'Status',
    statusKind: statusKind,
    dateTimeLabel: '2026-08-11',
    ticketLines: const [
      BusTicketLine(id: 1, seatNumber: '1', price: '10'),
    ],
    total: 'EGP 10',
    canCancel: false,
    fare: const BusOrderFare(
      originalTicketsTotal: 'EGP 10',
      discount: 'EGP 0',
      walletDiscount: 'EGP 0',
      ticketsTotalAfterDiscount: 'EGP 10',
      paymentFees: 'EGP 0',
      total: 'EGP 10',
      currency: 'EGP',
    ),
    canReview: canReview,
    reviewRating: reviewRating,
  );
}

void main() {
  group('busOrderCanRate', () {
    test('eligible when confirmed, canReview, no rating', () {
      expect(
        busOrderCanRate(
          _order(canReview: true),
        ),
        isTrue,
      );
    });

    test('not eligible when canReview false', () {
      expect(busOrderCanRate(_order()), isFalse);
    });

    test('not eligible when already rated', () {
      expect(
        busOrderCanRate(_order(canReview: true, reviewRating: 4)),
        isFalse,
      );
    });

    test('not eligible when pending', () {
      expect(
        busOrderCanRate(
          _order(
            statusKind: BusOrderStatusKind.pending,
            canReview: true,
          ),
        ),
        isFalse,
      );
    });
  });
}
