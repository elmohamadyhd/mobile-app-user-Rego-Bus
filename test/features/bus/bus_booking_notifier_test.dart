import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rego/features/bus/domain/entities/bus_search_params.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/domain/repositories/bus_repository.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';

import 'fake_bus_repository.dart';

BusTicket _pendingTicket({String? paymentUrl = 'https://pay.example/1'}) {
  return BusTicket(
    bookingRef: '000001',
    orderId: '42',
    trip: FakeBusRepository.sampleTrip,
    fromStop: FakeBusRepository.sampleTrip.defaultBoardingStop,
    toStop: FakeBusRepository.sampleTrip.defaultDropoffStop,
    seats: const ['16'],
    ticketLines: const [],
    total: 'EGP 100',
    currency: 'EGP',
    paymentUrl: paymentUrl,
    statusCode: 'pending',
    issuedAt: DateTime(2026, 7, 10),
  );
}

/// Drives the notifier to the point just before `confirmBooking`: search
/// params set (required by `confirmBooking`), a trip selected, one seat picked.
Future<void> _prepareBooking(BusBookingNotifier notifier) async {
  await notifier.searchTrips(
    BusSearchParams(cityFromId: 1, cityToId: 2, date: DateTime(2026, 7, 10)),
  );
  await notifier.selectTrip(FakeBusRepository.sampleTrip);
  notifier.toggleSeat('16');
}

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

    test('selectTrip enters loadingDetail then settles to idle', () async {
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
      final trip = container.read(busBookingProvider).trips.first;

      // The synchronous seed sets the trip + loading status before enrichment.
      final future = notifier.selectTrip(trip);
      final loadingState = container.read(busBookingProvider);
      expect(loadingState.status, BusBookingStatus.loadingDetail);
      expect(loadingState.selectedTrip, isNotNull);

      await future;
      expect(container.read(busBookingProvider).status, BusBookingStatus.idle);
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

    test('confirmBooking with a payment_url awaits payment (not confirmed)',
        () async {
      final repo = FakeBusRepository(ticketResult: _pendingTicket());
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);
      await _prepareBooking(notifier);

      await notifier.confirmBooking();

      final state = container.read(busBookingProvider);
      expect(state.status, BusBookingStatus.awaitingPayment);
      expect(state.ticket?.paymentUrl, isNotNull);
    });

    test('confirmBooking without a payment_url confirms directly', () async {
      final repo =
          FakeBusRepository(ticketResult: _pendingTicket(paymentUrl: null));
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);
      await _prepareBooking(notifier);

      await notifier.confirmBooking();

      expect(
        container.read(busBookingProvider).status,
        BusBookingStatus.confirmed,
      );
    });

    test('verifyPayment confirms when the order reads back paid', () async {
      final repo = FakeBusRepository(
        ticketResult: _pendingTicket(),
        orderStatusResult: const BusOrderStatus(
          orderId: '42',
          statusCode: 'confirmed',
          isConfirmed: true,
        ),
      );
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);
      await _prepareBooking(notifier);
      await notifier.confirmBooking();

      await notifier.verifyPayment();

      expect(
        container.read(busBookingProvider).status,
        BusBookingStatus.confirmed,
      );
    });

    test('verifyPayment stays pending when the order is still unpaid',
        () async {
      final repo = FakeBusRepository(
        ticketResult: _pendingTicket(),
        orderStatusResult: const BusOrderStatus(
          orderId: '42',
          statusCode: 'pending',
          isConfirmed: false,
        ),
      );
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);
      await _prepareBooking(notifier);
      await notifier.confirmBooking();

      await notifier.verifyPayment();

      expect(
        container.read(busBookingProvider).status,
        BusBookingStatus.paymentPending,
      );
    });
  });
}
