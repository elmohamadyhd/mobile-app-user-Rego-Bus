import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:safaria/core/location/device_location_gateway.dart';
import 'package:safaria/core/places/place_prediction.dart';
import 'package:safaria/core/places/places_client.dart';
import 'package:safaria/core/places/places_providers.dart';
import 'package:safaria/features/car/domain/entities/car_place.dart';
import 'package:safaria/features/car/presentation/car_routes.dart';
import 'package:safaria/features/car/presentation/car_search_form.dart';
import 'package:safaria/features/car/presentation/providers/car_booking_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/models/map_place.dart';

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

  @override
  Future<MapPlace> reverseGeocode({
    required double latitude,
    required double longitude,
    required String languageCode,
  }) async {
    return MapPlace(
      latitude: latitude,
      longitude: longitude,
      label: 'My current location',
    );
  }
}

DeviceLocationGateway _deniedLocationGateway({
  VoidCallback? onRequest,
}) {
  return DeviceLocationGateway(
    checkPermission: () async => LocationPermission.denied,
    requestPermission: () async {
      onRequest?.call();
      return LocationPermission.denied;
    },
    getCurrentPosition: () async => throw StateError('no gps in test'),
  );
}

DeviceLocationGateway _grantedLocationGateway() {
  return DeviceLocationGateway(
    checkPermission: () async => LocationPermission.whileInUse,
    requestPermission: () async => LocationPermission.whileInUse,
    getCurrentPosition: () async => Position(
      latitude: 30.05,
      longitude: 31.25,
      timestamp: DateTime(2026),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    ),
  );
}

ProviderScope _carFormScope({
  required Widget child,
  FakeCarRepository? repo,
  DeviceLocationGateway? location,
}) {
  return ProviderScope(
    overrides: [
      carRepositoryProvider.overrideWithValue(repo ?? FakeCarRepository()),
      placesClientProvider.overrideWithValue(_FakePlacesClient()),
      deviceLocationGatewayProvider.overrideWithValue(
        location ?? _deniedLocationGateway(),
      ),
    ],
    child: child,
  );
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: File('.env.example').readAsStringSync());
  });

  testWidgets('validation blocks search when places missing', (tester) async {
    await tester.pumpWidget(
      _carFormScope(
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

    final opacityFinder = find.ancestor(
      of: find.text('Request a car'),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(opacityFinder).opacity, 0.6);

    await tester.tap(find.text('Request a car'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Select pickup and drop-off'), findsNothing);
  });

  testWidgets(
      'prefills pickup from current location when permission already granted',
      (tester) async {
    await tester.pumpWidget(
      _carFormScope(
        location: _grantedLocationGateway(),
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

    expect(find.text('My current location'), findsOneWidget);
    expect(find.text('Search for a place'), findsOneWidget);
  });

  testWidgets('does not request location permission just by showing the form',
      (tester) async {
    var requestCalls = 0;
    await tester.pumpWidget(
      _carFormScope(
        location: _deniedLocationGateway(
          onRequest: () {
            requestCalls++;
          },
        ),
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

    expect(requestCalls, 0);
    expect(find.text('Search for a place'), findsNWidgets(2));
  });

  testWidgets('one-way shows date and time on one horizontal row',
      (tester) async {
    await tester.pumpWidget(
      _carFormScope(
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

    final timeLabel = find.text('Time');
    final departLabel = find.text('Depart');
    expect(timeLabel, findsOneWidget);
    expect(departLabel, findsOneWidget);

    final dy =
        (tester.getCenter(timeLabel).dy - tester.getCenter(departLabel).dy)
            .abs();
    expect(dy, lessThan(24),
        reason: 'date and time labels should share one row');
  });

  testWidgets(
      'opening depart picker does not crash when cached travel date is '
      'stale (day rolled over)', (tester) async {
    final staleDate = DateTime.now().subtract(const Duration(days: 1));
    await tester.pumpWidget(
      _carFormScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CarSearchForm(initialTravelDate: staleDate),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final departValueFinder = find.descendant(
      of: find
          .ancestor(
            of: find.text('Depart'),
            matching: find.byType(Column),
          )
          .first,
      matching: find.byType(InkWell),
    );
    await tester.tap(departValueFinder.first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('search proceeds when pickup and drop-off differ',
      (tester) async {
    final repo = FakeCarRepository();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              child: CarSearchForm(
                initialFrom: const CarPlace(
                  latitude: 30.0626,
                  longitude: 31.3219,
                  label: 'Nasr City, Cairo',
                ),
                initialTo: const CarPlace(
                  latitude: 31.2001,
                  longitude: 29.9187,
                  label: 'Alexandria',
                ),
                initialTravelDate: DateTime.now().add(const Duration(days: 1)),
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
      _carFormScope(
        repo: repo,
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
    expect(repo.lastSearchParams, isNotNull);
    expect(repo.lastSearchParams!.departDate.hour, isNot(0));
  });
}
