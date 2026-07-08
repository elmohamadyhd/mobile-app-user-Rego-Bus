import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rego/features/bus/domain/entities/bus_search_params.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/domain/repositories/bus_repository.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';

import 'fake_bus_repository.dart';

void main() {
  ProviderContainer makeContainer(FakeBusRepository repo) {
    final container = ProviderContainer(
      overrides: [
        busRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('BusBookingNotifier', () {
    test('initial state is idle with empty trips', () {
      final container = makeContainer(FakeBusRepository());
      final state = container.read(busBookingProvider);
      expect(state.status, BusBookingStatus.idle);
      expect(state.trips, isEmpty);
    });

    test('searchTrips populates trips from repository', () async {
      final repo = FakeBusRepository(
        tripsPage: BusTripsPage(
          trips: [FakeBusRepository.sampleTrip],
          currentPage: 1,
          lastPage: 1,
        ),
      );
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await notifier.searchTrips(
        BusSearchParams(
          cityFromId: 1,
          cityToId: 2,
          date: DateTime(2026, 7, 10),
        ),
      );

      final state = container.read(busBookingProvider);
      expect(state.status, BusBookingStatus.idle);
      expect(state.trips, hasLength(1));
    });

    test('selectTrip seeds default stops and segment fare', () async {
      final repo = FakeBusRepository(
        tripsPage: BusTripsPage(
          trips: [FakeBusRepository.sampleTrip],
          currentPage: 1,
          lastPage: 1,
        ),
        tripByIdResult: BusTripSummary(
          id: '290545',
          gatewayId: '',
          operatorName: '',
          category: '',
          dateTime: DateTime.now(),
          currency: 'EGP',
          defaultBoardingStop: BusStop.empty,
          defaultDropoffStop: BusStop.empty,
        ),
      );
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);
      await notifier.searchTrips(
        BusSearchParams(
          cityFromId: 1,
          cityToId: 2,
          date: DateTime(2026, 7, 10),
        ),
      );

      final trip = container.read(busBookingProvider).trips.first;
      await notifier.selectTrip(trip);

      final state = container.read(busBookingProvider);
      expect(state.fromStop?.locationId, '985052');
      expect(state.toStop?.locationId, '985053');
      expect(state.segmentFare, 148.5);
    });

    test('setStops updates dropoff fare only', () async {
      final container = makeContainer(FakeBusRepository());
      final notifier = container.read(busBookingProvider.notifier);
      final trip = FakeBusRepository.sampleTrip;
      await notifier.selectTrip(trip);

      final cheaperStop = trip.dropoffStops.first.copyWith(finalPrice: 99);
      notifier.setStops(from: trip.defaultBoardingStop, to: cheaperStop);

      expect(container.read(busBookingProvider).segmentFare, 99);
    });

    test('toggleSeat adds and removes seat ids', () async {
      final container = makeContainer(FakeBusRepository());
      final notifier = container.read(busBookingProvider.notifier);
      await notifier.selectTrip(FakeBusRepository.sampleTrip);

      notifier.toggleSeat('16');
      expect(container.read(busBookingProvider).selectedSeats, contains('16'));

      notifier.toggleSeat('16');
      expect(container.read(busBookingProvider).selectedSeats, isEmpty);
    });
  });
}
