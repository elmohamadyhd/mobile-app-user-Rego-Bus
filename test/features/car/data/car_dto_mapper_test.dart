import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/car/data/car_dto_mapper.dart';
import 'package:safaria/features/car/domain/entities/car_order.dart';
import 'package:safaria/features/car/domain/entities/car_search_params.dart';
import 'package:safaria/shared/models/map_place.dart';

import '../fake_car_repository.dart';
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

    test('maps create order envelope', () {
      final order = CarDtoMapper.orderFromEnvelope(privateOrderCreatedEnvelope);
      expect(order.id, 39);
      expect(order.statusKind, CarOrderStatusKind.pending);
      expect(order.price, '1000.00');
      expect(order.currency, 'EGP');
      expect(order.invoiceUrl, 'https://eg.myfatoorah.com/EGY/ia/sample');
      expect(order.canBeCancel, isTrue);
      expect(order.trip?.company.name, 'Sky Travel');
      expect(order.paymentGateway, 'myfatoorah');
      expect(order.paymentInvoiceId, '8213800');
      expect(order.trip?.fromLocation.name, 'Cairo');
      expect(order.trip?.toLocation.name, 'Alexandria');
    });

    test('builds create order body from selection', () {
      final params = CarSearchParams(
        from: const MapPlace(
          label: 'A',
          latitude: 30.03,
          longitude: 31.26,
        ),
        to: const MapPlace(
          label: 'B',
          latitude: 31.18,
          longitude: 29.89,
        ),
        rounded: false,
        departDate: DateTime(2026, 12, 20, 22, 0),
      );
      final req = CarDtoMapper.createRequestFromSelection(
        quote: FakeCarRepository.sampleQuote,
        params: params,
      );
      final body = CarDtoMapper.createOrderBody(req);
      expect(body['trip_id'], 1);
      expect(body['rounded'], false);
      expect(
        (body['departure'] as Map)['date'],
        '2026-12-20 22:00',
      );
      expect(
        (body['destination'] as Map)['date'],
        '2026-12-20 22:00',
      );
    });

    test('orderStatusKind maps paid and cancelled', () {
      expect(
        CarDtoMapper.orderStatusKind('confirmed'),
        CarOrderStatusKind.confirmed,
      );
      expect(
        CarDtoMapper.orderStatusKind('cancelled'),
        CarOrderStatusKind.cancelled,
      );
      expect(
        CarDtoMapper.orderStatusKind('pending'),
        CarOrderStatusKind.pending,
      );
    });
  });
}
