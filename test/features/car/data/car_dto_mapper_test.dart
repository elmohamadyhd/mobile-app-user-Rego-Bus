import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/car/data/car_dto_mapper.dart';

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

    test('maps details envelope to a single quote', () {
      final quote =
          CarDtoMapper.quoteFromDetailsEnvelope(privateTripDetailsEnvelope);
      expect(quote.id, 1);
      expect(quote.goPrice, 1000);
      expect(quote.roundPrice, 1500);
      expect(quote.currency, 'EGP');
      expect(quote.company.name, 'Sky Travel');
      expect(quote.vehicle.categoryName, 'Sedan');
      expect(quote.vehicle.seatsNumber, 5);
    });

    test('throws ApiException on details 404 envelope', () {
      expect(
        () => CarDtoMapper.quoteFromDetailsEnvelope(
          privateTripDetailsNotFoundEnvelope,
        ),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
