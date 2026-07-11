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
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RouteTimeline(
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
  testWidgets('renders every stop in order with the selected pair marked',
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
    expect(find.text('Board here'), findsOneWidget);
    expect(find.text('Drop off'), findsOneWidget);
  });

  testWidgets('tapping a boarding stop fires onBoardSelected', (tester) async {
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

  testWidgets('tapping a drop-off stop fires onDropoffSelected',
      (tester) async {
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
}
