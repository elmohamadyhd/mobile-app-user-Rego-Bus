import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/trip_details_screen.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../fake_bus_repository.dart';

BusTripSummary _buildTrip() {
  final board = BusStop(
    locationId: 'b1',
    name: 'Ramsis',
    cityId: 1,
    cityName: 'Cairo',
    arrivalAt: DateTime(2026, 2, 10, 8),
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
    finalPrice: 150,
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
    boardingStops: [board],
    dropoffStops: [dropDefault, dropAlt],
  );
}

Future<ProviderContainer> _pumpDetails(
  WidgetTester tester,
  BusTripSummary trip, {
  Locale locale = const Locale('en'),
}) async {
  final container = ProviderContainer(
    overrides: [
      busRepositoryProvider
          .overrideWithValue(FakeBusRepository(tripByIdResult: trip)),
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
      // Ramsis/Sidi Gaber are the selected pair, so they render both in the
      // header's compact time line and in the RouteTimeline below.
      expect(find.text('Ramsis'), findsOneWidget);
      expect(find.text('Sidi Gaber'), findsOneWidget);
      // Moharam Bek is the unselected alternate drop-off, shown only in the
      // RouteTimeline.
      expect(find.text('Moharam Bek'), findsOneWidget);
      expect(find.text('Choose seats'), findsOneWidget);
      // Default segment fare (Sidi Gaber, 180) shown in the timeline row +
      // footer.
      expect(find.textContaining('180', findRichText: true), findsWidgets);
    },
  );

  testWidgets(
    'selecting an alternate drop-off stop updates the live fare',
    (tester) async {
      await _pumpDetails(tester, _buildTrip());

      // Sidi Gaber's own row fare + the footer total both read 180.
      expect(find.textContaining('180', findRichText: true), findsNWidgets(2));

      final altStop = find.text('Moharam Bek');
      await tester.ensureVisible(altStop);
      await tester.pumpAndSettle();
      // A single tap on a drop-off row selects it directly.
      await tester.tap(altStop);
      await tester.pumpAndSettle();

      // Moharam Bek's own row fare + the new footer total both read 150.
      expect(find.textContaining('150', findRichText: true), findsNWidgets(2));
      // Sidi Gaber's row still shows its own fare even though it's no
      // longer selected — only the footer total moved off 180.
      expect(find.textContaining('180', findRichText: true), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the amenity icons opens the labeled amenities sheet',
    (tester) async {
      await _pumpDetails(tester, _buildTrip());

      expect(find.text('Amenities'), findsNothing);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
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
}
