import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';

void main() {
  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  group('BusBookingNotifier', () {
    test('initial state is idle with empty trips and no selection', () {
      final container = makeContainer();
      final state = container.read(busBookingProvider);
      expect(state.status, BusBookingStatus.idle);
      expect(state.trips, isEmpty);
      expect(state.selectedTrip, isNull);
      expect(state.selectedSeats, isEmpty);
      expect(state.ticket, isNull);
    });

    test(
        'searchTrips sets status to loadingTrips then idle and populates trips',
        () async {
      final container = makeContainer();
      final notifier = container.read(busBookingProvider.notifier);

      await notifier.searchTrips('Cairo', 'Alexandria', '2026-06-30');

      final state = container.read(busBookingProvider);
      expect(state.status, BusBookingStatus.idle);
      expect(state.trips, isNotEmpty);
      expect(state.trips.length, 3);
    });

    test('selectTrip sets selectedTrip and loads tripDetail', () async {
      final container = makeContainer();
      final notifier = container.read(busBookingProvider.notifier);

      await notifier.searchTrips('Cairo', 'Alexandria', '2026-06-30');
      final trip = container.read(busBookingProvider).trips.first;
      await notifier.selectTrip(trip);

      final state = container.read(busBookingProvider);
      expect(state.selectedTrip, trip);
      expect(state.tripDetail, isNotNull);
      expect(state.tripDetail!.summary.id, trip.id);
    });

    test('selectTrip resets selectedSeats', () async {
      final container = makeContainer();
      final notifier = container.read(busBookingProvider.notifier);

      await notifier.searchTrips('Cairo', 'Alexandria', '2026-06-30');
      final trip = container.read(busBookingProvider).trips.first;
      await notifier.selectTrip(trip);
      notifier.toggleSeat('A2');

      expect(container.read(busBookingProvider).selectedSeats, contains('A2'));

      // Select a different trip
      final trip2 = container.read(busBookingProvider).trips[1];
      await notifier.selectTrip(trip2);

      expect(container.read(busBookingProvider).selectedSeats, isEmpty);
    });

    test('toggleSeat adds a seat when not selected', () async {
      final container = makeContainer();
      final notifier = container.read(busBookingProvider.notifier);

      await notifier.searchTrips('Cairo', 'Alexandria', '2026-06-30');
      final trip = container.read(busBookingProvider).trips.first;
      await notifier.selectTrip(trip);

      notifier.toggleSeat('A2');

      expect(container.read(busBookingProvider).selectedSeats, contains('A2'));
    });

    test('toggleSeat removes a seat when already selected', () async {
      final container = makeContainer();
      final notifier = container.read(busBookingProvider.notifier);

      await notifier.searchTrips('Cairo', 'Alexandria', '2026-06-30');
      final trip = container.read(busBookingProvider).trips.first;
      await notifier.selectTrip(trip);

      notifier.toggleSeat('A2');
      notifier.toggleSeat('A2');

      expect(container.read(busBookingProvider).selectedSeats,
          isNot(contains('A2')));
    });

    test('setPaymentMethod updates paymentMethod', () {
      final container = makeContainer();
      final notifier = container.read(busBookingProvider.notifier);

      notifier.setPaymentMethod(PaymentMethod.card);

      expect(container.read(busBookingProvider).paymentMethod,
          PaymentMethod.card);
    });

    test(
        'confirmBooking produces BusTicket with RG- prefix and sets status to confirmed',
        () async {
      final container = makeContainer();
      final notifier = container.read(busBookingProvider.notifier);

      await notifier.searchTrips('Cairo', 'Alexandria', '2026-06-30');
      final trip = container.read(busBookingProvider).trips.first;
      await notifier.selectTrip(trip);
      notifier.toggleSeat('A2');
      await notifier.confirmBooking();

      final state = container.read(busBookingProvider);
      expect(state.status, BusBookingStatus.confirmed);
      expect(state.ticket, isNotNull);
      expect(state.ticket!.bookingRef, startsWith('RG-'));
      expect(state.ticket!.seats, contains('A2'));
    });

    test('reset clears all state back to initial', () async {
      final container = makeContainer();
      final notifier = container.read(busBookingProvider.notifier);

      await notifier.searchTrips('Cairo', 'Alexandria', '2026-06-30');
      notifier.reset();

      final state = container.read(busBookingProvider);
      expect(state.status, BusBookingStatus.idle);
      expect(state.trips, isEmpty);
      expect(state.selectedTrip, isNull);
    });
  });
}
