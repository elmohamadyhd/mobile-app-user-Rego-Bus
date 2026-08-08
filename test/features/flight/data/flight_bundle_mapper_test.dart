import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/data/flight_dto_mapper.dart';

import 'flight_bundles_fixture.dart';

void main() {
  test('maps the captured payload into journeys and bundles', () {
    final result = FlightDtoMapper.journeyBundlesFromEnvelope(bundlesEnvelope);
    expect(result, isNotEmpty);
    expect(result.first.offerJourneyId, isNotEmpty);
    expect(result.first.bundles, isNotEmpty);
    expect(result.first.bundles.first.code, isNotEmpty);
  });

  test('a single bundle_prices object becomes a one-entry list', () {
    final envelope = {
      'data': [
        {
          'offer_journey_id': 'j1',
          'bundles': [
            {
              'bundle_code': 'RCAI',
              'bundle_name': 'Light',
              'bundle_prices': {
                'passenger_type_code': 'ADT',
                'total_amount': 250,
                'taxes_amount': 0,
                'fee_mount': 0,
                'currency': 'EGP',
              },
              'included_services': ['15KG Check-in Baggage'],
            },
          ],
        },
      ],
    };
    final result = FlightDtoMapper.journeyBundlesFromEnvelope(envelope);
    final prices = result.first.bundles.first.prices;
    expect(prices, hasLength(1));
    expect(prices.first.passengerTypeCode, 'ADT');
    expect(prices.first.totalAmount, 250);
  });

  test('an array of bundle_prices maps one entry per passenger type', () {
    final envelope = {
      'data': [
        {
          'offer_journey_id': 'j1',
          'bundles': [
            {
              'bundle_code': 'RCAI',
              'bundle_name': 'Light',
              'bundle_prices': [
                {'passenger_type_code': 'ADT', 'total_amount': 250},
                {'passenger_type_code': 'CHD', 'total_amount': 125},
              ],
              'included_services': <String>[],
            },
          ],
        },
      ],
    };
    final result = FlightDtoMapper.journeyBundlesFromEnvelope(envelope);
    expect(
      result.first.bundles.first.prices
          .map((p) => p.passengerTypeCode)
          .toList(),
      ['ADT', 'CHD'],
    );
  });
}
