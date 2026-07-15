import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/providers/bus_orders_provider.dart';

import '../fake_bus_repository.dart';

BusOrder _order({
  String orderId = '1475',
  BusOrderStatusKind statusKind = BusOrderStatusKind.pending,
  bool canCancel = true,
}) {
  return BusOrder(
    orderId: orderId,
    bookingNumber: '000001475',
    operatorName: 'SuperJet',
    category: 'Five stars',
    statusText: 'Pending',
    statusKind: statusKind,
    dateTimeLabel: '2026-07-30 08:45 AM',
    ticketLines: const [
      BusTicketLine(id: 2076, seatNumber: '1', price: '205.00'),
    ],
    total: 'EGP 219.35',
    canCancel: canCancel,
    gatewayCheckoutUrl: 'https://demo.MyFatoorah.com/pay',
    invoiceUrl: 'https://portal.wdenytravel.com/orders/1475/invoice',
    fare: const BusOrderFare(
      originalTicketsTotal: 'EGP 205.00',
      discount: 'EGP 0.00',
      walletDiscount: 'EGP 0.00',
      ticketsTotalAfterDiscount: 'EGP 205.00',
      paymentFees: 'EGP 14.35',
      total: 'EGP 219.35',
      currency: 'EGP',
    ),
  );
}

void main() {
  ProviderContainer makeContainer(FakeBusRepository repo) {
    final container = ProviderContainer(
      overrides: [busRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('BusOrdersNotifier', () {
    test('build loads orders from the repository', () async {
      final repo = FakeBusRepository(ordersResult: [_order()]);
      final container = makeContainer(repo);

      final orders = await container.read(busOrdersProvider.future);

      expect(orders, hasLength(1));
      expect(orders.first.orderId, '1475');
    });

    test('refresh re-fetches and replaces the list', () async {
      final repo = FakeBusRepository(ordersResult: [_order()]);
      final container = makeContainer(repo);
      await container.read(busOrdersProvider.future);

      repo.ordersResult = [_order(orderId: '9999')];
      await container.read(busOrdersProvider.notifier).refresh();

      final orders = container.read(busOrdersProvider).value;
      expect(orders, isNotNull);
      expect(orders!.single.orderId, '9999');
    });

    test('cancel calls the repository and refreshes on success', () async {
      final repo = FakeBusRepository(ordersResult: [_order()]);
      final container = makeContainer(repo);
      await container.read(busOrdersProvider.future);

      final success =
          await container.read(busOrdersProvider.notifier).cancel('1475');

      expect(success, isTrue);
      expect(repo.cancelOrderCalls, ['1475']);
    });

    test('cancel returns false and keeps the list on repository failure',
        () async {
      final repo = FakeBusRepository(ordersResult: [_order()])
        ..cancelOrderShouldThrow = true;
      final container = makeContainer(repo);
      await container.read(busOrdersProvider.future);

      final success =
          await container.read(busOrdersProvider.notifier).cancel('1475');

      expect(success, isFalse);
      final orders = container.read(busOrdersProvider).value;
      expect(orders, hasLength(1));
    });
  });
}
