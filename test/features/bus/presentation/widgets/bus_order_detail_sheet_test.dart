import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/widgets/bus_order_detail_sheet.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../../fake_bus_repository.dart';

BusOrder _seedOrder() => const BusOrder(
      orderId: '1475',
      bookingNumber: '000001475',
      operatorName: 'SuperJet',
      category: 'Five stars',
      statusText: 'Pending',
      statusKind: BusOrderStatusKind.pending,
      dateTimeLabel: '2026-07-30 08:45 AM',
      pickupStopLabel: 'Cairo Main Station',
      dropoffStopLabel: 'Alexandria Terminal',
      ticketLines: [BusTicketLine(id: 2076, seatNumber: '1', price: '205.00')],
      total: 'EGP 219.35',
      canCancel: true,
      gatewayCheckoutUrl: 'https://demo.MyFatoorah.com/pay',
      invoiceUrl: 'https://portal.wdenytravel.com/orders/1475/invoice',
      fare: BusOrderFare(
        originalTicketsTotal: 'EGP 205.00',
        discount: 'EGP 0.00',
        walletDiscount: 'EGP 0.00',
        ticketsTotalAfterDiscount: 'EGP 205.00',
        paymentFees: 'EGP 14.35',
        total: 'EGP 219.35',
        currency: 'EGP',
      ),
      paymentGateway: 'Myfatoorah',
      paymentStatusText: 'Pending',
      paymentInvoiceId: '6956732',
      tripId: '145261',
      gatewayOrderId: '5077099',
      tripType: 'Buses',
    );

Future<void> _pumpSheet(
  WidgetTester tester, {
  required FakeBusRepository repo,
  BusOrder? seed,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [busRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () =>
                  showBusOrderDetailSheet(context, seed ?? _seedOrder()),
              child: const Text('Open sheet'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open sheet'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('paints the seed immediately with no spinner', (tester) async {
    final repo = FakeBusRepository()
      ..orderByIdCompleter = Completer<BusOrder>();
    await _pumpSheet(tester, repo: repo);

    expect(find.text('SuperJet'), findsOneWidget);
    expect(find.text('EGP 219.35'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('replaces seed once the refresh call resolves', (tester) async {
    final completer = Completer<BusOrder>();
    final repo = FakeBusRepository()..orderByIdCompleter = completer;
    await _pumpSheet(tester, repo: repo);

    completer.complete(
      _seedOrder().copyWith(statusKind: BusOrderStatusKind.confirmed),
    );
    await tester.pumpAndSettle();

    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('keeps the seed when the refresh call fails', (tester) async {
    final repo = FakeBusRepository()..orderByIdShouldThrow = true;
    await _pumpSheet(tester, repo: repo);
    await tester.pumpAndSettle();

    expect(find.text('SuperJet'), findsOneWidget);
    expect(find.text('EGP 219.35'), findsWidgets);
  });

  testWidgets('hides zero-value discount rows', (tester) async {
    final repo = FakeBusRepository()
      ..orderByIdCompleter = Completer<BusOrder>();
    await _pumpSheet(tester, repo: repo);

    expect(find.text('Discount'), findsNothing);
    expect(find.text('Wallet discount'), findsNothing);
  });

  testWidgets('shows non-zero discount rows', (tester) async {
    final seed = _seedOrder().copyWith(
      fare: const BusOrderFare(
        originalTicketsTotal: 'EGP 250.00',
        discount: 'EGP 12.00',
        walletDiscount: 'EGP 5.00',
        ticketsTotalAfterDiscount: 'EGP 233.00',
        paymentFees: 'EGP 14.35',
        total: 'EGP 247.35',
        currency: 'EGP',
      ),
    );
    final repo = FakeBusRepository()
      ..orderByIdCompleter = Completer<BusOrder>();
    await _pumpSheet(tester, repo: repo, seed: seed);

    expect(find.text('Discount'), findsOneWidget);
    expect(find.text('EGP 12.00'), findsOneWidget);
    expect(find.text('Wallet discount'), findsOneWidget);
    expect(find.text('EGP 5.00'), findsOneWidget);
  });
}
