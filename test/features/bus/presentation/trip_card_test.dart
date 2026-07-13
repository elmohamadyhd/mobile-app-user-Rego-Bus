import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/presentation/widgets/trip_card.dart';
import 'package:rego/l10n/app_localizations.dart';

Offset _textTopLeft(WidgetTester tester, String text) {
  final finder = find.text(text);
  expect(finder, findsOneWidget);
  return tester.getTopLeft(finder);
}

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
    dropoffStops: [
      drop,
      drop.copyWith(
        locationId: '10',
        name: 'Moharam Bek',
        arrivalAt: DateTime(2026, 2, 10, 12, 45),
        finalPrice: 250,
      ),
    ],
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
  testWidgets('shows the last drop-off stop and its arrival time on the card',
      (tester) async {
    await _pumpCard(tester, _buildTrip());

    expect(find.text('Moharam Bek'), findsOneWidget);
    expect(find.text('Sidi Gaber'), findsNothing);
    expect(find.text('12:45'), findsOneWidget);
    expect(find.text('11:30'), findsNothing);
  });

  testWidgets('renders operator, fare stub and select without overflow',
      (tester) async {
    await _pumpCard(tester, _buildTrip());

    expect(find.textContaining('Go Bus', findRichText: true), findsOneWidget);
    expect(find.textContaining('250', findRichText: true), findsWidgets);
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

  testWidgets('cards with different content align times and fare rows',
      (tester) async {
    final shortTrip = _buildTrip();
    final board = BusStop(
      locationId: '3',
      name: 'Cairo NasrCity Station Very Long Name',
      cityId: 1,
      cityName: 'Cairo',
      arrivalAt: DateTime(2026, 2, 10, 5, 35),
    );
    final drop = BusStop(
      locationId: '9',
      name: 'Moharam Bek',
      cityId: 2,
      cityName: 'Alexandria',
      arrivalAt: DateTime(2026, 2, 10, 9, 5),
      finalPrice: 396,
    );
    final extraStops = List.generate(
      5,
      (i) => board.copyWith(locationId: '$i', name: 'Stop $i'),
    );
    final longTrip = BusTripSummary(
      id: '290546',
      gatewayId: 'Tazcara',
      operatorName: 'GO Bus',
      category: 'FARE-2 business class extra long',
      dateTime: DateTime(2026, 2, 10, 5, 35),
      currency: 'EGP',
      availableSeats: 0,
      priceStartWith: 396,
      defaultBoardingStop: board,
      defaultDropoffStop: drop,
      boardingStops: [board, ...extraStops],
      dropoffStops: [drop],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          backgroundColor: const Color(0xFFF4F7FB),
          body: Center(
            child: SizedBox(
              width: 360,
              child: Column(
                children: [
                  TripCard(trip: shortTrip, onTap: () {}),
                  const SizedBox(height: 16),
                  TripCard(trip: longTrip, onTap: () {}),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cards = find.byType(TripCard);
    expect(cards, findsNWidgets(2));

    final shortCardTop = tester.getTopLeft(cards.at(0)).dy;
    final longCardTop = tester.getTopLeft(cards.at(1)).dy;

    final shortDepartY = _textTopLeft(tester, '08:00').dy - shortCardTop;
    final longDepartY = _textTopLeft(tester, '05:35').dy - longCardTop;
    expect(shortDepartY, longDepartY);

    final fareFinder = find.text('Fare');
    expect(fareFinder, findsNWidgets(2));
    final shortFareY = tester.getTopLeft(fareFinder.at(0)).dy - shortCardTop;
    final longFareY = tester.getTopLeft(fareFinder.at(1)).dy - longCardTop;
    expect(shortFareY, longFareY);

    expect(tester.takeException(), isNull);
  });

  testWidgets('long station names wrap to two lines instead of truncating',
      (tester) async {
    final board = BusStop(
      locationId: '3',
      name: 'Cairo NasrCity Station Very Long Name',
      cityId: 1,
      cityName: 'Cairo',
      arrivalAt: DateTime(2026, 2, 10, 8),
    );
    final drop = BusStop(
      locationId: '9',
      name: 'Moharam Bek',
      cityId: 2,
      cityName: 'Alexandria',
      arrivalAt: DateTime(2026, 2, 10, 11, 30),
      finalPrice: 180,
    );
    await _pumpCard(
      tester,
      _buildTrip().copyWith(
        defaultBoardingStop: board,
        defaultDropoffStop: drop,
        boardingStops: [board],
        dropoffStops: [drop],
      ),
    );

    final stationText = tester.widget<Text>(
      find.textContaining('Cairo NasrCity Station Very Long Name'),
    );
    expect(stationText.maxLines, 2);
    expect(stationText.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
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
