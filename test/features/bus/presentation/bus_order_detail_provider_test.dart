import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/providers/bus_orders_provider.dart';

import '../fake_bus_repository.dart';

void main() {
  ProviderContainer makeContainer(FakeBusRepository repo) {
    final container = ProviderContainer(
      overrides: [busRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('busOrderDetailProvider', () {
    test('fetches the order by id from the repository', () async {
      final repo = FakeBusRepository(
        orderByIdResult: FakeBusRepository.sampleOrder,
      );
      final container = makeContainer(repo);

      final order =
          await container.read(busOrderDetailProvider('1475').future);

      expect(order.orderId, '1475');
      expect(repo.orderByIdCalls, ['1475']);
    });

    test('surfaces a repository failure as a provider error', () async {
      final repo = FakeBusRepository()..orderByIdShouldThrow = true;
      final container = makeContainer(repo);

      await expectLater(
        container.read(busOrderDetailProvider('1475').future),
        throwsA(anything),
      );
    });
  });
}
