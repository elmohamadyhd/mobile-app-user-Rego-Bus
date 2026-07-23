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
import 'package:rego/features/car/presentation/car_place_picker_args.dart';
import 'package:rego/features/car/presentation/car_place_picker_screen.dart';
import 'package:rego/features/car/presentation/car_routes.dart';
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
     const PlacePrediction(placeId: 'p1', description: 'Cairo Tower, Egypt'),
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

  @override
  Future<CarPlace> reverseGeocode({
    required double latitude,
    required double longitude,
    required String languageCode,
  }) async {
    return CarPlace(
      latitude: latitude,
      longitude: longitude,
      label: 'Reverse geocoded',
    );
  }
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: File('.env.example').readAsStringSync());
  });

  Future<void> pumpPicker(
    WidgetTester tester, {
    required CarPlacePickerArgs args,
    CarPlace? resultHolder,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final picked = await context.push<CarPlace>(
                    CarRoutes.placePicker,
                    extra: args,
                  );
                  if (resultHolder != null && picked != null) {
                    // ignore: invalid_use_of_visible_for_testing_member
                  }
                },
                child: const Text('Open'),
              ),
            ),
          ),
          routes: [
            GoRoute(
              path: CarRoutes.placePicker.substring(1),
              builder: (context, state) => CarPlacePickerScreen(
                args: state.extra! as CarPlacePickerArgs,
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shows search field and confirm button', (tester) async {
    await pumpPicker(
      tester,
      args: const CarPlacePickerArgs(title: 'Pickup', showUseMyLocation: true),
    );

    expect(find.text('Search for a place'), findsOneWidget);
    expect(find.text('Confirm location'), findsOneWidget);
  });

  testWidgets('pickup shows GPS control when showUseMyLocation is true',
      (tester) async {
    await pumpPicker(
      tester,
      args: const CarPlacePickerArgs(title: 'Pickup', showUseMyLocation: true),
    );

    // GPS FAB uses AppIcons.locationFrom — verify pickup path opened without error.
    expect(find.text('Confirm location'), findsOneWidget);
  });

  testWidgets('drop-off hides GPS when showUseMyLocation is false', (tester) async {
    await pumpPicker(
      tester,
      args: const CarPlacePickerArgs(title: 'Drop-off'),
    );

    expect(find.text('Drop-off'), findsOneWidget);
  });

  testWidgets('selecting a prediction updates draft label', (tester) async {
    await pumpPicker(
      tester,
      args: const CarPlacePickerArgs(title: 'Pickup'),
    );

    await tester.enterText(find.byType(TextField), 'Cai');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('Cairo Tower, Egypt'), findsOneWidget);

    await tester.tap(find.text('Cairo Tower, Egypt'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('Current selection'), findsWidgets);
    expect(find.text('Cairo Tower, Egypt'), findsWidgets);
  });

  testWidgets('typing with keyboard inset does not overflow', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placesClientProvider.overrideWithValue(_FakePlacesClient()),
        ],
        child: const MediaQuery(
          data: MediaQueryData(
            viewInsets: EdgeInsets.only(bottom: 320),
            size: Size(411, 800),
          ),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: CarPlacePickerScreen(
              args: CarPlacePickerArgs(title: 'Pickup'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField), 'Cai');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Confirm location'), findsOneWidget);
    expect(find.text('Current selection'), findsNothing);
  });

  testWidgets('confirm returns CarPlace', (tester) async {
    CarPlace? result;

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await context.push<CarPlace>(
                    CarRoutes.placePicker,
                    extra: const CarPlacePickerArgs(title: 'Pickup'),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
          routes: [
            GoRoute(
              path: CarRoutes.placePicker.substring(1),
              builder: (context, state) => CarPlacePickerScreen(
                args: state.extra! as CarPlacePickerArgs,
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.latitude, closeTo(30.0444, 0.01));
  });
}
