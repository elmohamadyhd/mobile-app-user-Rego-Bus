import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_leg_badge.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_trip_summary_card.dart';
import 'package:safaria/l10n/app_localizations.dart';

FlightJourney _journey() {
  return FlightJourney(
    id: 'j1',
    origin: 'CDG',
    destination: 'CAI',
    numberOfStops: 1,
    segments: [
      FlightSegment(
        id: 's1',
        origin: 'CDG',
        destination: 'CAI',
        departureDateTime: DateTime(2026, 9, 3, 9),
        arrivalDateTime: DateTime(2026, 9, 3, 23, 45),
        flightTimeInMinutes: 315,
        operatingCarrierCode: 'OS',
        operatingFlightNumber: '1',
        marketingCarrierCode: 'OS',
        marketingFlightNumber: '1',
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: FlightTripSummaryCard(
          journey: _journey(),
          originLabel: 'All Airport',
          destinationLabel: 'Cairo Intl Airport',
          legLabel: 'Return',
          legKind: FlightLegKind.returning,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows airport names instead of raw IATA', (tester) async {
    await _pump(tester);
    expect(find.text('All Airport'), findsOneWidget);
    expect(find.text('Cairo Intl Airport'), findsOneWidget);
    expect(find.text('CDG'), findsNothing);
    expect(find.text('CAI'), findsNothing);
    expect(find.text('09:00 – 23:45'), findsOneWidget);
    expect(find.textContaining('1 stop'), findsOneWidget);
  });

  testWidgets('return pill uses landing icon and amber treatment',
      (tester) async {
    await _pump(tester);
    expect(find.text('Return'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.airplaneLanding), findsOneWidget);
  });

  testWidgets('airport names use primary text', (tester) async {
    await _pump(tester);
    final origin = tester.widget<Text>(find.text('All Airport'));
    expect(origin.style?.color, AppColors.textPrimary);
  });

  testWidgets('date sits in a chip beside the return pill', (tester) async {
    await _pump(tester);
    expect(find.text('Sep 3'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.calendarBlank), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.airplaneLanding), findsOneWidget);
  });
}
