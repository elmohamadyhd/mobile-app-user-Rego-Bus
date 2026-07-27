import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/car/domain/entities/car_order.dart';
import 'package:safaria/features/car/domain/entities/car_place.dart';
import 'package:safaria/features/car/domain/entities/car_search_params.dart';
import 'package:safaria/features/car/presentation/providers/car_booking_providers.dart';

import '../fake_car_repository.dart';

void main() {
  const cairo = CarPlace(
    latitude: 30.03,
    longitude: 31.26,
    label: 'Cairo',
  );
  const alex = CarPlace(
    latitude: 31.18,
    longitude: 29.89,
    label: 'Alexandria',
  );

  CarSearchParams params({bool rounded = false}) => CarSearchParams(
        from: cairo,
        to: alex,
        rounded: rounded,
        departDate: DateTime(2026, 12, 20),
      );

  ProviderContainer makeContainer(FakeCarRepository repo) {
    return ProviderContainer(
      overrides: [
        carRepositoryProvider.overrideWithValue(repo),
      ],
    );
  }

  test('searchQuotes stores params and populates quotes', () async {
    final repo =
        FakeCarRepository(quotesResult: [FakeCarRepository.sampleQuote]);
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(carBookingProvider.notifier);
    await notifier.searchQuotes(params());

    final state = container.read(carBookingProvider);
    expect(state.searchParams, isNotNull);
    expect(state.quotes, hasLength(1));
    expect(state.selectedQuote?.id, FakeCarRepository.sampleQuote.id);
    expect(state.quotesError, isNull);
    expect(state.isLoadingQuotes, isFalse);
  });

  test('searchQuotes records 401 for guest gate handling', () async {
    final repo = FakeCarRepository()
      ..searchShouldThrow = true
      ..searchException = const ApiException('Unauthorized', statusCode: 401);
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(carBookingProvider.notifier);
    await notifier.searchQuotes(params());

    final state = container.read(carBookingProvider);
    expect(state.needsAuthRetry, isTrue);
    expect(state.quotes, isEmpty);
  });

  test('selectQuote stores selected trip id', () {
    final container = makeContainer(FakeCarRepository());
    addTearDown(container.dispose);

    const quote = FakeCarRepository.sampleQuote;
    container.read(carBookingProvider.notifier).selectQuote(quote);

    expect(
      container.read(carBookingProvider).selectedQuote?.id,
      quote.id,
    );
  });

  test('loadTripDetails replaces selectedQuote on success', () async {
    final repo =
        FakeCarRepository(tripResult: FakeCarRepository.refreshedQuote);
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(carBookingProvider.notifier);
    notifier.selectQuote(FakeCarRepository.sampleQuote);
    await notifier.loadTripDetails(1);

    final state = container.read(carBookingProvider);
    expect(repo.lastGetTripId, 1);
    expect(state.selectedQuote?.currency, 'EGP');
    expect(state.selectedQuote?.goPrice, 1000);
    expect(state.isLoadingTripDetails, isFalse);
    expect(state.tripDetailsHardError, isNull);
    expect(state.tripDetailsSoftError, isNull);
  });

  test('loadTripDetails sets hard error on 404 and keeps quote', () async {
    final repo = FakeCarRepository()
      ..getTripShouldThrow = true
      ..getTripException =
          const ApiException("This record can't be found", statusCode: 404);
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(carBookingProvider.notifier);
    notifier.selectQuote(FakeCarRepository.sampleQuote);
    await notifier.loadTripDetails(1);

    final state = container.read(carBookingProvider);
    expect(state.selectedQuote?.id, FakeCarRepository.sampleQuote.id);
    expect(state.tripDetailsHardError, isNotNull);
    expect(state.tripDetailsSoftError, isNull);
    expect(state.isLoadingTripDetails, isFalse);
  });

  test('loadTripDetails sets soft error on non-404 and keeps quote', () async {
    final repo = FakeCarRepository()
      ..getTripShouldThrow = true
      ..getTripException = const ApiException('Network error', statusCode: 500);
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(carBookingProvider.notifier);
    notifier.selectQuote(FakeCarRepository.sampleQuote);
    await notifier.loadTripDetails(1);

    final state = container.read(carBookingProvider);
    expect(state.selectedQuote?.id, FakeCarRepository.sampleQuote.id);
    expect(state.tripDetailsSoftError, isNotNull);
    expect(state.tripDetailsHardError, isNull);
  });

  test('clearTripDetailsErrors clears hard and soft flags', () async {
    final repo = FakeCarRepository()
      ..getTripShouldThrow = true
      ..getTripException = const ApiException('Network error', statusCode: 500);
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(carBookingProvider.notifier);
    notifier.selectQuote(FakeCarRepository.sampleQuote);
    await notifier.loadTripDetails(1);
    notifier.clearTripDetailsErrors();

    final state = container.read(carBookingProvider);
    expect(state.tripDetailsSoftError, isNull);
    expect(state.tripDetailsHardError, isNull);
  });

  test('createOrder sets awaitingPayment with invoice url', () async {
    final repo = FakeCarRepository();
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(carBookingProvider.notifier);
    await notifier.searchQuotes(params());
    await notifier.createOrder();

    final state = container.read(carBookingProvider);
    expect(repo.createCallCount, 1);
    expect(state.status, CarBookingStatus.awaitingPayment);
    expect(state.order?.invoiceUrl, isNotEmpty);
  });

  test('createOrder resumes without second API call when reusable', () async {
    const matchingOrder = CarOrder(
      id: 39,
      statusText: 'pending',
      statusKind: CarOrderStatusKind.pending,
      price: '1000.00',
      currency: 'EGP',
      rounded: false,
      from: CarOrderCoords(latitude: 30.03, longitude: 31.26),
      to: CarOrderCoords(latitude: 31.18, longitude: 29.89),
      trip: FakeCarRepository.sampleQuote,
      invoiceUrl: 'https://eg.myfatoorah.com/EGY/ia/sample',
      canBeCancel: true,
    );
    final repo = FakeCarRepository(orderResult: matchingOrder);
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(carBookingProvider.notifier);
    await notifier.searchQuotes(params());
    await notifier.createOrder();
    expect(repo.createCallCount, 1);

    await notifier.createOrder();
    expect(repo.createCallCount, 1);
    expect(
      container.read(carBookingProvider).status,
      CarBookingStatus.awaitingPayment,
    );
  });

  test('verifyPayment sets confirmed when order paid', () async {
    final repo = FakeCarRepository(
      orderResult: FakeCarRepository.sampleConfirmedOrder,
    );
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(carBookingProvider.notifier);
    await notifier.searchQuotes(params());
    await notifier.createOrder();
    // Force pending held order id, then verify returns confirmed.
    notifier.hydrateOrder(FakeCarRepository.samplePendingOrder);
    await notifier.verifyPayment();

    expect(
      container.read(carBookingProvider).status,
      CarBookingStatus.confirmed,
    );
  });

  test('verifyPayment sets paymentPending on lookup failure', () async {
    final repo = FakeCarRepository()..getOrderShouldThrow = true;
    final container = makeContainer(repo);
    addTearDown(container.dispose);

    final notifier = container.read(carBookingProvider.notifier);
    notifier.hydrateOrder(FakeCarRepository.samplePendingOrder);
    await notifier.verifyPayment();

    expect(
      container.read(carBookingProvider).status,
      CarBookingStatus.paymentPending,
    );
  });
}
