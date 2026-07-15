import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';

/// Owns the "My Tickets" list of booked bus trips. A plain
/// `AsyncNotifierProvider` (not autoDispose) so state survives switching
/// bottom-nav tabs, matching `busBookingProvider`/`sessionControllerProvider`.
class BusOrdersNotifier extends AsyncNotifier<List<BusOrder>> {
  @override
  Future<List<BusOrder>> build() {
    return ref.read(busRepositoryProvider).listOrders();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(busRepositoryProvider).listOrders(),
    );
  }

  /// Cancels [orderId] and refreshes the list. Returns whether it succeeded
  /// so the caller can show the right toast.
  Future<bool> cancel(String orderId) async {
    try {
      await ref.read(busRepositoryProvider).cancelOrder(orderId);
    } catch (_) {
      return false;
    }
    await refresh();
    return true;
  }
}

final busOrdersProvider =
    AsyncNotifierProvider<BusOrdersNotifier, List<BusOrder>>(
  BusOrdersNotifier.new,
);

/// Fetches one order by id for the order detail sheet. `autoDispose` because
/// it's sheet-scoped (unlike the tab-lifetime `busOrdersProvider`) — closing
/// the sheet frees it, and reopening always re-fetches fresh.
final busOrderDetailProvider =
    FutureProvider.autoDispose.family<BusOrder, String>(
  (ref, orderId) => ref.read(busRepositoryProvider).orderById(orderId),
);
