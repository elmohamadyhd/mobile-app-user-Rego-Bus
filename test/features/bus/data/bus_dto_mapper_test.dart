import 'package:flutter_test/flutter_test.dart';
import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/bus/data/bus_dto_mapper.dart';
import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';

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
      expect(trip.busImageUrl, isNull);
    });

    test('maps company_data.bus_image to busImageUrl when non-empty', () {
      final envelope = Map<String, dynamic>.from(tripsSearchEnvelope);
      final data = List<Map<String, dynamic>>.from(
        envelope['data'] as List,
      );
      final tripJson = Map<String, dynamic>.from(data.first);
      tripJson['company_data'] = {
        'name': 'النورس للنقل البري',
        'avatar': 'https://example.com/avatar.png',
        'bus_image': 'https://example.com/bus.jpeg',
        'pin': '',
      };
      data[0] = tripJson;
      envelope['data'] = data;

      final trip = BusDtoMapper.tripsPageFromEnvelope(envelope).trips.first;
      expect(
        trip.busImageUrl,
        'https://example.com/bus.jpeg',
      );
    });

    test('mergeEnrichment keeps cached stops when detail stations are empty',
        () {
      final cached =
          BusDtoMapper.tripsPageFromEnvelope(tripsSearchEnvelope).trips.first;
      final detail =
          BusDtoMapper.tripFromEnvelope(tripByIdEmptyStationsEnvelope);

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
      // "In Processing" is a confirmed Wadeny booking (operator issuing the
      // ticket), not an unpaid order.
      expect(BusDtoMapper.isPaidStatus('in_processing', 0), isTrue);
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
          'payment_url':
              'https://demo.safaria.travel/api/v1/buses/orders/1454/pay',
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

    group('ticketFromEnvelope', () {
      BusTicket map(Map<String, dynamic> envelope) =>
          BusDtoMapper.ticketFromEnvelope(
            body: envelope,
            trip: BusDtoMapper.emptyTrip(),
            fromStop: BusStop.empty,
            toStop: BusStop.empty,
            selectedSeats: const ['14'],
          );

      test('paymentUrl is the gateway checkout (payment_data.invoice_url)', () {
        final ticket = map(createTicketEnvelope);
        expect(
          ticket.paymentUrl,
          'https://demo.MyFatoorah.com/KWT/ia/01072695205842-dee51cf8',
        );
      });

      test('invoiceUrl is the e-ticket PDF (top-level invoice_url)', () {
        final ticket = map(createTicketEnvelope);
        expect(
          ticket.invoiceUrl,
          'https://portal.wdenytravel.com/orders/1466/invoice/download',
        );
      });

      test('order metadata (ref, id, status, seats, cancel) is mapped', () {
        final ticket = map(createTicketEnvelope);
        expect(ticket.bookingRef, '000001466');
        expect(ticket.orderId, '1466');
        expect(ticket.statusCode, 'pending');
        // `total` is passed through verbatim; the API formats it with a
        // non-breaking space, so assert on the currency and amount separately.
        expect(ticket.total, startsWith('EGP'));
        expect(ticket.total, contains('240.75'));
        expect(
          ticket.cancelUrl,
          'https://demo.safaria.travel/api/v1/buses/orders/1466/cancel',
        );
        expect(ticket.ticketLines, hasLength(1));
        expect(ticket.ticketLines.first.seatNumber, '14');
      });

      test('paymentUrl falls back to /pay when no gateway URL is present', () {
        final ticket = map(<String, dynamic>{
          'status': 200,
          'data': <String, dynamic>{
            'id': 1466,
            'payment_url':
                'https://demo.safaria.travel/api/v1/buses/orders/1466/pay',
            'invoice_url':
                'https://portal.wdenytravel.com/orders/1466/invoice/download',
          },
        });
        expect(
          ticket.paymentUrl,
          'https://demo.safaria.travel/api/v1/buses/orders/1466/pay',
        );
        expect(
          ticket.invoiceUrl,
          'https://portal.wdenytravel.com/orders/1466/invoice/download',
        );
      });
    });

    group('ordersFromEnvelope', () {
      test('maps bus orders list with status, seats, and URLs', () {
        final orders = BusDtoMapper.ordersFromEnvelope(busOrdersEnvelope);
        expect(orders, hasLength(2));

        final pending = orders.first;
        expect(pending.orderId, '1475');
        expect(pending.bookingNumber, '000001475');
        expect(pending.operatorName, 'SuperJet');
        expect(pending.category, 'Five stars');
        expect(pending.statusKind, BusOrderStatusKind.pending);
        expect(pending.ticketLines, hasLength(1));
        expect(pending.ticketLines.first.seatNumber, '1');
        expect(pending.pickupStopLabel, 'Cairo Main Station');
        expect(pending.dropoffStopLabel, 'Alexandria Terminal');
        expect(pending.total, 'EGP 219.35');
        expect(pending.canCancel, isTrue);
        expect(
          pending.cancelUrl,
          'https://demo.safaria.travel/api/v1/buses/orders/1475/cancel',
        );
        expect(pending.gatewayCheckoutUrl, isNotNull);
        expect(pending.invoiceUrl, isNotNull);
      });

      test('confirmed order without payment_data has no checkout url', () {
        final orders = BusDtoMapper.ordersFromEnvelope(busOrdersEnvelope);
        final confirmed = orders[1];
        expect(confirmed.statusKind, BusOrderStatusKind.confirmed);
        expect(confirmed.pickupStopLabel, isNull);
        expect(confirmed.dropoffStopLabel, isNull);
        expect(confirmed.canCancel, isFalse);
        expect(confirmed.cancelUrl, isNull);
        expect(confirmed.gatewayCheckoutUrl, isNull);
      });
    });

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
        expect(
          order.cancelUrl,
          'https://demo.safaria.travel/api/v1/buses/orders/1475/cancel',
        );
      });

      test('throws ApiException for the documented not-found envelope', () {
        expect(
          () => BusDtoMapper.orderFromEnvelope(busOrderNotFoundEnvelope),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('orderStatusKind', () {
      test('is_confirmed flag wins regardless of status_code', () {
        expect(
          BusDtoMapper.orderStatusKind('pending', 1),
          BusOrderStatusKind.confirmed,
        );
      });

      test('maps known confirmed/cancelled codes', () {
        expect(BusDtoMapper.orderStatusKind('confirmed', 0),
            BusOrderStatusKind.confirmed);
        expect(
            BusDtoMapper.orderStatusKind('paid', 0), BusOrderStatusKind.confirmed);
        expect(BusDtoMapper.orderStatusKind('cancelled', 0),
            BusOrderStatusKind.cancelled);
        expect(BusDtoMapper.orderStatusKind('expired', 0),
            BusOrderStatusKind.cancelled);
        expect(BusDtoMapper.orderStatusKind('in_processing', 0),
            BusOrderStatusKind.confirmed);
      });

      test('pending code with no confirm flag stays pending', () {
        expect(BusDtoMapper.orderStatusKind('pending', 0),
            BusOrderStatusKind.pending);
      });

      test('unrecognized code falls back to unknown', () {
        expect(BusDtoMapper.orderStatusKind('weird_code', 0),
            BusOrderStatusKind.unknown);
      });
    });
  });
}
