import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/presentation/widgets/trip_card.dart';
import 'package:rego/l10n/app_localizations.dart';

BusTripSummary _buildTrip({int seats = 6}) {
  final board = BusStop(
    locationId: '1',
    name: 'Ramsis',
    cityId: 1,
    cityName: 'Cairo',
    arrivalAt: DateTime(2026, 2, 10, 8),
  );
  final drop = BusStop(
    locationId: '9',
    name: 'Sidi Gaber',
    cityId: 2,
    cityName: 'Alexandria',
    arrivalAt: DateTime(2026, 2, 10, 11, 30),
    finalPrice: 180,
  );
  return BusTripSummary(
    id: '290545',
    gatewayId: 'Tazcara',
    operatorName: 'Go Bus',
    category: 'VIP',
    dateTime: DateTime(2026, 2, 10, 8),
    currency: 'EGP',
    availableSeats: seats,
    priceStartWith: 180,
    defaultBoardingStop: board,
    defaultDropoffStop: drop,
    boardingStops: [board, board.copyWith(locationId: '2', name: 'Giza')],
    dropoffStops: [drop, drop.copyWith(locationId: '10', name: 'Moharam Bek')],
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  BusTripSummary trip, {
  Locale locale = const Locale('en'),
  VoidCallback? onTap,
  bool loading = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        body: Center(
          child: SizedBox(
            width: 360,
            child: TripCard(
              trip: trip,
              onTap: onTap ?? () {},
              loading: loading,
            ),
          ),
        ),
      ),
    ),
  );
  // The Select-button spinner animates indefinitely while loading, so
  // pumpAndSettle would time out — a single pump is enough to lay out.
  if (loading) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('renders operator, fare stub and select without overflow',
      (tester) async {
    await _pumpCard(tester, _buildTrip());

    expect(find.textContaining('Go Bus', findRichText: true), findsOneWidget);
    expect(find.textContaining('180', findRichText: true), findsWidgets);
    expect(find.text('Fare'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('6 seats left'), findsOneWidget);
    // Alternate boarding/drop-off stations collapse to a "+1" hint.
    expect(find.textContaining('+1', findRichText: true), findsWidgets);
  });

  testWidgets('low seat count still renders the pill', (tester) async {
    await _pumpCard(tester, _buildTrip(seats: 2));
    expect(find.text('2 seats left'), findsOneWidget);
  });

  testWidgets('tapping the card invokes onTap', (tester) async {
    var tapped = 0;
    await _pumpCard(tester, _buildTrip(), onTap: () => tapped++);

    await tester.tap(find.byType(TripCard));
    await tester.pumpAndSettle();

    expect(tapped, 1);
  });

  testWidgets('paints and lays out in RTL (Arabic)', (tester) async {
    await _pumpCard(tester, _buildTrip(), locale: const Locale('ar'));

    expect(find.text('السعر'), findsOneWidget); // Fare
    expect(find.text('اختر'), findsOneWidget); // Select
    expect(find.textContaining('Go Bus', findRichText: true), findsOneWidget);
  });

  testWidgets('loading shows a spinner in place of Select and blocks taps',
      (tester) async {
    var tapped = 0;
    await _pumpCard(
      tester,
      _buildTrip(),
      onTap: () => tapped++,
      loading: true,
    );

    expect(find.text('Select'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(TripCard));
    await tester.pump();
    expect(tapped, 0);
  });
}
