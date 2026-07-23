import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rego/core/places/place_prediction.dart';
import 'package:rego/core/places/places_client.dart';
import 'package:rego/core/places/places_providers.dart';
import 'package:rego/features/car/domain/entities/car_place.dart';
import 'package:rego/features/car/presentation/widgets/car_place_picker_sheet.dart';
import 'package:rego/l10n/app_localizations.dart';

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
    if (input.length < 2) return const [];
    return [
      PlacePrediction(placeId: 'p1', description: 'Cairo Tower, Egypt'),
    ];
  }

  @override
  Future<CarPlace> placeDetails({
    required String placeId,
    required String languageCode,
    required String sessionToken,
  }) async {
    return const CarPlace(
      latitude: 30.045,
      longitude: 31.224,
      label: 'Cairo Tower, Egypt',
    );
  }
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: File('.env.example').readAsStringSync());
  });

  Future<void> pumpPickerHost(
    WidgetTester tester, {
    required Future<void> Function(BuildContext context) onOpen,
    bool showUseMyLocation = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placesClientProvider.overrideWithValue(_FakePlacesClient()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => onOpen(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('idle state shows quick actions without duplicate placeholder',
      (tester) async {
    await pumpPickerHost(
      tester,
      onOpen: (context) => showCarPlacePicker(
        context,
        title: 'Pickup',
        showUseMyLocation: true,
      ),
    );

    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Use my location'), findsOneWidget);
    expect(find.text('Adjust on map'), findsOneWidget);
    expect(find.text('Search for a place'), findsOneWidget);
  });

  testWidgets('drop-off picker hides use my location quick action',
      (tester) async {
    await pumpPickerHost(
      tester,
      onOpen: (context) => showCarPlacePicker(
        context,
        title: 'Drop-off',
        showUseMyLocation: false,
      ),
    );

    expect(find.text('Use my location'), findsNothing);
    expect(find.text('Adjust on map'), findsOneWidget);
  });

  testWidgets('selecting a prediction returns CarPlace', (tester) async {
    CarPlace? result;

    await pumpPickerHost(
      tester,
      onOpen: (context) async {
        result = await showCarPlacePicker(
          context,
          title: 'Pickup',
        );
      },
    );

    await tester.enterText(find.byType(TextField), 'Cai');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Cairo Tower, Egypt'), findsOneWidget);

    await tester.tap(find.text('Cairo Tower, Egypt'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.label, 'Cairo Tower, Egypt');
  });
}
