import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_passenger_row.dart';
import 'package:safaria/l10n/app_localizations.dart';

Future<void> _pump(WidgetTester tester, FlightPassengerDraft draft) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: FlightPassengerRow(
          draft: draft,
          ordinal: 2,
          onTap: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('names the first missing field rather than a bare warning',
      (tester) async {
    const draft = FlightPassengerDraft(
      type: FlightPassengerType.adult,
      title: 'MR',
      firstName: 'Ahmed',
      lastName: 'Mostafa',
      gender: 'M',
      nationalityCode: 'EGY',
      residenceCode: 'EGY',
    );
    await _pump(tester, draft);
    expect(find.text('Missing date of birth'), findsOneWidget);
  });

  testWidgets('shows the traveller name once complete', (tester) async {
    final draft = FlightPassengerDraft(
      type: FlightPassengerType.adult,
      title: 'MR',
      firstName: 'Ahmed',
      lastName: 'Mostafa',
      gender: 'M',
      birthDate: DateTime(1990, 1, 2),
      documentNumber: '29001021234567',
      nationalityCode: 'EGY',
      residenceCode: 'EGY',
      addressCountryCode: 'EG',
      addressCityCode: 'CAI',
      addressLine1: '12 Tahrir St',
      addressLine2: 'Downtown',
    );
    await _pump(tester, draft);
    expect(find.text('Ahmed Mostafa'), findsOneWidget);
  });

  testWidgets('labels an empty draft by its slot', (tester) async {
    const draft = FlightPassengerDraft(type: FlightPassengerType.child);
    await _pump(tester, draft);
    expect(find.text('Child 2'), findsOneWidget);
  });
}
