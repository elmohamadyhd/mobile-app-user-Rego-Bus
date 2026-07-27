import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/features/car/domain/entities/car_order.dart';
import 'package:safaria/features/car/presentation/providers/car_booking_providers.dart';

class CarOrdersNotifier extends AsyncNotifier<List<CarOrder>> {
  @override
  Future<List<CarOrder>> build() {
    return ref.read(carRepositoryProvider).listOrders();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(carRepositoryProvider).listOrders(),
    );
  }

  Future<bool> cancel(int orderId) async {
    try {
      await ref.read(carRepositoryProvider).cancelOrder(orderId);
    } catch (_) {
      return false;
    }
    await refresh();
    return true;
  }
}

final carOrdersProvider =
    AsyncNotifierProvider<CarOrdersNotifier, List<CarOrder>>(
  CarOrdersNotifier.new,
);

/// Freshness fetch for the order detail sheet — seeded from the list card.
final carOrderDetailProvider =
    FutureProvider.autoDispose.family<CarOrder, int>((ref, orderId) {
  return ref.read(carRepositoryProvider).getOrder(orderId);
});
