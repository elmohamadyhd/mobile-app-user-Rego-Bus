import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safaria/features/bus/domain/entities/bus_search_params.dart';
import 'package:safaria/features/bus/domain/entities/bus_stop.dart';
import 'package:safaria/features/bus/domain/entities/bus_ticket.dart';
import 'package:safaria/features/bus/domain/entities/bus_trip.dart';
import 'package:safaria/features/bus/domain/repositories/bus_repository.dart';
import 'package:safaria/features/bus/presentation/providers/bus_booking_providers.dart';

import 'fake_bus_repository.dart';

BusTripSummary _trip(String id, {double price = 100}) {
  return FakeBusRepository.sampleTrip.copyWith(id: id, priceStartWith: price);
}

BusTripsPage _page(List<BusTripSummary> trips) {
  return BusTripsPage(trips: trips, currentPage: 1, lastPage: 1);
}

Future<void> _search(BusBookingNotifier notifier) {
  return notifier.searchTrips(
    BusSearchParams(cityFromId: 1, cityToId: 2, date: DateTime(2026, 7, 10)),
  );
}

BusTicket _pendingTicket({String? paymentUrl = 'https://pay.example/1'}) {
  return BusTicket(
    bookingRef: '000001',
    orderId: '42',
    trip: FakeBusRepository.sampleTrip,
    fromStop: FakeBusRepository.sampleTrip.defaultBoardingStop,
    // `selectTrip` seeds `toStop` from `terminalDropoffStop` (the last
    // dropoff stop), not `defaultDropoffStop` — match that so the reuse
    // guard's stop comparison lines up with what `_prepareBooking` sets.
    toStop: FakeBusRepository.sampleTrip.terminalDropoffStop,
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
  ProviderContainer makeContainer(
    FakeBusRepository repo, {
    Duration gap = Duration.zero,
  }) {
    final container = ProviderContainer(
      overrides: [
        busRepositoryProvider.overrideWithValue(repo),
        busSearchScheduleProvider.overrideWithValue(
          BusSearchSchedule(gap: gap),
        ),
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

    test('initial state is not searching and has nothing staged', () {
      final container = makeContainer(FakeBusRepository());
      final state = container.read(busBookingProvider);
      expect(state.searchPhase, BusSearchPhase.idle);
      expect(state.stagedTrips, isEmpty);
      expect(state.searchGeneration, 0);
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

    test('selectTrip seeds terminal drop-off stop and segment fare', () async {
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
      expect(state.toStop?.locationId, '985054');
      expect(state.segmentFare, 175);
    });

    test('selectTrip seeds explicit from/to when provided', () async {
      final trip = FakeBusRepository.sampleTrip;
      final from = trip.boardingStops.first;
      final to = trip.dropoffStops.first;
      final container = makeContainer(FakeBusRepository());
      final notifier = container.read(busBookingProvider.notifier);

      await notifier.selectTrip(trip, from: from, to: to);

      final state = container.read(busBookingProvider);
      expect(state.fromStop?.locationId, from.locationId);
      expect(state.toStop?.locationId, to.locationId);
      expect(state.segmentFare, to.finalPrice);
    });

    test('selectTrip without from/to keeps terminal drop-off default',
        () async {
      final trip = FakeBusRepository.sampleTrip;
      final container = makeContainer(FakeBusRepository());
      final notifier = container.read(busBookingProvider.notifier);

      await notifier.selectTrip(trip);

      final state = container.read(busBookingProvider);
      expect(state.fromStop?.locationId, trip.defaultBoardingStop.locationId);
      expect(state.toStop?.locationId, trip.terminalDropoffStop.locationId);
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

    test('setPaymentMethod wallet updates state', () async {
      final container = makeContainer(FakeBusRepository());
      final notifier = container.read(busBookingProvider.notifier);

      notifier.setPaymentMethod(PaymentMethod.wallet);

      expect(
        container.read(busBookingProvider).paymentMethod,
        PaymentMethod.wallet,
      );
    });

    test('confirmBooking with wallet sends payment_method wallet', () async {
      final repo = FakeBusRepository(
        ticketResult: _pendingTicket(paymentUrl: null).copyWith(
          statusCode: 'confirmed',
        ),
      );
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);
      await _prepareBooking(notifier);
      notifier.setPaymentMethod(PaymentMethod.wallet);

      await notifier.confirmBooking();

      expect(repo.lastCreateTicketRequest?.paymentMethod, 'wallet');
      expect(
        container.read(busBookingProvider).status,
        BusBookingStatus.confirmed,
      );
    });

    test('confirmBooking with visa sends payment_method credit', () async {
      final repo = FakeBusRepository(ticketResult: _pendingTicket());
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);
      await _prepareBooking(notifier);
      notifier.setPaymentMethod(PaymentMethod.visa);

      await notifier.confirmBooking();

      expect(repo.lastCreateTicketRequest?.paymentMethod, 'credit');
    });

    test(
        'confirmBooking with wallet and confirmed status confirms even with payment_url',
        () async {
      final repo = FakeBusRepository(
        ticketResult: _pendingTicket().copyWith(statusCode: 'confirmed'),
      );
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);
      await _prepareBooking(notifier);
      notifier.setPaymentMethod(PaymentMethod.wallet);

      await notifier.confirmBooking();

      expect(
        container.read(busBookingProvider).status,
        BusBookingStatus.confirmed,
      );
    });

    test('confirmBooking with wallet and payment_url awaits payment', () async {
      final repo = FakeBusRepository(ticketResult: _pendingTicket());
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);
      await _prepareBooking(notifier);
      notifier.setPaymentMethod(PaymentMethod.wallet);

      await notifier.confirmBooking();

      final state = container.read(busBookingProvider);
      expect(state.status, BusBookingStatus.awaitingPayment);
      expect(state.ticket?.paymentUrl, isNotNull);
    });

    test(
        'confirmBooking with wallet pending order without payment_url stays paymentPending',
        () async {
      final repo = FakeBusRepository(
        ticketResult: _pendingTicket(paymentUrl: null),
      );
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);
      await _prepareBooking(notifier);
      notifier.setPaymentMethod(PaymentMethod.wallet);

      await notifier.confirmBooking();

      expect(
        container.read(busBookingProvider).status,
        BusBookingStatus.paymentPending,
      );
    });

    test(
        'confirmBooking reuses held wallet ticket for the same trip/stops/seats',
        () async {
      final repo = FakeBusRepository(ticketResult: _pendingTicket());
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);
      await _prepareBooking(notifier);
      notifier.setPaymentMethod(PaymentMethod.wallet);

      await notifier.confirmBooking();
      expect(repo.createTicketCallCount, 1);

      await notifier.confirmBooking();

      expect(repo.createTicketCallCount, 1);
      expect(
        container.read(busBookingProvider).status,
        BusBookingStatus.awaitingPayment,
      );
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

    test('confirmBooking reuses the held ticket for the same trip/stops/seats',
        () async {
      final repo = FakeBusRepository(ticketResult: _pendingTicket());
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);
      await _prepareBooking(notifier);

      await notifier.confirmBooking();
      expect(repo.createTicketCallCount, 1);

      // Rider backed out of payment and taps "Confirm & pay" again with the
      // exact same trip/stops/seats — must reuse the held order.
      await notifier.confirmBooking();

      expect(repo.createTicketCallCount, 1);
      expect(
        container.read(busBookingProvider).status,
        BusBookingStatus.awaitingPayment,
      );
    });

    test(
        'confirmBooking creates a new order when seats changed since the held ticket',
        () async {
      final repo = FakeBusRepository(ticketResult: _pendingTicket());
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);
      await _prepareBooking(notifier);
      await notifier.confirmBooking();
      expect(repo.createTicketCallCount, 1);

      // Rider goes back, picks a different seat, confirms again.
      notifier.toggleSeat('16');
      notifier.toggleSeat('17');
      await notifier.confirmBooking();

      expect(repo.createTicketCallCount, 2);
    });
  });

  group('BusBookingNotifier progressive search', () {
    test('round 0 renders immediately and enters the polling phase', () async {
      final repo = FakeBusRepository(
        tripsPageQueue: [
          _page([_trip('a')]),
          _page([_trip('a'), _trip('b')]),
        ],
      );
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);

      final state = container.read(busBookingProvider);
      expect(state.trips.map((t) => t.id), ['a']);
      expect(state.searchPhase, BusSearchPhase.polling);
      expect(state.status, BusBookingStatus.idle);
    });

    test('trips found in later rounds are staged, not shown', () async {
      final repo = FakeBusRepository(
        tripsPageQueue: [
          _page([_trip('a')]),
          _page([_trip('a'), _trip('b')]),
        ],
      );
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      await pumpEventQueue();

      final state = container.read(busBookingProvider);
      expect(state.trips.map((t) => t.id), ['a']);
      expect(state.stagedTrips.map((t) => t.id), ['b']);
    });

    test('arrivals go straight in while nothing is on screen yet', () async {
      final repo = FakeBusRepository(
        tripsPageQueue: [
          _page([]),
          _page([_trip('a')]),
        ],
      );
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      await pumpEventQueue();

      final state = container.read(busBookingProvider);
      expect(state.trips.map((t) => t.id), ['a']);
      expect(state.stagedTrips, isEmpty);
    });

    test('a price change on a visible trip updates it in place', () async {
      final repo = FakeBusRepository(
        tripsPageQueue: [
          _page([_trip('a', price: 100)]),
          _page([_trip('a', price: 120)]),
        ],
      );
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      await pumpEventQueue();

      final state = container.read(busBookingProvider);
      expect(state.trips.single.priceStartWith, 120);
      expect(state.stagedTrips, isEmpty);
    });

    test('two quiet rounds settle the search as complete', () async {
      final repo = FakeBusRepository(tripsPage: _page([_trip('a')]));
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      await pumpEventQueue();

      final state = container.read(busBookingProvider);
      expect(state.searchPhase, BusSearchPhase.complete);
      // Round 0 plus the two quiet rounds — the third never runs.
      expect(repo.searchTripsCallCount, 3);
    });

    test('revealStagedTrips moves staged trips into the visible list',
        () async {
      final repo = FakeBusRepository(
        tripsPageQueue: [
          _page([_trip('a')]),
          _page([_trip('a'), _trip('b')]),
        ],
      );
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      await pumpEventQueue();
      notifier.revealStagedTrips();

      final state = container.read(busBookingProvider);
      expect(state.trips.map((t) => t.id), ['a', 'b']);
      expect(state.stagedTrips, isEmpty);
    });

    test('a schedule that keeps finding trips ends as exhausted', () async {
      final repo = FakeBusRepository(
        tripsPageQueue: [
          _page([_trip('a')]),
          _page([_trip('a'), _trip('b')]),
          _page([_trip('a'), _trip('b'), _trip('c')]),
          _page([_trip('a'), _trip('b'), _trip('c'), _trip('d')]),
        ],
      );
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      await pumpEventQueue();

      final state = container.read(busBookingProvider);
      expect(state.searchPhase, BusSearchPhase.exhausted);
      // Round 0 plus all three follow-ups; the queue never went quiet.
      expect(repo.searchTripsCallCount, 4);
      expect(state.stagedTrips.map((t) => t.id), ['b', 'c', 'd']);
    });

    test('a failed round does not count toward the quiet rule', () async {
      final repo = FakeBusRepository(tripsPage: _page([_trip('a')]))
        ..failingSearchCalls = {1};
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      await pumpEventQueue();

      final state = container.read(busBookingProvider);
      // Rounds 2 and 3 are the first two quiet ones, so the window runs out
      // rather than settling: the failure in between reset nothing.
      expect(state.searchPhase, BusSearchPhase.complete);
      expect(state.trips.map((t) => t.id), ['a']);
      expect(state.error, isNull);
      expect(state.status, BusBookingStatus.idle);
    });

    test('three consecutive failures end the window as exhausted', () async {
      final repo = FakeBusRepository(tripsPage: _page([_trip('a')]))
        ..failingSearchCalls = {1, 2, 3};
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      await pumpEventQueue();

      final state = container.read(busBookingProvider);
      expect(state.searchPhase, BusSearchPhase.exhausted);
      expect(state.trips.map((t) => t.id), ['a']);
      expect(state.error, isNull);
    });

    test('a failing round 0 keeps the existing error behaviour', () async {
      final repo = FakeBusRepository()..failingSearchCalls = {0};
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      await pumpEventQueue();

      final state = container.read(busBookingProvider);
      expect(state.status, BusBookingStatus.error);
      expect(state.searchPhase, BusSearchPhase.idle);
      expect(state.error, isNotNull);
      // No follow-up rounds were scheduled off a failed first call.
      expect(repo.searchTripsCallCount, 1);
    });
  });
}
