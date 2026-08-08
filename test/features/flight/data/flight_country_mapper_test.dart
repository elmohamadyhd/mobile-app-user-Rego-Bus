import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/data/flight_dto_mapper.dart';
import 'package:safaria/features/flight/domain/entities/flight_country.dart';

const _envelope = {
  'status': 200,
  'message': 'Countries',
  'errors': <String, dynamic>{},
  'data': [
    {'name': 'Egypt', 'iso2': 'EG', 'iso3': 'EGY', 'phonecode': '20'},
    {'name': 'Saudi Arabia', 'iso2': 'SA', 'iso3': 'SAU', 'phonecode': '966'},
  ],
};

void main() {
  test('maps every country with both ISO widths', () {
    final countries = FlightDtoMapper.countriesFromEnvelope(_envelope);
    expect(countries, hasLength(2));
    expect(countries.first.name, 'Egypt');
    expect(countries.first.iso2, 'EG');
    expect(countries.first.iso3, 'EGY');
    expect(countries.first.phoneCode, '20');
  });

  test('passengerCode returns the width the provider accepts', () {
    const egypt =
        FlightCountry(name: 'Egypt', iso2: 'EG', iso3: 'EGY', phoneCode: '20');
    // Settled by Phase 3 Task 1: passenger fields take iso3.
    expect(egypt.passengerCode, 'EGY');
    expect(kPassengerCountryCodeWidth, FlightCountryCodeWidth.iso3);
  });

  test('a malformed row is skipped rather than crashing the list', () {
    final countries = FlightDtoMapper.countriesFromEnvelope({
      'data': [
        {'name': 'Egypt', 'iso2': 'EG', 'iso3': 'EGY', 'phonecode': '20'},
        {'iso2': null},
      ],
    });
    expect(countries, hasLength(1));
  });
}
