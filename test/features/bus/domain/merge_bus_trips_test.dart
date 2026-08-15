import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/bus/domain/entities/bus_trip.dart';
import 'package:safaria/features/bus/domain/utils/merge_bus_trips.dart';

import '../fake_bus_repository.dart';

BusTripSummary _trip(String id, {double price = 100}) {
  return FakeBusRepository.sampleTrip.copyWith(id: id, priceStartWith: price);
}

void main() {
  group('mergeBusTrips', () {
    test('appends unseen trips and reports a change', () {
      final result = mergeBusTrips([_trip('a')], [_trip('b')]);

      expect(result.trips.map((t) => t.id), ['a', 'b']);
      expect(result.changed, isTrue);
    });

    test('replaces a trip whose price moved and reports a change', () {
      final result = mergeBusTrips(
        [_trip('a', price: 100)],
        [_trip('a', price: 120)],
      );

      expect(result.trips, hasLength(1));
      expect(result.trips.single.priceStartWith, 120);
      expect(result.changed, isTrue);
    });

    test('reports no change when the round repeats what is already held', () {
      final result = mergeBusTrips([_trip('a')], [_trip('a')]);

      expect(result.trips.map((t) => t.id), ['a']);
      expect(result.changed, isFalse);
    });

    test('keeps a trip that disappeared from the newer round', () {
      final result = mergeBusTrips([_trip('a'), _trip('b')], [_trip('a')]);

      expect(result.trips.map((t) => t.id), ['a', 'b']);
      expect(result.changed, isFalse);
    });

    test('preserves first-seen order across several rounds', () {
      final first = mergeBusTrips([], [_trip('c'), _trip('a')]);
      final second = mergeBusTrips(first.trips, [_trip('b')]);

      expect(second.trips.map((t) => t.id), ['c', 'a', 'b']);
    });

    test('collapses ids duplicated in the existing list', () {
      final result = mergeBusTrips([_trip('a'), _trip('a')], []);

      expect(result.trips.map((t) => t.id), ['a']);
      expect(result.changed, isFalse);
    });
  });
}
