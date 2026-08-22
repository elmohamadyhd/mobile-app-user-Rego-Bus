import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
import 'package:safaria/features/flight/domain/utils/flight_airport_labels.dart';

FlightJourney _journey({
  required String origin,
  required String destination,
}) {
  return FlightJourney(
    id: '$origin-$destination',
    origin: origin,
    destination: destination,
    numberOfStops: 1,
    segments: [
      FlightSegment(
        id: 'seg',
        origin: origin,
        destination: destination,
        departureDateTime: DateTime(2026, 9, 15, 13, 45),
        arrivalDateTime: DateTime(2026, 9, 16, 6, 5),
        flightTimeInMinutes: 335,
        operatingCarrierCode: 'OS',
        operatingFlightNumber: '1',
        marketingCarrierCode: 'OS',
        marketingFlightNumber: '1',
      ),
    ],
  );
}

void main() {
  test('falls back to IATA when no search name is known', () {
    expect(
      flightAirportDisplayName(iataCode: 'CDG'),
      'CDG',
    );
  });

  test('prefers the picker name for the offer IATA', () {
    expect(
      flightAirportDisplayName(
        iataCode: 'CAI',
        fallbackName: 'All Airport',
        namesByIata: const {'CAI': 'Cairo Intl Airport'},
      ),
      'Cairo Intl Airport',
    );
  });

  test('round-trip return uses swapped search names when IATA is unknown', () {
    final labels = flightJourneyAirportLabels(
      index: 1,
      journey: _journey(origin: 'CDG', destination: 'CAI'),
      tripType: FlightTripType.roundTrip,
      searchFromLabel: 'Cairo Intl Airport',
      searchToLabel: 'All Airport',
    );

    expect(labels.origin, 'All Airport');
    expect(labels.destination, 'Cairo Intl Airport');
  });

  test('multi-city later legs use the matching search-leg names', () {
    final labels = flightJourneyAirportLabels(
      index: 1,
      journey: _journey(origin: 'CDG', destination: 'LHR'),
      tripType: FlightTripType.multiCity,
      searchLegs: [
        FlightSearchLeg(
          origin: 'CAI',
          destination: 'CDG',
          date: DateTime(2026, 9, 15),
        ),
        FlightSearchLeg(
          origin: 'CDG',
          destination: 'LHR',
          date: DateTime(2026, 9, 18),
        ),
      ],
      namesByIata: const {
        'CAI': 'Cairo Intl Airport',
        'CDG': 'Charles de Gaulle',
        'LHR': 'Heathrow',
      },
    );

    expect(labels.origin, 'Charles de Gaulle');
    expect(labels.destination, 'Heathrow');
  });
}
