import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:safaria/features/car/domain/entities/car_place.dart';
import 'package:safaria/features/car/domain/entities/car_search_params.dart';
import 'package:safaria/features/car/presentation/car_routes.dart';
import 'package:safaria/features/car/presentation/car_tier_results_screen.dart';
import 'package:safaria/features/car/presentation/providers/car_booking_providers.dart';
import 'package:safaria/features/car/presentation/widgets/car_trip_ticket_card.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

import '../fake_car_repository.dart';

void main() {
  const cairo = CarPlace(
    latitude: 30.03,
    longitude: 31.26,
    label: 'Cairo',
  );
  const alex = CarPlace(
    latitude: 31.18,
    longitude: 29.89,
    label: 'Alexandria',
  );

  final params = CarSearchParams(
    from: cairo,
    to: alex,
    rounded: false,
    departDate: DateTime(2026, 7, 31, 10, 30),
  );

  Future<(GoRouter, ProviderContainer)> pumpResults(
    WidgetTester tester,
  ) async {
    final repo = FakeCarRepository(
      quotesResult: [FakeCarRepository.sampleQuote],
    );
    final router = GoRouter(
      initialLocation: CarRoutes.results,
      routes: carRoutes(),
    );
    final container = ProviderContainer(
      overrides: [
        carRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );

    await container.read(carBookingProvider.notifier).searchQuotes(params);
    await tester.pumpAndSettle();
    return (router, container);
  }

  testWidgets('shows quote card and no Continue button', (tester) async {
    await pumpResults(tester);

    expect(find.byType(CarTripTicketCard), findsOneWidget);
    expect(find.text('Sky Travel'), findsOneWidget);
    expect(find.byType(PrimaryButton), findsNothing);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('tapping a quote card selects it and opens details',
      (tester) async {
    final (router, container) = await pumpResults(tester);

    await tester.tap(find.byType(CarTripTicketCard));
    await tester.pumpAndSettle();

    expect(
      container.read(carBookingProvider).selectedQuote?.id,
      FakeCarRepository.sampleQuote.id,
    );
    expect(router.state.uri.path, CarRoutes.details);
    expect(find.byType(CarTierResultsScreen), findsNothing);
  });
}
