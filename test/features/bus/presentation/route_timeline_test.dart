import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/presentation/widgets/route_timeline.dart';
import 'package:rego/l10n/app_localizations.dart';

const _board1 = BusStop(
  locationId: 'b1',
  name: 'October',
  cityId: 1,
  cityName: '6th of October',
);
final _board2 = BusStop(
  locationId: 'b2',
  name: 'Zayed',
  cityId: 1,
  cityName: '6th of October',
  arrivalAt: DateTime(2026, 2, 10, 7, 25),
);
final _drop1 = BusStop(
  locationId: 'd1',
  name: 'Ras Shitan',
  cityId: 2,
  cityName: 'Nuweiba',
  arrivalAt: DateTime(2026, 2, 10, 14, 10),
  finalPrice: 200,
);
final _drop2 = BusStop(
  locationId: 'd2',
  name: 'Dahab',
  cityId: 2,
  cityName: 'South Sinai',
  arrivalAt: DateTime(2026, 2, 10, 15, 5),
  finalPrice: 220,
);

Future<void> _pump(
  WidgetTester tester, {
  required BusStop from,
  required BusStop to,
  required ValueChanged<BusStop> onBoard,
  required ValueChanged<BusStop> onDrop,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Scaffold(
        body: SingleChildScrollView(
          child: RouteTimeline(
            boardingStops: [_board1, _board2],
            dropoffStops: [_drop1, _drop2],
            selectedFrom: from,
            selectedTo: to,
            currency: 'EGP',
            onBoardSelected: onBoard,
            onDropoffSelected: onDrop,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders every stop name, its time and drop-off fares',
      (tester) async {
    await _pump(
      tester,
      from: _board1,
      to: _drop1,
      onBoard: (_) {},
      onDrop: (_) {},
    );

    expect(find.text('October'), findsOneWidget);
    expect(find.text('Zayed'), findsOneWidget);
    expect(find.text('Ras Shitan'), findsOneWidget);
    expect(find.text('Dahab'), findsOneWidget);
    expect(find.text('07:25'), findsOneWidget); // Zayed arrival

    expect(find.textContaining('200', findRichText: true), findsWidgets);
    expect(find.textContaining('220', findRichText: true), findsWidgets);
  });

  testWidgets('shows the two zone headers', (tester) async {
    await _pump(
      tester,
      from: _board1,
      to: _drop1,
      onBoard: (_) {},
      onDrop: (_) {},
    );

    expect(find.text('Board at'), findsOneWidget);
    expect(find.text('Drop off at'), findsOneWidget);
  });

  testWidgets('marks the selected board and drop-off rows with pills',
      (tester) async {
    await _pump(
      tester,
      from: _board2,
      to: _drop2,
      onBoard: (_) {},
      onDrop: (_) {},
    );

    expect(find.text('Board here'), findsOneWidget);
    expect(find.text('Drop off'), findsOneWidget);
  });

  testWidgets('tapping a boarding row fires onBoardSelected', (tester) async {
    BusStop? tapped;
    await _pump(
      tester,
      from: _board1,
      to: _drop1,
      onBoard: (s) => tapped = s,
      onDrop: (_) {},
    );

    await tester.tap(find.text('Zayed'));
    await tester.pumpAndSettle();

    expect(tapped?.locationId, 'b2');
  });

  testWidgets('tapping a drop-off row fires onDropoffSelected', (tester) async {
    BusStop? tapped;
    await _pump(
      tester,
      from: _board1,
      to: _drop1,
      onBoard: (_) {},
      onDrop: (s) => tapped = s,
    );

    await tester.tap(find.text('Dahab'));
    await tester.pumpAndSettle();

    expect(tapped?.locationId, 'd2');
  });

  testWidgets('a stop with null arrivalAt renders without a time',
      (tester) async {
    await _pump(
      tester,
      from: _board1,
      to: _drop1,
      onBoard: (_) {},
      onDrop: (_) {},
    );

    // October has no arrivalAt; only Zayed's time (07:25) should render
    // among boarding stops.
    expect(find.text('07:25'), findsOneWidget);
  });

  testWidgets('renders in RTL (Arabic)', (tester) async {
    await _pump(
      tester,
      from: _board1,
      to: _drop1,
      onBoard: (_) {},
      onDrop: (_) {},
      locale: const Locale('ar'),
    );

    expect(find.text('تصعد من'), findsOneWidget);
    expect(find.text('تنزل في'), findsOneWidget);
  });

  testWidgets(
      'long press on a stop shows the stop-specific confirmation dialog',
      (tester) async {
    await _pump(
      tester,
      from: _board1,
      to: _drop1,
      onBoard: (_) {},
      onDrop: (_) {},
    );

    await tester.longPress(find.text('Zayed'));
    await tester.pumpAndSettle();

    expect(find.text('View Zayed on Google Maps?'), findsOneWidget);
    expect(
      find.text("You'll leave REGO and see this stop on Google Maps."),
      findsOneWidget,
    );
  });

  testWidgets('long press does not fire onBoardSelected', (tester) async {
    var boardTapped = false;
    await _pump(
      tester,
      from: _board1,
      to: _drop1,
      onBoard: (_) => boardTapped = true,
      onDrop: (_) {},
    );

    await tester.longPress(find.text('Zayed'));
    await tester.pumpAndSettle();

    expect(boardTapped, isFalse);
  });
}
