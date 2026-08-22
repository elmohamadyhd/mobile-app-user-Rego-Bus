import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
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

FlightJourney _journey({
  required String id,
  required String origin,
  required String destination,
  required DateTime depart,
  required DateTime arrive,
  required int minutes,
  int stops = 0,
}) {
  return FlightJourney(
    id: id,
    origin: origin,
    destination: destination,
    numberOfStops: stops,
    segments: [
      FlightSegment(
        id: '$id-seg',
        origin: origin,
        destination: destination,
        departureDateTime: depart,
        arrivalDateTime: arrive,
        flightTimeInMinutes: minutes,
        operatingCarrierCode: 'OS',
        operatingCarrierName: 'Austrian',
        operatingFlightNumber: '1',
        marketingCarrierCode: 'OS',
        marketingFlightNumber: '1',
      ),
    ],
  );
}

final _roundTripOffer = FlightOffer(
  offerId: 'offer-rt',
  haveBundles: false,
  canBeHeld: true,
  refundability: 'NotRefundable',
  journeys: [
    _journey(
      id: 'out',
      origin: 'CAI',
      destination: 'CDG',
      depart: DateTime(2026, 9, 15, 13, 45),
      arrive: DateTime(2026, 9, 16, 6, 5),
      minutes: 335,
      stops: 1,
    ),
    _journey(
      id: 'ret',
      origin: 'CDG',
      destination: 'CAI',
      depart: DateTime(2026, 9, 22, 9),
      arrive: DateTime(2026, 9, 22, 23, 45),
      minutes: 315,
      stops: 1,
    ),
  ],
  totalAmount: 39241,
  taxesAmount: 0,
  baseAmount: 39241,
  discountAmount: 0,
  beforeDiscountAmount: 39241,
  serviceChargeAmount: 0,
  currency: 'EGP',
  priceClasses: [],
);

final _multiCityOffer = FlightOffer(
  offerId: 'offer-mc',
  haveBundles: false,
  canBeHeld: true,
  refundability: 'NotRefundable',
  journeys: [
    _journey(
      id: 'leg-1',
      origin: 'CAI',
      destination: 'CDG',
      depart: DateTime(2026, 9, 15, 10),
      arrive: DateTime(2026, 9, 15, 14),
      minutes: 240,
    ),
    _journey(
      id: 'leg-2',
      origin: 'CDG',
      destination: 'LHR',
      depart: DateTime(2026, 9, 18, 9),
      arrive: DateTime(2026, 9, 18, 10),
      minutes: 60,
    ),
  ],
  totalAmount: 12000,
  taxesAmount: 0,
  baseAmount: 12000,
  discountAmount: 0,
  beforeDiscountAmount: 12000,
  serviceChargeAmount: 0,
  currency: 'EGP',
  priceClasses: [],
);

Future<void> _pump(
  WidgetTester tester, {
  bool rtl = false,
  VoidCallback? onSelect,
  FlightOffer? offer,
  FlightTripType tripType = FlightTripType.oneWay,
  List<FlightSearchLeg> searchLegs = const [],
  Map<String, String> airportNames = const {},
  String? originLabel = 'Cairo International Airport',
  String? destinationLabel = 'King Khalid International Airport',
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale(rtl ? 'ar' : 'en'),
      home: Scaffold(
        body: FlightOfferCard(
          offer: offer ?? _offer,
          originLabel: originLabel,
          destinationLabel: destinationLabel,
          tripType: tripType,
          searchLegs: searchLegs,
          airportNames: airportNames,
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

  testWidgets('airport names use primary text, not muted chrome',
      (tester) async {
    await _pump(tester);

    final origin = tester.widget<Text>(
      find.text('Cairo International Airport'),
    );
    expect(origin.style?.color, AppColors.textPrimary);
    expect(origin.style?.fontWeight, FontWeight.w700);

    final destination = tester.widget<Text>(
      find.text('King Khalid International Airport'),
    );
    expect(destination.style?.color, AppColors.textPrimary);
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

  testWidgets('round-trip return shows airport names, not IATA codes',
      (tester) async {
    await _pump(
      tester,
      offer: _roundTripOffer,
      tripType: FlightTripType.roundTrip,
      originLabel: 'Cairo Intl Airport',
      destinationLabel: 'All Airport',
    );

    expect(find.text('Cairo Intl Airport'), findsNWidgets(2));
    expect(find.text('All Airport'), findsNWidgets(2));
    expect(find.text('CDG'), findsNothing);
    expect(find.text('CAI'), findsNothing);
    expect(find.text('Outbound'), findsOneWidget);
    expect(find.text('Return'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.airplaneTakeoff), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.airplaneLanding), findsOneWidget);
  });

  testWidgets('multi-city later legs show airport names, not IATA codes',
      (tester) async {
    await _pump(
      tester,
      offer: _multiCityOffer,
      tripType: FlightTripType.multiCity,
      originLabel: 'Cairo Intl Airport',
      destinationLabel: 'Heathrow',
      searchLegs: [
        FlightSearchLeg(
          origin: 'CAI',
          destination: 'CDG',
          date: DateTime(2026, 9, 15),
        ),
        FlightSearchLeg(
          origin: 'CDG',
          destination: 'LHR',
          date: DateTime(2026, 9, 18),
        ),
      ],
      airportNames: const {
        'CAI': 'Cairo Intl Airport',
        'CDG': 'Charles de Gaulle',
        'LHR': 'Heathrow',
      },
    );

    expect(find.text('Cairo Intl Airport'), findsOneWidget);
    expect(find.text('Charles de Gaulle'), findsNWidgets(2));
    expect(find.text('Heathrow'), findsOneWidget);
    expect(find.text('CDG'), findsNothing);
    expect(find.text('LHR'), findsNothing);
    expect(find.text('CAI'), findsNothing);
  });
}
