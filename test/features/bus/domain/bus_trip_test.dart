import 'package:flutter_test/flutter_test.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';

BusTripSummary _tripWithStops({
  required BusStop defaultDrop,
  required List<BusStop> dropoffStops,
}) {
  final board = BusStop(
    locationId: '1',
    name: 'Ramsis',
    cityId: 1,
    cityName: 'Cairo',
    arrivalAt: DateTime(2026, 2, 10, 8),
  );
  return BusTripSummary(
    id: '1',
    gatewayId: 'gw',
    operatorName: 'Go Bus',
    category: 'VIP',
    dateTime: DateTime(2026, 2, 10, 8),
    currency: 'EGP',
    defaultBoardingStop: board,
    defaultDropoffStop: defaultDrop,
    boardingStops: [board],
    dropoffStops: dropoffStops,
  );
}

void main() {
  group('BusTripSummary terminal drop-off', () {
    test('terminalDropoffStop returns last drop-off when list is non-empty',
        () {
      final first = BusStop(
        locationId: '9',
        name: 'Sidi Gaber',
        cityId: 2,
        cityName: 'Alexandria',
        arrivalAt: DateTime(2026, 2, 10, 11, 30),
        finalPrice: 180,
      );
      final last = first.copyWith(
        locationId: '10',
        name: 'Moharam Bek',
        arrivalAt: DateTime(2026, 2, 10, 12, 45),
        finalPrice: 250,
      );
      final trip = _tripWithStops(
        defaultDrop: first,
        dropoffStops: [first, last],
      );

      expect(trip.terminalDropoffStop.name, 'Moharam Bek');
      expect(trip.terminalArriveLabel, '12:45');
      expect(trip.terminalDurationLabel, '4h 45m');
      expect(trip.terminalPriceEgp, 250);
      expect(trip.priceEgp, 180);
    });

    test('terminalDropoffStop falls back to default when list is empty', () {
      final drop = BusStop(
        locationId: '9',
        name: 'Sidi Gaber',
        cityId: 2,
        cityName: 'Alexandria',
        arrivalAt: DateTime(2026, 2, 10, 11, 30),
        finalPrice: 180,
      );
      final trip = _tripWithStops(defaultDrop: drop, dropoffStops: const []);

      expect(trip.terminalDropoffStop, drop);
      expect(trip.terminalArriveLabel, '11:30');
      expect(trip.terminalPriceEgp, 180);
    });
  });
}
