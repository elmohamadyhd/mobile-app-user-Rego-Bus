import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/car/domain/entities/car_order.dart';
import 'package:safaria/features/car/domain/utils/car_order_review.dart';

CarOrder _order({
  CarOrderStatusKind statusKind = CarOrderStatusKind.confirmed,
  bool canReview = false,
  int? reviewRating,
}) {
  return CarOrder(
    id: 1,
    statusText: 'ok',
    statusKind: statusKind,
    price: '10',
    currency: 'EGP',
    rounded: false,
    from: const CarOrderCoords(latitude: 0, longitude: 0),
    to: const CarOrderCoords(latitude: 1, longitude: 1),
    canBeCancel: false,
    canReview: canReview,
    reviewRating: reviewRating,
  );
}

void main() {
  test('carOrderCanRate when confirmed + canReview + no rating', () {
    expect(carOrderCanRate(_order(canReview: true)), isTrue);
  });

  test('carOrderCanRate false when pending', () {
    expect(
      carOrderCanRate(
        _order(statusKind: CarOrderStatusKind.pending, canReview: true),
      ),
      isFalse,
    );
  });
}
