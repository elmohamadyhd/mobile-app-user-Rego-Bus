import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rego/core/places/place_prediction.dart';
import 'package:rego/core/places/places_client.dart';
import 'package:rego/core/places/places_providers.dart';
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
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
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
}
