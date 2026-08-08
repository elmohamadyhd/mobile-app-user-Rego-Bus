import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/flight/data/flight_dto_mapper.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';

import 'flight_fixtures.dart';

void main() {
  group('FlightDtoMapper', () {
    test('maps IATA envelope to airports and pagination', () {
      final (airports, pagination) =
          FlightDtoMapper.iataAirportsFromEnvelope(iataAirportsEnvelope);

      expect(airports, hasLength(2));
      expect(airports.first.iataCode, 'CAI');
      expect(airports.first.icaoCode, 'HECA');
      expect(airports.last.icaoCode, isNull);
      expect(airports.last.latitude, isNull);
      expect(pagination.total, 21);
      expect(pagination.hasNextPage, isTrue);
    });

    test('maps airport suggestions envelope', () {
      final suggestions = FlightDtoMapper.airportSuggestionsFromEnvelope(
        airportSuggestionsEnvelope,
      );

      expect(suggestions, hasLength(2));
      expect(suggestions.first.isAllAirport, isTrue);
      expect(suggestions.first.ranking, 179);
      expect(suggestions.last.isAllAirport, isFalse);
    });

    test('throws ApiException on airport suggestions validation error', () {
      expect(
        () => FlightDtoMapper.airportSuggestionsFromEnvelope(
          airportSuggestionsRequiredTermEnvelope,
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('maps search envelope to offers with journeys and segments', () {
      final offers = FlightDtoMapper.offersFromEnvelope(flightSearchEnvelope);

      expect(offers, hasLength(1));
      final offer = offers.first;
      expect(offer.offerId, 'offer-abc');
      expect(offer.haveBundles, isTrue);
      expect(offer.journeys, hasLength(1));

      final journey = offer.journeys.first;
      expect(journey.id, 'journey-abc');
      expect(journey.segments, hasLength(1));

      final segment = journey.segments.first;
      expect(segment.operatingCarrierName, 'Flight Operations Services');
      expect(
        segment.departureDateTime,
        DateTime.parse('2026-09-15T10:50:00+03:00'),
      );
      expect(offer.totalAmount, 7601);
      expect(offer.priceClasses.single.rulesAndPenalties, hasLength(2));
    });

    test('maps empty search data to empty offer list', () {
      final offers =
          FlightDtoMapper.offersFromEnvelope(flightSearchEmptyEnvelope);
      expect(offers, isEmpty);
    });

    test('maps "No available offers" 400 envelope to an empty list', () {
      final offers =
          FlightDtoMapper.offersFromEnvelope(flightSearchNoOffersEnvelope);
      expect(offers, isEmpty);
    });

    test('recognises the no-offers message case-insensitively', () {
      expect(
        FlightDtoMapper.isNoOffersEnvelope({
          'status': 400,
          'message': 'no available offers',
        }),
        isTrue,
      );
      expect(
        FlightDtoMapper.isNoOffersEnvelope({
          'status': 400,
          'message': 'offer id is not valid or expired',
        }),
        isFalse,
      );
    });

    test('search request body uses the curreny typo, not currency', () {
      final body = FlightDtoMapper.searchRequestBody(
        tripType: FlightTripType.oneWay,
        legs: const [
          {
            'origin': 'CAI',
            'destination': 'RUH',
            'date': '2026-09-15',
          },
        ],
        passengers: const [
          {'passengerTypeCode': 'ADT', 'count': 1},
        ],
        sortingCriteria: 'CheapestFirst',
        cabinClass: 'CABIN_CLASS_ECONOMY',
        directFlightsOnly: false,
        currency: 'EGP',
      );

      expect(body['curreny'], 'EGP');
      expect(body.containsKey('currency'), isFalse);
    });
  });
}
