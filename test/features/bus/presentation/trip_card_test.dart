import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/bus/domain/entities/bus_stop.dart';
import 'package:safaria/features/bus/domain/entities/bus_trip.dart';
import 'package:safaria/features/bus/domain/entities/trip_highlight.dart';
import 'package:safaria/features/bus/presentation/widgets/trip_card.dart';
import 'package:safaria/l10n/app_localizations.dart';

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
  void Function({required BusStop from, required BusStop to})? onSelect,
  bool loading = false,
  TripHighlight? highlight,
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
              onSelect: onSelect ?? ({required from, required to}) {},
              loading: loading,
              highlight: highlight,
            ),
          ),
        ),
      ),
    ),
  );
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

  testWidgets('shows cheapest highlight badge in the header', (tester) async {
    await _pumpCard(
      tester,
      _buildTrip(),
      highlight: TripHighlight.cheapest,
    );
    expect(find.text('Cheapest'), findsOneWidget);
  });

  testWidgets('hides highlight badge when highlight is null', (tester) async {
    await _pumpCard(tester, _buildTrip());
    expect(find.text('Cheapest'), findsNothing);
    expect(find.text('Fastest'), findsNothing);
    expect(find.text('Best deal'), findsNothing);
  });

  testWidgets(
      'shows the governorate above the boarding and drop-off stop names',
      (tester) async {
    await _pumpCard(tester, _buildTrip());

    final cairoTop = _textTopLeft(tester, 'Cairo').dy;
    final boardStopTop = _textTopLeft(tester, 'Ramsis').dy;
    expect(cairoTop, lessThan(boardStopTop));

    final alexandriaTop = _textTopLeft(tester, 'Alexandria').dy;
    final dropStopTop = _textTopLeft(tester, 'Moharam Bek').dy;
    expect(alexandriaTop, lessThan(dropStopTop));
  });

  testWidgets('renders operator, fare stub and select without overflow',
      (tester) async {
    await _pumpCard(tester, _buildTrip());

    expect(find.text('Go Bus'), findsOneWidget);
    expect(find.textContaining('250', findRichText: true), findsWidgets);
    expect(find.text('Fare'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('6 seats left'), findsNothing);
    expect(find.text('4 stops'), findsOneWidget);
    expect(find.textContaining('+1', findRichText: true), findsNothing);
  });

  testWidgets('hides the seats-left pill until backend data is ready',
      (tester) async {
    await _pumpCard(tester, _buildTrip(seats: 2));
    expect(find.text('2 seats left'), findsNothing);
  });

  testWidgets('tapping the card invokes onSelect with default pair',
      (tester) async {
    BusStop? selectedFrom;
    BusStop? selectedTo;
    await _pumpCard(
      tester,
      _buildTrip(),
      onSelect: ({required from, required to}) {
        selectedFrom = from;
        selectedTo = to;
      },
    );

    await tester.tap(find.byType(TripCard));
    await tester.pumpAndSettle();

    expect(selectedFrom?.locationId, '1');
    expect(selectedTo?.locationId, '10');
  });

  testWidgets('tapping stops count opens sheet without selecting trip',
      (tester) async {
    var selected = 0;
    await _pumpCard(
      tester,
      _buildTrip(),
      onSelect: ({required from, required to}) => selected++,
    );

    await tester.tap(find.text('4 stops'));
    await tester.pumpAndSettle();

    expect(find.text('Stops'), findsOneWidget);
    expect(selected, 0);
  });

  testWidgets('tapping a stop applies fare immediately; Select keeps pair',
      (tester) async {
    BusStop? selectedFrom;
    BusStop? selectedTo;
    await _pumpCard(
      tester,
      _buildTrip(),
      onSelect: ({required from, required to}) {
        selectedFrom = from;
        selectedTo = to;
      },
    );

    await tester.tap(find.text('4 stops'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giza'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sidi Gaber'));
    await tester.pumpAndSettle();

    // Card under the sheet already reflects the live pick.
    expect(find.textContaining('180', findRichText: true), findsWidgets);

    Navigator.of(tester.element(find.text('Stops'))).pop();
    await tester.pumpAndSettle();

    expect(find.text('Giza'), findsWidgets);

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    expect(selectedFrom?.locationId, '2');
    expect(selectedTo?.locationId, '9');
  });

  testWidgets('shows combined stops count on the duration line in Arabic',
      (tester) async {
    await _pumpCard(tester, _buildTrip(), locale: const Locale('ar'));

    expect(find.text('4 محطات'), findsOneWidget);
    expect(find.text('4h 45m'), findsOneWidget);
  });

  testWidgets('paints and lays out in RTL (Arabic)', (tester) async {
    await _pumpCard(tester, _buildTrip(), locale: const Locale('ar'));

    expect(find.text('السعر'), findsOneWidget);
    expect(find.text('اختر'), findsOneWidget);
    expect(find.text('Go Bus'), findsOneWidget);
    expect(find.text('VIP'), findsOneWidget);
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
                  TripCard(
                    trip: shortTrip,
                    onSelect: ({required from, required to}) {},
                  ),
                  const SizedBox(height: 16),
                  TripCard(
                    trip: longTrip,
                    onSelect: ({required from, required to}) {},
                  ),
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
      onSelect: ({required from, required to}) => tapped++,
      loading: true,
    );

    expect(find.text('Select'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(TripCard));
    await tester.pump();
    expect(tapped, 0);
  });
}
