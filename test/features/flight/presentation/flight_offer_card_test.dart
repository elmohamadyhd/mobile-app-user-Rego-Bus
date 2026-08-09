import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_offer_card.dart';
import 'package:safaria/l10n/app_localizations.dart';

final _offer = FlightOffer(
  offerId: 'offer-1',
  haveBundles: false,
  canBeHeld: true,
  refundability: 'NotRefundable',
  journeys: [
    FlightJourney(
      id: 'journey-1',
      origin: 'CAI',
      destination: 'RUH',
      numberOfStops: 0,
      segments: [
        FlightSegment(
          id: 'segment-1',
          origin: 'CAI',
          destination: 'RUH',
          departureDateTime: DateTime(2026, 9, 15, 10, 50),
          arrivalDateTime: DateTime(2026, 9, 15, 13, 35),
          flightTimeInMinutes: 165,
          operatingCarrierCode: 'XY',
          operatingCarrierName: 'Flight Operations Services',
          operatingFlightNumber: '264',
          marketingCarrierCode: 'XY',
          marketingFlightNumber: '264',
        ),
      ],
    ),
  ],
  totalAmount: 7601,
  taxesAmount: 3141.88,
  baseAmount: 4459.12,
  discountAmount: 0,
  beforeDiscountAmount: 7601,
  serviceChargeAmount: 0,
  currency: 'EGP',
  priceClasses: [],
);

Future<void> _pump(
  WidgetTester tester, {
  bool rtl = false,
  VoidCallback? onSelect,
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale(rtl ? 'ar' : 'en'),
      home: Scaffold(
        body: FlightOfferCard(
          offer: _offer,
          originLabel: 'Cairo International Airport',
          destinationLabel: 'King Khalid International Airport',
          onSelect: onSelect ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders times, direct label, and price', (tester) async {
    await _pump(tester);

    expect(find.text('10:50'), findsOneWidget);
    expect(find.text('13:35'), findsOneWidget);
    expect(find.text('Cairo International Airport'), findsOneWidget);
    expect(find.text('King Khalid International Airport'), findsOneWidget);
    expect(find.text('CAI'), findsNothing);
    expect(find.text('RUH'), findsNothing);
    expect(find.text('Direct'), findsOneWidget);
    expect(find.text('2h 45m'), findsOneWidget);
    expect(find.textContaining('7601'), findsOneWidget);
    expect(find.textContaining('EGP'), findsOneWidget);
    expect(find.text('Details'), findsNothing);
    expect(find.text('Select this flight'), findsOneWidget);
  });

  testWidgets('calls onSelect from the select button', (tester) async {
    var selected = false;
    await _pump(tester, onSelect: () => selected = true);

    await tester.tap(find.text('Select this flight'));
    expect(selected, isTrue);
  });

  testWidgets('calls onSelect when the card body is tapped', (tester) async {
    var selected = false;
    await _pump(tester, onSelect: () => selected = true);

    await tester.tap(find.text('10:50'));
    expect(selected, isTrue);
  });

  testWidgets('renders under Arabic/RTL locale without crashing',
      (tester) async {
    await _pump(tester, rtl: true);
    expect(tester.takeException(), isNull);
    expect(find.text('Cairo International Airport'), findsOneWidget);
  });
}
