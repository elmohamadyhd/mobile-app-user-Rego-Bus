import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/core/places/place_prediction.dart';
import 'package:safaria/core/places/places_client.dart';
import 'package:safaria/core/places/places_providers.dart';
import 'package:safaria/core/theme/app_theme.dart';
import 'package:safaria/features/auth/domain/entities/auth_session.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:safaria/features/car/presentation/providers/car_booking_providers.dart';
import 'package:safaria/features/home/presentation/home_screen.dart';
import 'package:safaria/l10n/app_localizations.dart';

import '../../bus/fake_bus_repository.dart';
import '../../car/fake_car_repository.dart';

class _FakeSessionController extends SessionController {
  _FakeSessionController(this._initial);
  final AuthSession? _initial;

  @override
  Future<AuthSession?> build() async => _initial;
}

class _FakeGuestController extends GuestController {
  _FakeGuestController(this._value);
  final bool _value;

  @override
  Future<bool> build() async => _value;
}

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

Future<void> _pumpHome(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(
          () => _FakeSessionController(const AuthSession(token: 't')),
        ),
        guestModeProvider.overrideWith(() => _FakeGuestController(true)),
        busRepositoryProvider.overrideWithValue(FakeBusRepository()),
        carRepositoryProvider.overrideWithValue(FakeCarRepository()),
        placesClientProvider.overrideWithValue(_FakePlacesClient()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        locale: const Locale('en'),
        home: const Scaffold(body: HomeScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: File('.env.example').readAsStringSync());
  });

  testWidgets('popular tap fills To on bus tab', (tester) async {
    await _pumpHome(tester);

    expect(find.text('Popular destinations'), findsOneWidget);
    expect(find.text('Alexandria'), findsOneWidget);

    await tester.ensureVisible(find.text('Alexandria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alexandria'));
    await tester.pumpAndSettle();

    expect(find.text('Alexandria'), findsNWidgets(2));
  });

  testWidgets('section hidden on car tab', (tester) async {
    await _pumpHome(tester);

    expect(find.text('Popular destinations'), findsOneWidget);

    await tester.tap(find.text('Private'));
    await tester.pumpAndSettle();

    expect(find.text('Popular destinations'), findsNothing);
  });
}
