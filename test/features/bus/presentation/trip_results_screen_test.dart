import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/features/bus/domain/entities/bus_search_params.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/domain/repositories/bus_repository.dart';
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/trip_results_screen.dart';
import 'package:rego/features/bus/presentation/widgets/trip_card.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../fake_bus_repository.dart';

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

      await tester.tap(cards.first);
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
}
