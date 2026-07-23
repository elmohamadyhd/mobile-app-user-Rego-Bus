import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/car/domain/entities/car_place.dart';
import 'package:rego/features/car/domain/entities/car_search_params.dart';
import 'package:rego/features/car/presentation/providers/car_booking_providers.dart';

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

    final quote = FakeCarRepository.sampleQuote;
    container.read(carBookingProvider.notifier).selectQuote(quote);

    expect(
      container.read(carBookingProvider).selectedQuote?.id,
      quote.id,
    );
  });
}
