import 'package:flutter_test/flutter_test.dart';
import 'package:rego/features/bus/data/bus_dto_mapper.dart';

import 'bus_fixtures.dart';

void main() {
  group('BusDtoMapper', () {
    test('maps trips search envelope to page with stops and fare', () {
      final page = BusDtoMapper.tripsPageFromEnvelope(tripsSearchEnvelope);
      expect(page.trips, hasLength(1));

      final trip = page.trips.first;
      expect(trip.id, '290545');
      expect(trip.boardingStops, hasLength(1));
      expect(trip.dropoffStops, hasLength(1));
      expect(trip.defaultDropoffStop.finalPrice, 148.5);
      expect(trip.priceEgp, 149);
    });

    test('mergeEnrichment keeps cached stops when detail stations are empty', () {
      final cached = BusDtoMapper.tripsPageFromEnvelope(tripsSearchEnvelope).trips.first;
      final detail = BusDtoMapper.tripFromEnvelope(tripByIdEmptyStationsEnvelope);

      final merged = cached.mergeEnrichment(detail);
      expect(merged.boardingStops, isNotEmpty);
      expect(merged.dropoffStops, isNotEmpty);
      expect(merged.defaultDropoffStop.finalPrice, 148.5);
    });

    test('isPaidStatus recognizes paid states and rejects pending', () {
      expect(BusDtoMapper.isPaidStatus('pending', 0), isFalse);
      expect(BusDtoMapper.isPaidStatus('Pending', 1), isTrue); // is_confirmed
      expect(BusDtoMapper.isPaidStatus('confirmed', 0), isTrue);
      expect(BusDtoMapper.isPaidStatus('PAID', 0), isTrue);
      expect(BusDtoMapper.isPaidStatus('success', 0), isTrue);
      expect(BusDtoMapper.isPaidStatus('failed', 0), isFalse);
    });

    test('orderStatusFromEnvelope reads a pending order', () {
      final order = BusDtoMapper.orderStatusFromEnvelope(<String, dynamic>{
        'status': 200,
        'message': 'order',
        'errors': <String, dynamic>{},
        'data': <String, dynamic>{
          'id': 1454,
          'status_code': 'pending',
          'is_confirmed': 0,
          'total': 'EGP 20.93',
          'payment_url': 'https://portal.wdenytravel.com/api/v1/buses/orders/1454/pay',
        },
      });

      expect(order.orderId, '1454');
      expect(order.statusCode, 'pending');
      expect(order.isConfirmed, isFalse);
      expect(order.total, 'EGP 20.93');
    });

    test('orderStatusFromEnvelope reads a confirmed order', () {
      final order = BusDtoMapper.orderStatusFromEnvelope(<String, dynamic>{
        'status': 200,
        'message': 'order',
        'errors': <String, dynamic>{},
        'data': <String, dynamic>{
          'id': 1455,
          'status_code': 'confirmed',
          'is_confirmed': 1,
        },
      });

      expect(order.isConfirmed, isTrue);
    });
  });
}
