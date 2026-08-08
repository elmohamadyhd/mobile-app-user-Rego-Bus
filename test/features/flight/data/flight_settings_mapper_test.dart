import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/data/flight_dto_mapper.dart';

void main() {
  test('reads the booking currency and gateway', () {
    final settings = FlightDtoMapper.settingsFromEnvelope({
      'status': 200,
      'data': {
        'default_booking_currency': 'EGP',
        'payment_gateway': 'myfatoorah',
      },
    });
    expect(settings.bookingCurrency, 'EGP');
    expect(settings.paymentGateway, 'myfatoorah');
  });

  test('falls back to EGP when the field is missing', () {
    final settings = FlightDtoMapper.settingsFromEnvelope({'data': {}});
    expect(settings.bookingCurrency, 'EGP');
  });

  test('a malformed envelope yields defaults rather than throwing', () {
    expect(FlightDtoMapper.settingsFromEnvelope(null).bookingCurrency, 'EGP');
  });
}
