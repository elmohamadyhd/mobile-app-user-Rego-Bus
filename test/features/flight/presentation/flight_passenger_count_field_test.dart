import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_passenger_count_field.dart';
import 'package:safaria/l10n/app_localizations.dart';

Future<void> _pump(
  WidgetTester tester,
  FlightPassengerCounts counts,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: FlightPassengerCountSheet(
          initial: counts,
          onApply: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('states why infants cannot be added', (tester) async {
    await _pump(tester, const FlightPassengerCounts(adults: 2, infants: 2));
    expect(find.text('One infant per adult'), findsOneWidget);
  });

  testWidgets('states why no more passengers fit', (tester) async {
    await _pump(tester, const FlightPassengerCounts(adults: 5, children: 4));
    expect(find.text('9 passengers maximum'), findsOneWidget);
  });

  testWidgets('shows the running total', (tester) async {
    await _pump(tester, const FlightPassengerCounts(adults: 2, children: 1));
    expect(find.text('3 of 9'), findsOneWidget);
  });

  testWidgets('adding a child raises the total', (tester) async {
    await _pump(tester, const FlightPassengerCounts(adults: 1));
    await tester.tap(find.byKey(const Key('flight-pax-add-child')));
    await tester.pump();
    expect(find.text('2 of 9'), findsOneWidget);
  });
}
