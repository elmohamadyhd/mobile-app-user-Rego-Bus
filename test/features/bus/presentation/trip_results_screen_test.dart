import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/features/bus/domain/entities/bus_search_params.dart';
import 'package:safaria/features/bus/domain/entities/bus_trip.dart';
import 'package:safaria/features/bus/domain/repositories/bus_repository.dart';
import 'package:safaria/features/bus/presentation/bus_routes.dart';
import 'package:safaria/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:safaria/features/bus/presentation/trip_results_screen.dart';
import 'package:safaria/features/bus/presentation/widgets/active_filter_chips.dart';
import 'package:safaria/features/bus/presentation/widgets/new_trips_pill.dart';
import 'package:safaria/features/bus/presentation/widgets/trip_card.dart';
import 'package:safaria/features/bus/presentation/widgets/trip_search_status_strip.dart';
import 'package:safaria/l10n/app_localizations.dart';

import '../fake_bus_repository.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Repository whose `tripById` never resolves until [detailCompleter]
/// completes — used to hold the notifier in `loadingDetail` so the test can
/// inspect the mid-flight card state.
class _DelayedTripRepository extends FakeBusRepository {
  _DelayedTripRepository({required this.detailCompleter, super.tripsPage});

  final Completer<BusTripSummary> detailCompleter;

  @override
  Future<BusTripSummary> tripById(
    String tripId, {
    required String currency,
  }) =>
      detailCompleter.future;
}

Future<void> _pumpResultsWithTrips(
  WidgetTester tester,
  List<BusTripSummary> trips,
) async {
  final repo = FakeBusRepository(
    tripsPage: BusTripsPage(trips: trips, currentPage: 1, lastPage: 1),
  );

  final router = GoRouter(
    initialLocation: BusRoutes.results,
    routes: [
      GoRoute(
        path: BusRoutes.results,
        builder: (context, state) => const TripResultsScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [busRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        routerConfig: router,
      ),
    ),
  );

  final container = ProviderScope.containerOf(
    tester.element(find.byType(TripResultsScreen)),
  );
  await container.read(busBookingProvider.notifier).searchTrips(
        BusSearchParams(
          cityFromId: 1,
          cityToId: 2,
          date: DateTime(2026, 7, 10),
        ),
      );
  await tester.pumpAndSettle();
}

/// Pumps the results screen with a queue of successive search rounds and a
/// zero-length gap, so the progressive window runs inside the test.
Future<ProviderContainer> _pumpResultsWithRounds(
  WidgetTester tester,
  List<List<BusTripSummary>> rounds, {
  Duration gap = Duration.zero,
}) async {
  final repo = FakeBusRepository(
    tripsPageQueue: [
      for (final trips in rounds)
        BusTripsPage(trips: trips, currentPage: 1, lastPage: 1),
    ],
  );

  final router = GoRouter(
    initialLocation: BusRoutes.results,
    routes: [
      GoRoute(
        path: BusRoutes.results,
        builder: (context, state) => const TripResultsScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        busRepositoryProvider.overrideWithValue(repo),
        busSearchScheduleProvider.overrideWithValue(
          BusSearchSchedule(gap: gap),
        ),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        routerConfig: router,
      ),
    ),
  );

  final container = ProviderScope.containerOf(
    tester.element(find.byType(TripResultsScreen)),
  );
  await container.read(busBookingProvider.notifier).searchTrips(
        BusSearchParams(
          cityFromId: 1,
          cityToId: 2,
          date: DateTime(2026, 7, 10),
        ),
      );
  // One frame for round 0. Do not settle: a polling strip or empty-list
  // skeleton animates forever, and a zero gap would otherwise finish the
  // window before the "still running" assertions can see it.
  await tester.pump();
  return container;
}

void main() {
  testWidgets(
    'tapping a trip spins only that card; the rest of the list stays usable',
    (tester) async {
      final tripA = FakeBusRepository.sampleTrip;
      final tripB = tripA.copyWith(
        id: 'other-trip',
        operatorName: 'Blue Bus',
        // Later departure keeps tripA first under the default Times sort,
        // so the tapped card is deterministically `cards.first`.
        dateTime: tripA.dateTime.add(const Duration(minutes: 30)),
      );
      final detailCompleter = Completer<BusTripSummary>();
      final repo = _DelayedTripRepository(
        detailCompleter: detailCompleter,
        tripsPage:
            BusTripsPage(trips: [tripA, tripB], currentPage: 1, lastPage: 1),
      );

      final router = GoRouter(
        initialLocation: BusRoutes.results,
        routes: [
          GoRoute(
            path: BusRoutes.results,
            builder: (context, state) => const TripResultsScreen(),
          ),
          GoRoute(
            path: BusRoutes.detail,
            builder: (context, state) =>
                const Scaffold(body: Text('Trip detail')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [busRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TripResultsScreen)),
      );
      await container.read(busBookingProvider.notifier).searchTrips(
            BusSearchParams(
              cityFromId: 1,
              cityToId: 2,
              date: DateTime(2026, 7, 10),
            ),
          );
      await tester.pumpAndSettle();

      final cards = find.byType(TripCard);
      expect(cards, findsNWidgets(2));

      // Tap Select on the first card — card center can hit the stops chip.
      await tester.tap(find.descendant(
        of: cards.first,
        matching: find.text('Select'),
      ));
      // Don't pumpAndSettle: the tapped card's spinner animates forever
      // while enrichment is in flight.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final tappedCard = tester.widget<TripCard>(cards.first);
      final otherCard = tester.widget<TripCard>(cards.last);
      expect(tappedCard.loading, isTrue);
      expect(otherCard.loading, isFalse);

      // Still on results — navigation waits for selection to resolve.
      expect(find.text('Trip detail'), findsNothing);

      detailCompleter.complete(tripA);
      await tester.pumpAndSettle();

      expect(find.text('Trip detail'), findsOneWidget);
    },
  );

  testWidgets('filter button opens filter sheet', (tester) async {
    final tripA = FakeBusRepository.sampleTrip;
    final tripB = tripA.copyWith(
      id: 'other-trip',
      operatorName: 'Blue Bus',
      dateTime: tripA.dateTime.add(const Duration(hours: 2)),
    );
    await _pumpResultsWithTrips(tester, [tripA, tripB]);

    await tester.tap(find.byIcon(PhosphorIconsLight.fadersHorizontal));
    await tester.pumpAndSettle();

    expect(find.text('Filter trips'), findsOneWidget);
    expect(find.text('Highlights'), findsOneWidget);
    expect(find.text('Cheapest'), findsWidgets);
    expect(find.text('Fastest'), findsWidgets);
    // Card behind the sheet + operator chip in the sheet both show the name.
    expect(find.text('Blue Bus'), findsAtLeastNWidgets(1));
  });

  testWidgets('cheapest filter narrows list but badges remain after clear', (
    tester,
  ) async {
    final tripA = FakeBusRepository.sampleTrip;
    final expensiveDrop = tripA.dropoffStops.last.copyWith(finalPrice: 400);
    final tripB = tripA.copyWith(
      id: 'other-trip',
      operatorName: 'Blue Bus',
      dateTime: tripA.dateTime.add(const Duration(hours: 2)),
      dropoffStops: [
        tripA.dropoffStops.first,
        expensiveDrop,
      ],
      defaultDropoffStop: expensiveDrop,
    );
    await _pumpResultsWithTrips(tester, [tripA, tripB]);
    expect(find.byType(TripCard), findsNWidgets(2));
    // Same duration → cheapest trip gets both pills; other stays fastest-only.
    expect(
      find.descendant(
        of: find.byType(TripCard),
        matching: find.text('Cheapest'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(TripCard),
        matching: find.text('Fastest'),
      ),
      findsWidgets,
    );
    expect(find.text('Best deal'), findsNothing);

    await tester.tap(find.byIcon(PhosphorIconsLight.fadersHorizontal));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(SwitchListTile).first,
        matching: find.byType(Switch),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.byType(TripCard), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TripCard),
        matching: find.text('Cheapest'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(TripCard),
        matching: find.text('Fastest'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ActiveFilterChips),
        matching: find.text('Cheapest'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(ActiveFilterChips),
        matching: find.text('Cheapest'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TripCard), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(TripCard),
        matching: find.text('Cheapest'),
      ),
      findsOneWidget,
    );
    expect(find.text('Best deal'), findsNothing);
  });

  testWidgets('applying operator filter shows chip and narrows list', (
    tester,
  ) async {
    final tripA = FakeBusRepository.sampleTrip;
    final tripB = tripA.copyWith(
      id: 'other-trip',
      operatorName: 'Blue Bus',
      dateTime: tripA.dateTime.add(const Duration(hours: 2)),
    );
    await _pumpResultsWithTrips(tester, [tripA, tripB]);
    expect(find.byType(TripCard), findsNWidgets(2));

    await tester.tap(find.byIcon(PhosphorIconsLight.fadersHorizontal));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Bus').last);
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.byType(ActiveFilterChips), findsOneWidget);
    expect(find.byType(TripCard), findsOneWidget);
  });

  testWidgets('removing active filter chip restores filtered trips', (
    tester,
  ) async {
    final tripA = FakeBusRepository.sampleTrip;
    final tripB = tripA.copyWith(
      id: 'other-trip',
      operatorName: 'Blue Bus',
      dateTime: tripA.dateTime.add(const Duration(hours: 2)),
    );
    await _pumpResultsWithTrips(tester, [tripA, tripB]);

    await tester.tap(find.byIcon(PhosphorIconsLight.fadersHorizontal));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Bus').last);
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.byType(TripCard), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(ActiveFilterChips),
        matching: find.text('Blue Bus'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ActiveFilterChips), findsNothing);
    expect(find.byType(TripCard), findsNWidgets(2));
  });

  testWidgets('the strip reports the search is still running', (tester) async {
    await _pumpResultsWithRounds(
      tester,
      [
        [FakeBusRepository.sampleTrip],
      ],
      // A pending follow-up must not fire: this assertion is about the
      // in-flight strip, not about later rounds completing.
      gap: const Duration(days: 1),
    );

    expect(find.byType(TripSearchStatusStrip), findsOneWidget);
    expect(find.text('Looking for more trips…'), findsOneWidget);
  });

  testWidgets('an empty list while polling shows the skeleton, not "no trips"',
      (tester) async {
    await _pumpResultsWithRounds(
      tester,
      [[]],
      gap: const Duration(days: 1),
    );

    expect(find.text('No trips found'), findsNothing);
  });

  testWidgets('staged trips reveal themselves while the rider is at the top',
      (tester) async {
    final tripA = FakeBusRepository.sampleTrip;
    final tripB = tripA.copyWith(
      id: 'trip-b',
      operatorName: 'Blue Bus',
      dateTime: tripA.dateTime.add(const Duration(minutes: 30)),
    );

    final container = await _pumpResultsWithRounds(tester, [
      [tripA],
      [tripA, tripB],
    ]);
    await tester.pumpAndSettle();

    // The rider never scrolled, so nothing they are reading can move.
    expect(container.read(busBookingProvider).stagedTrips, isEmpty);
    expect(find.byType(TripCard), findsNWidgets(2));
    expect(find.byType(NewTripsPill), findsNothing);
  });

  testWidgets('a scrolled rider gets the pill instead of a moving list',
      (tester) async {
    final base = FakeBusRepository.sampleTrip;
    final many = [
      for (var i = 0; i < 12; i++)
        base.copyWith(
          id: 'trip-$i',
          dateTime: base.dateTime.add(Duration(minutes: 30 * i)),
        ),
    ];
    // Not named `late` — that is a Dart keyword and will not compile.
    final lateArrival = base.copyWith(
      id: 'trip-late',
      operatorName: 'Blue Bus',
      dateTime: base.dateTime.add(const Duration(hours: 9)),
    );

    // Rounds 1 and 2 repeat round 0, so the window settles; the extra trip
    // only appears on the round that the manual button fires.
    final container = await _pumpResultsWithRounds(tester, [
      many,
      many,
      many,
      [...many, lateArrival],
    ]);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(TripCard).first, const Offset(0, -400));
    await tester.pumpAndSettle();

    container.read(busBookingProvider.notifier).checkForMoreTrips();
    await tester.pumpAndSettle();

    expect(container.read(busBookingProvider).stagedTrips, hasLength(1));
    expect(find.byType(NewTripsPill), findsOneWidget);
    expect(find.text('1 new trip'), findsOneWidget);

    await tester.tap(find.byType(NewTripsPill));
    await tester.pumpAndSettle();

    expect(container.read(busBookingProvider).stagedTrips, isEmpty);
    expect(find.byType(NewTripsPill), findsNothing);
  });
}
