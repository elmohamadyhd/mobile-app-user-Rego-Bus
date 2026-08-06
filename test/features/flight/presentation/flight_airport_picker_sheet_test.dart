import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/flight/domain/entities/flight_airport_suggestion.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_airport_picker_sheet.dart';
import 'package:safaria/l10n/app_localizations.dart';

import '../fake_flight_repository.dart';

void main() {
  Future<void> pumpPickerHost(
    WidgetTester tester,
    FakeFlightRepository repo, {
    void Function(FlightAirportSuggestion?)? onPicked,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [flightRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  final picked =
                      await showFlightAirportPicker(context, title: 'From');
                  onPicked?.call(picked);
                },
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
  }

  testWidgets('does not search below the 2-character minimum', (tester) async {
    final repo = FakeFlightRepository();
    await pumpPickerHost(tester, repo);

    await tester.enterText(find.byType(TextField), 'C');
    await tester.pump(const Duration(milliseconds: 350));

    expect(repo.lastAirportTerm, isNull);
  });

  testWidgets('searches after debounce once minimum length is reached',
      (tester) async {
    final repo = FakeFlightRepository();
    await pumpPickerHost(tester, repo);

    await tester.enterText(find.byType(TextField), 'Dub');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(repo.lastAirportTerm, 'Dub');
    expect(find.text('Cairo Intl Airport'), findsOneWidget);
    expect(find.text('CAI'), findsOneWidget);
  });

  testWidgets('shows empty state when no airports match', (tester) async {
    final repo = FakeFlightRepository(airportSuggestionsResult: const []);
    await pumpPickerHost(tester, repo);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('No airports found'), findsOneWidget);
  });

  testWidgets('shows retry on error and retries the same term', (tester) async {
    final repo = FakeFlightRepository()
      ..airportSearchShouldThrow = true
      ..airportSearchException = const ApiException('Failed', statusCode: 500);
    await pumpPickerHost(tester, repo);

    await tester.enterText(find.byType(TextField), 'Dub');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);

    repo.airportSearchShouldThrow = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Cairo Intl Airport'), findsOneWidget);
  });

  testWidgets('returns tapped airport', (tester) async {
    FlightAirportSuggestion? picked;
    final repo = FakeFlightRepository();
    await pumpPickerHost(tester, repo, onPicked: (v) => picked = v);

    await tester.enterText(find.byType(TextField), 'Dub');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cairo Intl Airport'));
    await tester.pumpAndSettle();

    expect(picked?.iataCode, 'CAI');
  });
}
