import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/bus/domain/entities/bus_location.dart';
import 'package:safaria/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:safaria/features/home/presentation/widgets/popular_destinations.dart';
import 'package:safaria/l10n/app_localizations.dart';

import '../../bus/fake_bus_repository.dart';

void main() {
  testWidgets('renders nothing when not visible', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          busRepositoryProvider.overrideWithValue(FakeBusRepository()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: PopularDestinations(
              visible: false,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Popular destinations'), findsNothing);
  });

  testWidgets('lists location names when visible', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          busRepositoryProvider.overrideWithValue(FakeBusRepository()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: PopularDestinations(
              visible: true,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Popular destinations'), findsOneWidget);
    expect(find.text('Cairo'), findsWidgets);
  });

  testWidgets('tap selects city; same as exclude is ignored', (tester) async {
    final selected = <BusLocation>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          busRepositoryProvider.overrideWithValue(FakeBusRepository()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: PopularDestinations(
              visible: true,
              excludeCityId: 1,
              onSelected: selected.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cairo').first);
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    await tester.tap(find.text('Alexandria').first);
    await tester.pumpAndSettle();
    expect(selected.single.id, 2);
  });
}
