import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_rules.dart';

void main() {
  test('total sums all three types', () {
    const counts = FlightPassengerCounts(adults: 2, children: 3, infants: 1);
    expect(counts.total, 6);
  });

  test('a tenth passenger is blocked, whatever the type', () {
    const counts = FlightPassengerCounts(adults: 5, children: 4);
    expect(canAddFlightPassenger(counts, FlightPassengerType.child), isFalse);
    expect(
      flightPassengerLimit(counts, FlightPassengerType.child),
      FlightPassengerLimit.maxTotal,
    );
  });

  test('an infant needs a spare adult', () {
    const counts = FlightPassengerCounts(adults: 2, infants: 2);
    expect(canAddFlightPassenger(counts, FlightPassengerType.infant), isFalse);
    expect(
      flightPassengerLimit(counts, FlightPassengerType.infant),
      FlightPassengerLimit.infantsPerAdult,
    );
  });

  test('an infant is allowed while adults outnumber infants', () {
    const counts = FlightPassengerCounts(adults: 2, infants: 1);
    expect(canAddFlightPassenger(counts, FlightPassengerType.infant), isTrue);
  });

  test('the last adult cannot be removed', () {
    const counts = FlightPassengerCounts(adults: 1);
    expect(
      canRemoveFlightPassenger(counts, FlightPassengerType.adult),
      isFalse,
    );
  });

  test('an adult an infant depends on cannot be removed', () {
    const counts = FlightPassengerCounts(adults: 2, infants: 2);
    expect(
      canRemoveFlightPassenger(counts, FlightPassengerType.adult),
      isFalse,
    );
  });

  test('wire passengers omit zero counts', () {
    const counts = FlightPassengerCounts(adults: 2, children: 1);
    final wire = toWirePassengers(counts);
    expect(wire.map((p) => p.passengerTypeCode).toList(), ['ADT', 'CHD']);
    expect(wire.first.count, 2);
  });
}
