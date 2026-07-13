import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/domain/entities/bus_trip_filters.dart';
import 'package:rego/features/bus/domain/utils/apply_bus_trip_filters.dart';

BusTripSummary _trip({
  required String id,
  required String operatorName,
  required DateTime depart,
  required int priceEgp,
}) {
  return BusTripSummary(
    id: id,
    gatewayId: 'gw',
    operatorName: operatorName,
    category: 'VIP',
    dateTime: depart,
    currency: 'EGP',
    availableSeats: 5,
    defaultBoardingStop: BusStop(
      locationId: 'b$id',
      name: 'Board',
      cityId: 1,
      cityName: 'Cairo',
      arrivalAt: depart,
    ),
    defaultDropoffStop: BusStop(
      locationId: 'd$id',
      name: 'Drop',
      cityId: 2,
      cityName: 'Alex',
      finalPrice: priceEgp.toDouble(),
    ),
  );
}

void main() {
  final tripA = _trip(
    id: 'a',
    operatorName: 'Go Bus',
    depart: DateTime(2026, 7, 10, 8),
    priceEgp: 150,
  );
  final tripB = _trip(
    id: 'b',
    operatorName: 'Blue Bus',
    depart: DateTime(2026, 7, 10, 12),
    priceEgp: 250,
  );
  final tripC = _trip(
    id: 'c',
    operatorName: 'Go Bus',
    depart: DateTime(2026, 7, 10, 18),
    priceEgp: 100,
  );
  final trips = [tripA, tripB, tripC];

  group('uniqueOperators', () {
    test('returns sorted deduplicated operator names', () {
      expect(uniqueOperators(trips), ['Blue Bus', 'Go Bus']);
    });
  });

  group('priceBounds', () {
    test('returns min and max terminal price', () {
      expect(priceBounds(trips), (100, 250));
    });
  });

  group('departBounds', () {
    test('returns earliest and latest departure in minutes', () {
      expect(departBounds(trips), (8 * 60, 18 * 60));
    });
  });

  group('applyBusTripFilters', () {
    test('returns all trips when filters are inactive', () {
      expect(
        applyBusTripFilters(trips, const BusTripFilters()),
        trips,
      );
    });

    test('filters by operator', () {
      final result = applyBusTripFilters(
        trips,
        const BusTripFilters(operators: {'Go Bus'}),
      );
      expect(result.map((t) => t.id), ['a', 'c']);
    });

    test('empty operators set does not filter by operator', () {
      expect(
        applyBusTripFilters(trips, const BusTripFilters(operators: {})),
        trips,
      );
    });

    test('filters by departure time window', () {
      final result = applyBusTripFilters(
        trips,
        const BusTripFilters(
          departAfter: TimeOfDay(hour: 9, minute: 0),
          departBefore: TimeOfDay(hour: 17, minute: 0),
        ),
      );
      expect(result.map((t) => t.id), ['b']);
    });

    test('includes boundary departures in time window', () {
      final result = applyBusTripFilters(
        trips,
        const BusTripFilters(
          departAfter: TimeOfDay(hour: 8, minute: 0),
          departBefore: TimeOfDay(hour: 18, minute: 0),
        ),
      );
      expect(result.length, 3);
    });

    test('filters by minimum price', () {
      final result = applyBusTripFilters(
        trips,
        const BusTripFilters(minPriceEgp: 150),
      );
      expect(result.map((t) => t.id), ['a', 'b']);
    });

    test('filters by maximum price', () {
      final result = applyBusTripFilters(
        trips,
        const BusTripFilters(maxPriceEgp: 150),
      );
      expect(result.map((t) => t.id), ['a', 'c']);
    });

    test('combines filters with AND semantics', () {
      final result = applyBusTripFilters(
        trips,
        const BusTripFilters(
          operators: {'Go Bus'},
          minPriceEgp: 120,
          maxPriceEgp: 200,
        ),
      );
      expect(result.map((t) => t.id), ['a']);
    });
  });
}
