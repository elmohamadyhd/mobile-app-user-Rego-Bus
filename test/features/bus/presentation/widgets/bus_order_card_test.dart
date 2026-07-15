import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/presentation/widgets/bus_order_card.dart';
import 'package:rego/l10n/app_localizations.dart';

BusOrder _order({
  BusOrderStatusKind statusKind = BusOrderStatusKind.pending,
  bool canCancel = true,
  String? gatewayCheckoutUrl = 'https://demo.MyFatoorah.com/pay',
  String? invoiceUrl = 'https://portal.wdenytravel.com/orders/1475/invoice',
  String? pickupStopLabel = 'Cairo Main Station',
  String? dropoffStopLabel = 'Alexandria Terminal',
}) {
  return BusOrder(
    orderId: '1475',
    bookingNumber: '000001475',
    operatorName: 'SuperJet',
    category: 'Five stars',
    statusText: 'Pending',
    statusKind: statusKind,
    dateTimeLabel: '2026-07-30 08:45 AM',
    pickupStopLabel: pickupStopLabel,
    dropoffStopLabel: dropoffStopLabel,
    seats: const ['1', '2'],
    total: 'EGP 219.35',
    canCancel: canCancel,
    gatewayCheckoutUrl: gatewayCheckoutUrl,
    invoiceUrl: invoiceUrl,
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  BusOrder order, {
  VoidCallback? onPay,
  VoidCallback? onOpenETicket,
  VoidCallback? onCancel,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: BusOrderCard(
          order: order,
          onPay: onPay ?? () {},
          onOpenETicket: onOpenETicket ?? () {},
          onCancel: onCancel ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders operator, route stops, ref and total', (tester) async {
    await _pumpCard(tester, _order());

    expect(find.text('SuperJet'), findsOneWidget);
    expect(find.text('Cairo Main Station'), findsOneWidget);
    expect(find.text('Alexandria Terminal'), findsOneWidget);
    expect(find.text('#000001475'), findsOneWidget);
    expect(find.text('EGP 219.35'), findsOneWidget);
    expect(find.text('Five stars'), findsNothing);
    expect(find.text('1, 2'), findsNothing);
  });

  testWidgets('hides stop rows when station labels are absent', (tester) async {
    await _pumpCard(
      tester,
      _order(pickupStopLabel: null, dropoffStopLabel: null),
    );

    expect(find.text('From'), findsNothing);
    expect(find.text('To'), findsNothing);
    expect(find.text('EGP 219.35'), findsOneWidget);
  });

  testWidgets('pending order with checkout url shows Complete payment',
      (tester) async {
    var tapped = 0;
    await _pumpCard(tester, _order(), onPay: () => tapped++);

    final payButton = find.text('Complete payment');
    expect(payButton, findsOneWidget);

    await tester.tap(payButton);
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('confirmed order hides Complete payment', (tester) async {
    await _pumpCard(
      tester,
      _order(statusKind: BusOrderStatusKind.confirmed, canCancel: false),
    );

    expect(find.text('Complete payment'), findsNothing);
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('cancellable order shows Cancel and invokes onCancel',
      (tester) async {
    var tapped = 0;
    await _pumpCard(tester, _order(), onCancel: () => tapped++);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('order with no invoice hides the download action',
      (tester) async {
    await _pumpCard(tester, _order(invoiceUrl: null, canCancel: false));

    expect(find.text('Download'), findsNothing);
    expect(find.text('Complete payment'), findsOneWidget);
  });
}
