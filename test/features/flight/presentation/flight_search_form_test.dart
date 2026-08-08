import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/flight_search_form.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';

import '../fake_flight_repository.dart';

void main() {
  testWidgets('search CTA is disabled when airports are empty', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          flightRepositoryProvider.overrideWithValue(FakeFlightRepository()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(child: FlightSearchForm()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final opacityFinder = find.ancestor(
      of: find.text('Search flights'),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(opacityFinder).opacity, 0.6);
  });

  testWidgets('shows a snackbar when origin and destination are the same',
      (tester) async {
    const airport = FakeFlightRepository.sampleOrigin;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          flightRepositoryProvider.overrideWithValue(FakeFlightRepository()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: FlightSearchForm(
                initialOrigin: airport,
                initialDestination: airport,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search flights'));
    await tester.pump();

    expect(
      find.text('Origin and destination must be different'),
      findsOneWidget,
    );
  });

  testWidgets('search proceeds and pushes results when airports differ',
      (tester) async {
    final repo = FakeFlightRepository();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: SingleChildScrollView(
              child: FlightSearchForm(
                initialOrigin: FakeFlightRepository.sampleOrigin,
                initialDestination: FakeFlightRepository.sampleDestination,
              ),
            ),
          ),
        ),
        GoRoute(
          path: FlightRoutes.results,
          builder: (context, state) =>
              const Scaffold(body: Text('Flight results')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [flightRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search flights'));
    await tester.pumpAndSettle();

    expect(repo.lastSearchParams, isNotNull);
    expect(repo.lastSearchParams!.firstLeg.origin, 'CAI');
    expect(repo.lastSearchParams!.firstLeg.destination, 'RUH');
    expect(find.text('Flight results'), findsOneWidget);
  });
}
