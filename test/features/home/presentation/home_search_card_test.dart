import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/core/config/app_config.dart';
import 'package:safaria/core/places/place_prediction.dart';
import 'package:safaria/core/places/places_client.dart';
import 'package:safaria/core/places/places_providers.dart';
import 'package:safaria/features/bus/domain/entities/bus_location.dart';
import 'package:safaria/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:safaria/features/car/presentation/providers/car_booking_providers.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/home/presentation/widgets/home_search_card.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/transport_mode_tab_bar.dart';

import '../../bus/fake_bus_repository.dart';
import '../../car/fake_car_repository.dart';
import '../../flight/fake_flight_repository.dart';

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

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      busRepositoryProvider.overrideWithValue(FakeBusRepository()),
      carRepositoryProvider.overrideWithValue(FakeCarRepository()),
      flightRepositoryProvider.overrideWithValue(FakeFlightRepository()),
      placesClientProvider.overrideWithValue(_FakePlacesClient()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: File('.env.example').readAsStringSync());
  });

  testWidgets('bus CTA is disabled when cities are empty', (tester) async {
    await tester.pumpWidget(
      _wrap(
        HomeSearchCard(
          selectedTab: TransportModeTabBar.busTabIndex,
          onTabChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final opacityFinder = find.ancestor(
      of: find.text('Search trips'),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(opacityFinder).opacity, 0.6);
  });

  testWidgets('bus CTA is enabled when both cities are set', (tester) async {
    await tester.pumpWidget(
      _wrap(
        HomeSearchCard(
          selectedTab: TransportModeTabBar.busTabIndex,
          onTabChanged: (_) {},
          initialFromCity: BusLocationDefaults.from,
          initialToCity: BusLocationDefaults.to,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final opacityFinder = find.ancestor(
      of: find.text('Search trips'),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(opacityFinder).opacity, 1.0);
  });

  testWidgets(
      'opening depart picker does not crash when cached travel date is '
      'stale (day rolled over)', (tester) async {
    final staleDate = DateTime.now().subtract(const Duration(days: 1));
    await tester.pumpWidget(
      _wrap(
        HomeSearchCard(
          selectedTab: TransportModeTabBar.busTabIndex,
          onTabChanged: (_) {},
          initialFromCity: BusLocationDefaults.from,
          initialToCity: BusLocationDefaults.to,
          initialTravelDate: staleDate,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Depart'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('updates To when parent passes a new toCity', (tester) async {
    BusLocation? reportedTo;
    final to = FakeBusRepository.sampleLocations[1];
    await tester.pumpWidget(
      _wrap(
        HomeSearchCard(
          selectedTab: TransportModeTabBar.busTabIndex,
          onTabChanged: (_) {},
          initialFromCity: FakeBusRepository.sampleLocations.first,
          toCity: null,
          onToCityChanged: (c) => reportedTo = c,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _wrap(
        HomeSearchCard(
          selectedTab: TransportModeTabBar.busTabIndex,
          onTabChanged: (_) {},
          initialFromCity: FakeBusRepository.sampleLocations.first,
          toCity: to,
          onToCityChanged: (c) => reportedTo = c,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(to.displayName('en')), findsOneWidget);
    expect(reportedTo, isNull);
  });

  testWidgets('private tab shows request-car CTA label', (tester) async {
    await tester.pumpWidget(
      _wrap(
        HomeSearchCard(
          selectedTab: TransportModeTabBar.privateTabIndex,
          onTabChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Request a car'), findsOneWidget);
    expect(find.text('Search trips'), findsNothing);
  });

  testWidgets('flight tab shows search-flights CTA label', (tester) async {
    await tester.pumpWidget(
      _wrap(
        HomeSearchCard(
          selectedTab: TransportModeTabBar.flightTabIndex,
          onTabChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search flights'), findsOneWidget);
    expect(find.text('Search trips'), findsNothing);
    expect(find.text('Request a car'), findsNothing);
  }, skip: !AppConfig.showFlights);

  testWidgets('flight tab no longer shows the coming-soon snackbar',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        HomeSearchCard(
          selectedTab: TransportModeTabBar.busTabIndex,
          onTabChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Flight'));
    await tester.pump();

    expect(find.text('Coming soon'), findsNothing);
  }, skip: !AppConfig.showFlights);

  testWidgets('hides the Flight tab when showFlights is off', (tester) async {
    await tester.pumpWidget(
      _wrap(
        HomeSearchCard(
          selectedTab: TransportModeTabBar.busTabIndex,
          onTabChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Flight'),
      AppConfig.showFlights ? findsOneWidget : findsNothing,
    );
  });
}
