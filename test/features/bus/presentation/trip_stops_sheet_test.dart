import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/bus/domain/entities/bus_stop.dart';
import 'package:safaria/features/bus/domain/entities/bus_trip.dart';
import 'package:safaria/features/bus/presentation/widgets/trip_stops_sheet.dart';
import 'package:safaria/l10n/app_localizations.dart';

BusTripSummary _trip() {
  final board = BusStop(
    locationId: '1',
    name: 'Ramsis',
    cityId: 1,
    cityName: 'Cairo',
    arrivalAt: DateTime(2026, 2, 10, 8),
  );
  final board2 = board.copyWith(locationId: '2', name: 'Giza');
  final drop = BusStop(
    locationId: '9',
    name: 'Sidi Gaber',
    cityId: 2,
    cityName: 'Alexandria',
    arrivalAt: DateTime(2026, 2, 10, 11, 30),
    finalPrice: 180,
  );
  final drop2 = drop.copyWith(
    locationId: '10',
    name: 'Moharam Bek',
    arrivalAt: DateTime(2026, 2, 10, 12, 45),
    finalPrice: 250,
  );
  return BusTripSummary(
    id: '290545',
    gatewayId: 'Tazcara',
    operatorName: 'Go Bus',
    category: 'VIP',
    dateTime: DateTime(2026, 2, 10, 8),
    currency: 'EGP',
    defaultBoardingStop: board,
    defaultDropoffStop: drop,
    boardingStops: [board, board2],
    dropoffStops: [drop, drop2],
  );
}

void main() {
  testWidgets('tapping a stop applies the pair immediately', (tester) async {
    final trip = _trip();
    BusStop? changedFrom;
    BusStop? changedTo;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showTripStopsSheet(
                  context,
                  trip: trip,
                  initialFrom: trip.defaultBoardingStop,
                  initialTo: trip.terminalDropoffStop,
                  onChanged: ({required from, required to}) {
                    changedFrom = from;
                    changedTo = to;
                  },
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Stops'), findsOneWidget);
    expect(find.text('Apply'), findsNothing);
    expect(find.text('Board here'), findsOneWidget);

    await tester.tap(find.text('Giza'));
    await tester.pumpAndSettle();

    expect(changedFrom?.locationId, '2');
    expect(changedTo?.locationId, trip.terminalDropoffStop.locationId);
    expect(find.text('Board here'), findsOneWidget);

    await tester.tap(find.text('Sidi Gaber'));
    await tester.pumpAndSettle();

    expect(changedFrom?.locationId, '2');
    expect(changedTo?.locationId, '9');
    expect(find.text('Drop off'), findsOneWidget);
  });
}
