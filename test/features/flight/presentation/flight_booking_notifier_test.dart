import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';

import '../fake_flight_repository.dart';

void main() {
  FlightSearchParams params() => FlightSearchParams(
        origin: 'CAI',
        destination: 'RUH',
        date: DateTime(2026, 9, 15),
        passengers: const [
          FlightPassengerCount(passengerTypeCode: 'ADT', count: 1),
        ],
        currency: 'EGP',
      );

  ProviderContainer makeContainer(FakeFlightRepository repo) {
    return ProviderContainer(
      overrides: [flightRepositoryProvider.overrideWithValue(repo)],
    );
  }

  test('search stores params and populates offers', () async {
    final repo = FakeFlightRepository(
      searchResult: [FakeFlightRepository.sampleOffer],
    );
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(flightBookingProvider.notifier);
    await notifier.search(params());

    final state = container.read(flightBookingProvider);
    expect(state.searchParams, isNotNull);
    expect(state.offers, hasLength(1));
    expect(state.status, FlightBookingStatus.idle);
    expect(state.error, isNull);
  });

  test('search clears previous offers and sets error status on failure',
      () async {
    final repo = FakeFlightRepository()..searchShouldThrow = true;
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(flightBookingProvider.notifier);
    await notifier.search(params());

    final state = container.read(flightBookingProvider);
    expect(state.status, FlightBookingStatus.error);
    expect(state.offers, isEmpty);
    expect(state.error, isNotNull);
  });

  test('search with empty results leaves offers empty without error',
      () async {
    final repo = FakeFlightRepository(searchResult: const []);
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(flightBookingProvider.notifier);
    await notifier.search(params());

    final state = container.read(flightBookingProvider);
    expect(state.status, FlightBookingStatus.idle);
    expect(state.offers, isEmpty);
  });

  test('setSearchLabels stores from/to labels', () {
    final container = makeContainer(FakeFlightRepository());
    addTearDown(container.dispose);

    container
        .read(flightBookingProvider.notifier)
        .setSearchLabels(from: 'CAI', to: 'RUH');

    final state = container.read(flightBookingProvider);
    expect(state.searchFromLabel, 'CAI');
    expect(state.searchToLabel, 'RUH');
  });
}
