import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/flight/domain/entities/flight_order.dart';
import 'package:safaria/features/flight/presentation/flight_ticket_screen.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';

import '../fake_flight_repository.dart';

FlightOrder _unpaidOrder() => FlightOrder(
      id: '76',
      status: 'pending',
      orderStatus: 'PendingPayment',
      paymentStatus: 'pending',
      totalAmount: 37259,
      currency: 'EGP',
      checkoutUrl: 'https://pay.example/1',
      passengers: const [
        FlightOrderPassenger(
          id: 'p1',
          passengerTypeCode: 'ADT',
          firstName: 'Mona',
          lastName: 'Hassan',
        ),
      ],
      segments: [
        FlightOrderSegment(
          id: '1',
          origin: 'CAI',
          destination: 'RUH',
          departureDateTime: DateTime(2026, 8, 24, 15, 10),
          arrivalDateTime: DateTime(2026, 8, 24, 18, 5),
          marketingCarrierCode: 'XY',
          marketingFlightNumber: '264',
        ),
      ],
    );

FlightOrder _paidOrder() => _unpaidOrder().copyWith(
      orderStatus: 'Ticketed',
      paymentStatus: 'paid',
      airlinePnr: 'ABC123',
      gdsPnr: 'GDS999',
      checkoutUrl: null,
    );

Future<void> _pumpScreen(
  WidgetTester tester, {
  required FlightOrder order,
  Locale locale = const Locale('en'),
}) async {
  final repo = FakeFlightRepository();
  repo.orderResult = order;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        flightRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FlightTicketScreen(order: order),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('unpaid details show journey, traveller, and pay CTA',
      (tester) async {
    await _pumpScreen(tester, order: _unpaidOrder());

    expect(find.text('Order details'), findsOneWidget);
    expect(find.text('Cairo Intl Airport'), findsOneWidget);
    expect(find.text('King Khalid Intl Airport'), findsOneWidget);
    expect(find.textContaining('15:10'), findsOneWidget);
    expect(find.textContaining('XY264'), findsOneWidget);
    expect(find.text('Mona Hassan'), findsOneWidget);
    expect(find.text('Adult 1'), findsOneWidget);
    expect(find.text('Complete payment'), findsOneWidget);
    expect(find.text('Your booking is confirmed'), findsNothing);
  });

  testWidgets('paid details show confirmation, PNRs, and tickets CTA',
      (tester) async {
    await _pumpScreen(tester, order: _paidOrder());

    expect(find.text('Your booking is confirmed'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('GDS999'), findsOneWidget);
    expect(find.text('Booking reference'), findsOneWidget);
    expect(find.text('GDS reference'), findsOneWidget);
    expect(find.text('Go to My Tickets'), findsOneWidget);
    expect(find.text('Complete payment'), findsNothing);
  });

  testWidgets('details page is localized in Arabic', (tester) async {
    await _pumpScreen(
      tester,
      order: _unpaidOrder(),
      locale: const Locale('ar'),
    );

    expect(find.text('تفاصيل الطلب'), findsOneWidget);
    expect(find.text('المسافرين'), findsOneWidget);
  });
}
