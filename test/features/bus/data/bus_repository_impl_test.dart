import 'package:flutter_test/flutter_test.dart';
import 'package:rego/features/bus/data/bus_repository_impl.dart';
import 'package:rego/features/bus/data/mock_bus_data.dart';

void main() {
  group('BusRepositoryImpl', () {
    test('searchTrips returns the mock trip list', () async {
      final repo = BusRepositoryImpl();
      final trips = await repo.searchTrips('Cairo', 'Alexandria', '2026-06-30');
      expect(trips, MockBusData.trips);
      expect(trips.length, 3);
    });

    test('tripDetail returns the detail for the given trip id', () async {
      final repo = BusRepositoryImpl();
      final trip = MockBusData.trips.first;
      final detail = await repo.tripDetail(trip.id);
      expect(detail.summary.id, trip.id);
    });
  });
}
