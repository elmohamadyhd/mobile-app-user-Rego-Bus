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
