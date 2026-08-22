import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/flight/domain/entities/flight_order.dart';
import 'package:safaria/features/flight/domain/utils/flight_order_journeys.dart';

FlightOrderSegment _hop({
  required String id,
  required String from,
  required String to,
  required DateTime depart,
  required DateTime arrive,
}) {
  return FlightOrderSegment(
    id: id,
    origin: from,
    destination: to,
    departureDateTime: depart,
    arrivalDateTime: arrive,
    marketingCarrierCode: 'LX',
    marketingFlightNumber: id,
  );
}

void main() {
  test('one-way connection stays one journey', () {
    final journeys = groupFlightOrderJourneys([
      _hop(
        id: '1',
        from: 'CAI',
        to: 'ZRH',
        depart: DateTime(2026, 8, 24, 13, 20),
        arrive: DateTime(2026, 8, 24, 17, 35),
      ),
      _hop(
        id: '2',
        from: 'ZRH',
        to: 'CDG',
        depart: DateTime(2026, 8, 24, 19, 10),
        arrive: DateTime(2026, 8, 24, 20, 30),
      ),
    ]);

    expect(journeys, hasLength(1));
    expect(journeys.single.first.origin, 'CAI');
    expect(journeys.single.last.destination, 'CDG');
  });

  test('round-trip with an overnight gap is two journeys', () {
    final journeys = groupFlightOrderJourneys([
      _hop(
        id: '1',
        from: 'CAI',
        to: 'ZRH',
        depart: DateTime(2026, 8, 24, 13, 20),
        arrive: DateTime(2026, 8, 24, 17, 35),
      ),
      _hop(
        id: '2',
        from: 'ZRH',
        to: 'CAI',
        depart: DateTime(2026, 8, 26, 4, 20),
        arrive: DateTime(2026, 8, 26, 12, 20),
      ),
    ]);

    expect(journeys, hasLength(2));
    expect(journeys[0].single.destination, 'ZRH');
    expect(journeys[1].single.destination, 'CAI');
  });

  test('same-day round-trip chain splits in half', () {
    final journeys = groupFlightOrderJourneys([
      _hop(
        id: '1',
        from: 'CAI',
        to: 'RUH',
        depart: DateTime(2026, 8, 24, 8),
        arrive: DateTime(2026, 8, 24, 11),
      ),
      _hop(
        id: '2',
        from: 'RUH',
        to: 'CAI',
        depart: DateTime(2026, 8, 24, 14),
        arrive: DateTime(2026, 8, 24, 17),
      ),
    ]);

    expect(journeys, hasLength(2));
    expect(journeys[0].single.origin, 'CAI');
    expect(journeys[1].single.origin, 'RUH');
  });
}
