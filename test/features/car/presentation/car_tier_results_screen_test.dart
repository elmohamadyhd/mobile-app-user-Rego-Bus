import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/car/domain/entities/car_place.dart';
import 'package:safaria/features/car/domain/entities/car_search_params.dart';
import 'package:safaria/features/car/presentation/car_tier_results_screen.dart';
import 'package:safaria/features/car/presentation/providers/car_booking_providers.dart';
import 'package:safaria/features/car/presentation/widgets/car_tier_card.dart';
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
    departDate: DateTime(2026, 7, 31),
  );

  Future<void> pumpResults(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carRepositoryProvider.overrideWithValue(
            FakeCarRepository(quotesResult: [FakeCarRepository.sampleQuote]),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: CarTierResultsScreen(),
        ),
      ),
    );

    final ctx = tester.element(find.byType(CarTierResultsScreen));
    await ProviderScope.containerOf(ctx)
        .read(carBookingProvider.notifier)
        .searchQuotes(params);
    await tester.pumpAndSettle();
  }

  testWidgets('shows quote card and no Continue button', (tester) async {
    await pumpResults(tester);

    expect(find.byType(CarTierCard), findsOneWidget);
    expect(find.text('Sky Travel'), findsOneWidget);
    expect(find.byType(PrimaryButton), findsNothing);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('tapping a card shows details coming soon snackbar',
      (tester) async {
    await pumpResults(tester);

    await tester.tap(find.byType(CarTierCard));
    await tester.pump();

    expect(find.text('Details coming soon'), findsOneWidget);
  });
}
