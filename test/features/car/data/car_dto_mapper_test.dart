import 'package:flutter_test/flutter_test.dart';
import 'package:rego/features/car/data/car_dto_mapper.dart';

import 'car_fixtures.dart';

void main() {
  group('CarDtoMapper', () {
    test('maps search envelope to quote list', () {
      final quotes = CarDtoMapper.quotesFromEnvelope(privateSearchEnvelope);
      expect(quotes, hasLength(1));

      final q = quotes.first;
      expect(q.id, 1);
      expect(q.goPrice, 69.87);
      expect(q.roundPrice, 104.81);
      expect(q.currency, 'SAR');
      expect(q.company.name, 'Sky Travel');
      expect(q.company.refundability, isTrue);
      expect(q.vehicle.categoryName, 'Sedan');
      expect(q.vehicle.seatsNumber, 5);
      expect(q.fromLocation.latitude, closeTo(30.0441028, 0.0001));
    });

    test('maps empty data array to empty list', () {
      final quotes =
          CarDtoMapper.quotesFromEnvelope(privateSearchEmptyEnvelope);
      expect(quotes, isEmpty);
    });
  });
}
