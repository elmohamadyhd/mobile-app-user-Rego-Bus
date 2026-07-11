import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/presentation/widgets/route_road.dart';
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
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: RouteRoad(
          boardingStops: [_board1, _board2],
          dropoffStops: [_drop1, _drop2],
          selectedFrom: from,
          selectedTo: to,
          onBoardSelected: onBoard,
          onDropoffSelected: onDrop,
        ),
      ),
    ),
  );
}

void main() {
  group('computeRouteRoadLayout', () {
    test('two stops lay out on a single row', () {
      final layout = computeRouteRoadLayout(
        stops: [
          const RouteStopInput(stop: _board1, isBoardCandidate: true),
          RouteStopInput(stop: _drop1, isBoardCandidate: false),
        ],
        width: 340,
      );

      expect(layout.nodes.length, 2);
      expect(layout.columns, 2);
      expect(layout.nodes.every((n) => n.row == 0), isTrue);
    });

    test('many stops wrap into snaking rows in route order', () {
      final stops = [
        for (var i = 0; i < 7; i++)
          RouteStopInput(
            stop: BusStop(
              locationId: 's$i',
              name: 'Stop $i',
              cityId: 1,
              cityName: 'City',
            ),
            isBoardCandidate: i < 4,
          ),
      ];

      final layout = computeRouteRoadLayout(stops: stops, width: 340);

      expect(layout.nodes.length, 7);
      expect(layout.columns, 3);
      for (var i = 0; i < layout.nodes.length; i++) {
        expect(layout.nodes[i].index, i);
      }
      expect(layout.nodes.last.row, 2); // ceil(7 / 3) - 1
      expect(layout.height, greaterThan(0));
    });
  });

  testWidgets('renders every stop name and its arrival time', (tester) async {
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
  });

  testWidgets('long-press a boarding stop then "Board here" fires onBoard',
      (tester) async {
    BusStop? tapped;
    await _pump(
      tester,
      from: _board1,
      to: _drop1,
      onBoard: (s) => tapped = s,
      onDrop: (_) {},
    );

    await tester.longPress(find.text('Zayed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Board here'));
    await tester.pumpAndSettle();

    expect(tapped?.locationId, 'b2');
  });

  testWidgets('long-press a drop-off stop then "Drop off" fires onDropoff',
      (tester) async {
    BusStop? tapped;
    await _pump(
      tester,
      from: _board1,
      to: _drop1,
      onBoard: (_) {},
      onDrop: (s) => tapped = s,
    );

    await tester.longPress(find.text('Dahab'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drop off'));
    await tester.pumpAndSettle();

    expect(tapped?.locationId, 'd2');
  });
}
