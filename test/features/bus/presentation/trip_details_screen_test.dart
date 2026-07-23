import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/trip_details_screen.dart';
import 'package:rego/features/bus/presentation/widgets/trip_route_map_fab.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../fake_bus_repository.dart';
import '../../../support/in_memory_secure_storage.dart';

BusTripSummary _buildTrip() {
  final board = BusStop(
    locationId: 'b1',
    name: 'Ramsis',
    cityId: 1,
    cityName: 'Cairo',
    arrivalAt: DateTime(2026, 2, 10, 8),
    latitude: 30.06,
    longitude: 31.24,
  );
  final boardAlt = BusStop(
    locationId: 'b2',
    name: 'Sekka Club',
    cityId: 1,
    cityName: 'Cairo',
    arrivalAt: DateTime(2026, 2, 10, 7, 45),
    latitude: 30.05,
    longitude: 31.23,
  );
  final dropDefault = BusStop(
    locationId: 'd1',
    name: 'Sidi Gaber',
    cityId: 2,
    cityName: 'Alexandria',
    arrivalAt: DateTime(2026, 2, 10, 11, 30),
    finalPrice: 180,
  );
  final dropAlt = BusStop(
    locationId: 'd2',
    name: 'Moharam Bek',
    cityId: 2,
    cityName: 'Alexandria',
    arrivalAt: DateTime(2026, 2, 10, 12),
    finalPrice: 250,
  );
  return BusTripSummary(
    id: 'trip-1',
    gatewayId: 'gw',
    operatorName: 'Go Bus',
    category: 'VIP',
    dateTime: DateTime(2026, 2, 10, 8),
    currency: 'EGP',
    availableSeats: 6,
    priceStartWith: 180,
    defaultBoardingStop: board,
    defaultDropoffStop: dropDefault,
    boardingStops: [boardAlt, board],
    dropoffStops: [dropDefault, dropAlt],
  );
}

Future<ProviderContainer> _pumpDetails(
  WidgetTester tester,
  BusTripSummary trip, {
  Locale locale = const Locale('en'),
  bool coachSeen = true,
}) async {
  final storage = SecureStorage(storage: InMemorySecureStorage({}));
  if (coachSeen) {
    await storage.setTripDetailsCoachSeen();
  }
  final container = ProviderContainer(
    overrides: [
      busRepositoryProvider
          .overrideWithValue(FakeBusRepository(tripByIdResult: trip)),
      secureStorageProvider.overrideWithValue(storage),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: const BusTripDetailsScreen(),
      ),
    ),
  );
  await container.read(busBookingProvider.notifier).selectTrip(trip);
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets(
    'renders the trip header, route timeline and footer fare',
    (tester) async {
      await _pumpDetails(tester, _buildTrip());

      expect(find.textContaining('Go Bus', findRichText: true), findsWidgets);
      expect(find.text('Trip route'), findsOneWidget);
      // Ramsis/Moharam Bek are the selected pair (last drop-off by default).
      expect(find.text('Ramsis'), findsOneWidget);
      expect(find.text('Moharam Bek'), findsOneWidget);
      // Sidi Gaber is the unselected alternate drop-off in the RouteTimeline.
      expect(find.text('Sidi Gaber'), findsOneWidget);
      expect(find.text('Choose seats'), findsOneWidget);
      // Default segment fare (Moharam Bek, 250) shown in the timeline row +
      // footer.
      expect(find.textContaining('250', findRichText: true), findsWidgets);
    },
  );

  testWidgets(
    'selecting an alternate drop-off stop updates the live fare',
    (tester) async {
      await _pumpDetails(tester, _buildTrip());

      // Moharam Bek's own row fare + the footer total both read 250.
      expect(find.textContaining('250', findRichText: true), findsNWidgets(2));

      final altStop = find.text('Sidi Gaber');
      await tester.ensureVisible(altStop);
      await tester.pumpAndSettle();
      // A single tap on a drop-off row selects it directly.
      await tester.tap(altStop);
      await tester.pumpAndSettle();

      // Sidi Gaber's own row fare + the new footer total both read 180.
      expect(find.textContaining('180', findRichText: true), findsNWidgets(2));
      // Moharam Bek's row still shows its own fare even though it's no
      // longer selected — only the footer total moved off 250.
      expect(find.textContaining('250', findRichText: true), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the amenity icons opens the labeled amenities sheet',
    (tester) async {
      await _pumpDetails(tester, _buildTrip());

      expect(find.text('Amenities'), findsNothing);

      await tester.tap(find.byIcon(AppIcons.chevronDown));
      await tester.pumpAndSettle();

      expect(find.text('Amenities'), findsOneWidget);
      expect(find.text('Wi-Fi'), findsOneWidget);
    },
  );

  testWidgets('renders in RTL (Arabic)', (tester) async {
    await _pumpDetails(tester, _buildTrip(), locale: const Locale('ar'));

    expect(find.text('مسار الرحلة'), findsOneWidget); // Trip route
    expect(find.text('اختر المقاعد'), findsOneWidget); // Choose seats
  });

  testWidgets('shows the map FAB on the route card', (tester) async {
    await _pumpDetails(tester, _buildTrip());

    expect(find.byIcon(AppIcons.map), findsOneWidget);
  });

  testWidgets('tapping the map FAB shows the Google Maps confirmation dialog',
      (tester) async {
    await _pumpDetails(tester, _buildTrip());

    final fab = find.byIcon(AppIcons.map);
    await tester.ensureVisible(fab);
    await tester.pumpAndSettle();
    await tester.tap(fab);
    await tester.pumpAndSettle();

    expect(find.text('Open in Google Maps?'), findsOneWidget);
    expect(
      find.text(
        "You'll leave REGO. Google Maps will show the full trip route "
        'through every stop on this journey.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('cancelling the Google Maps dialog stays on trip details',
      (tester) async {
    await _pumpDetails(tester, _buildTrip());

    final fab = find.byIcon(AppIcons.map);
    await tester.ensureVisible(fab);
    await tester.pumpAndSettle();
    await tester.tap(fab);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Open in Google Maps?'), findsNothing);
    expect(find.text('Trip route'), findsOneWidget);
  });

  testWidgets('confirming the dialog invokes the external launcher', (
    tester,
  ) async {
    Uri? launchedUri;
    final boarding = [
      BusStop(
        locationId: 'b1',
        name: 'Sekka Club',
        cityId: 1,
        cityName: 'Cairo',
        arrivalAt: DateTime(2026, 2, 10, 7, 45),
        latitude: 30.05,
        longitude: 31.23,
      ),
      BusStop(
        locationId: 'b2',
        name: 'Ramsis',
        cityId: 1,
        cityName: 'Cairo',
        arrivalAt: DateTime(2026, 2, 10, 8),
        latitude: 30.06,
        longitude: 31.24,
      ),
    ];
    final dropoff = [
      BusStop(
        locationId: 'd1',
        name: 'Sidi Gaber',
        cityId: 2,
        cityName: 'Alexandria',
        arrivalAt: DateTime(2026, 2, 10, 11, 30),
        latitude: 31.16,
        longitude: 29.90,
      ),
      BusStop(
        locationId: 'd2',
        name: 'Moharam Bek',
        cityId: 2,
        cityName: 'Alexandria',
        arrivalAt: DateTime(2026, 2, 10, 12),
        latitude: 31.17,
        longitude: 29.91,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: TripRouteMapFab(
            boardingStops: boarding,
            dropoffStops: dropoff,
            launchUrl: (uri) async {
              launchedUri = uri;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.map));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Google Maps'));
    await tester.pumpAndSettle();

    expect(launchedUri, isNotNull);
    expect(launchedUri!.host, 'www.google.com');
    expect(launchedUri!.queryParameters['origin'], '30.05,31.23');
    expect(launchedUri!.queryParameters['destination'], '31.17,29.91');
    expect(
      launchedUri!.queryParameters['waypoints'],
      '30.06,31.24|31.16,29.9',
    );
  });

  group('coach tour', () {
    testWidgets('does not show coach when already seen', (tester) async {
      await _pumpDetails(tester, _buildTrip(), coachSeen: true);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Choose your stops'), findsNothing);
    });

    testWidgets('shows first coach step when not seen', (tester) async {
      await _pumpDetails(tester, _buildTrip(), coachSeen: false);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Choose your stops'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('skip marks coach seen and dismisses overlay', (tester) async {
      final container = await _pumpDetails(
        tester,
        _buildTrip(),
        coachSeen: false,
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Skip'));
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Choose your stops'), findsNothing);
      expect(
        await container.read(secureStorageProvider).tripDetailsCoachSeen(),
        isTrue,
      );
    });

    testWidgets('advances through all three coach steps', (tester) async {
      await _pumpDetails(tester, _buildTrip(), coachSeen: false);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Choose your stops'), findsOneWidget);

      await _tapCoachPrimary(tester);
      expect(find.text('View the full route'), findsOneWidget);

      await _tapCoachPrimary(tester);
      expect(find.text('View a stop on the map'), findsOneWidget);

      await _tapCoachPrimary(tester, label: 'Got it');
      await tester.pumpAndSettle();
      expect(find.text('View a stop on the map'), findsNothing);
    });

    testWidgets('shows help button when coach already seen', (tester) async {
      await _pumpDetails(tester, _buildTrip(), coachSeen: true);
      await tester.pumpAndSettle();

      expect(find.byIcon(AppIcons.help), findsOneWidget);
    });

    testWidgets('tap help restarts the coach tour', (tester) async {
      await _pumpDetails(tester, _buildTrip(), coachSeen: true);
      await tester.pumpAndSettle();

      expect(find.text('Choose your stops'), findsNothing);

      await tester.tap(
        find.ancestor(
          of: find.byIcon(AppIcons.help),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Choose your stops'), findsOneWidget);
    });

    testWidgets('help button is disabled while coach is showing',
        (tester) async {
      await _pumpDetails(tester, _buildTrip(), coachSeen: false);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Choose your stops'), findsOneWidget);

      final helpButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(AppIcons.help),
          matching: find.byType(IconButton),
        ),
      );
      expect(helpButton.onPressed, isNull);
    });
  });
}

Future<void> _tapCoachPrimary(
  WidgetTester tester, {
  String label = 'Next',
}) async {
  final button = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}
