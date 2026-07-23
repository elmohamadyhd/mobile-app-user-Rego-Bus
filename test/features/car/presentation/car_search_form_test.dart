import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rego/core/places/place_prediction.dart';
import 'package:rego/core/places/places_client.dart';
import 'package:rego/core/places/places_providers.dart';
import 'package:rego/features/car/domain/entities/car_place.dart';
import 'package:rego/features/car/presentation/car_routes.dart';
import 'package:rego/features/car/presentation/car_search_form.dart';
import 'package:rego/features/car/presentation/providers/car_booking_providers.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../fake_car_repository.dart';

class _FakePlacesClient extends PlacesClient {
  _FakePlacesClient() : super(apiKey: 'test');

  @override
  bool get isConfigured => true;

  @override
  Future<List<PlacePrediction>> autocomplete({
    required String input,
    required String languageCode,
    required String sessionToken,
  }) async {
    return const [];
  }
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: File('.env.example').readAsStringSync());
  });

  testWidgets('validation blocks search when places missing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carRepositoryProvider.overrideWithValue(FakeCarRepository()),
          placesClientProvider.overrideWithValue(_FakePlacesClient()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(child: CarSearchForm()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search for a place'), findsNWidgets(2));
    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('Drop-off'), findsOneWidget);

    await tester.tap(find.text('Request a car'));
    await tester.pumpAndSettle();

    expect(find.text('Select pickup and drop-off'), findsOneWidget);
  });

  testWidgets('search proceeds when pickup and drop-off differ', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: SingleChildScrollView(
              child: CarSearchForm(
                initialFrom: CarPlace(
                  latitude: 30.0626,
                  longitude: 31.3219,
                  label: 'Nasr City, Cairo',
                ),
                initialTo: CarPlace(
                  latitude: 31.2001,
                  longitude: 29.9187,
                  label: 'Alexandria',
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: CarRoutes.results,
          builder: (context, state) =>
              const Scaffold(body: Text('Car results')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carRepositoryProvider.overrideWithValue(FakeCarRepository()),
          placesClientProvider.overrideWithValue(_FakePlacesClient()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Request a car'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Pickup and drop-off must be different'), findsNothing);
    expect(find.text('Select pickup and drop-off'), findsNothing);
  });
}
