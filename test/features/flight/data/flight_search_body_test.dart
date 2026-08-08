import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/data/flight_dto_mapper.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';

const _legCaiRuh = {
  'origin': 'CAI',
  'destination': 'RUH',
  'date': '2026-08-30',
};
const _legRuhJed = {
  'origin': 'RUH',
  'destination': 'JED',
  'date': '2026-09-02',
};

const _passengers = [
  {'passengerTypeCode': 'ADT', 'count': 1},
];

Map<String, dynamic> _body({
  required FlightTripType tripType,
  required List<Map<String, String>> legs,
  String? returnDate,
}) {
  return FlightDtoMapper.searchRequestBody(
    tripType: tripType,
    legs: legs,
    returnDate: returnDate,
    passengers: _passengers,
    sortingCriteria: 'CheapestFirst',
    cabinClass: 'CABIN_CLASS_ECONOMY',
    directFlightsOnly: false,
    currency: 'EGP',
  );
}

void main() {
  test('one-way sends a flat origin, destination and date', () {
    final body = _body(
      tripType: FlightTripType.oneWay,
      legs: [_legCaiRuh],
    );
    expect(body['origin'], 'CAI');
    expect(body['destination'], 'RUH');
    expect(body['date'], '2026-08-30');
    expect(body['trip_type'], 'one_way');
    expect(body.containsKey('return_date'), isFalse);
    expect(body.containsKey('segments'), isFalse);
  });

  test('round trip adds return_date', () {
    final body = _body(
      tripType: FlightTripType.roundTrip,
      legs: [_legCaiRuh],
      returnDate: '2026-09-05',
    );
    expect(body['origin'], 'CAI');
    expect(body['return_date'], '2026-09-05');
    expect(body['trip_type'], 'round_trip');
  });

  test('multi city sends segments and no flat route keys', () {
    final body = _body(
      tripType: FlightTripType.multiCity,
      legs: [_legCaiRuh, _legRuhJed],
    );
    expect(body['segments'], [_legCaiRuh, _legRuhJed]);
    expect(body['trip_type'], 'multi_city');
    expect(body.containsKey('origin'), isFalse);
    expect(body.containsKey('destination'), isFalse);
    expect(body.containsKey('date'), isFalse);
  });

  test('every shape keeps the misspelled currency key', () {
    for (final tripType in FlightTripType.values) {
      final body = _body(tripType: tripType, legs: [_legCaiRuh]);
      expect(body['curreny'], 'EGP', reason: tripType.wireValue);
      expect(body.containsKey('currency'), isFalse);
    }
  });
}
