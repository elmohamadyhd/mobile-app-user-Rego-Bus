import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/features/bus/domain/entities/seat_map.dart';
import 'package:rego/features/bus/presentation/widgets/bus_images_fab.dart';
import 'package:rego/features/bus/presentation/widgets/seat_grid.dart';
import 'package:rego/l10n/app_localizations.dart';

SeatMap _buildSeatMap() {
  const salon = SeatSalon(id: 1, name: 'Express', rows: 2, columns: 4);
  const cells = [
    SeatMapCell(kind: SeatMapCellKind.driver),
    SeatMapCell(kind: SeatMapCellKind.space),
    SeatMapCell(kind: SeatMapCellKind.available, id: 'A1', seatNo: 'A1'),
    SeatMapCell(kind: SeatMapCellKind.booked, id: 'A2', seatNo: 'A2'),
    SeatMapCell(kind: SeatMapCellKind.space),
    SeatMapCell(kind: SeatMapCellKind.available, id: 'B1', seatNo: 'B1'),
    SeatMapCell(kind: SeatMapCellKind.door),
    SeatMapCell(kind: SeatMapCellKind.wc),
  ];
  return const SeatMap(salon: salon, cells: cells);
}

Future<void> _pumpGrid(
  WidgetTester tester, {
  List<String> selectedSeats = const [],
  required ValueChanged<String> onToggle,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SeatGrid(
          seatMap: _buildSeatMap(),
          selectedSeats: selectedSeats,
          onToggle: onToggle,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'aisle cells render blank — no icon, no interactive control',
    (tester) async {
      await _pumpGrid(tester, onToggle: (_) {});

      // Driver + door + wc = 3 icons. The two aisle (`space`) cells contribute
      // none — they must stay visually empty.
      expect(find.byType(Icon), findsNWidgets(3));

      // Only the three seat cells (2 available + 1 booked) are rendered as
      // InkWell controls (booked is present but disabled); the aisle and
      // marker cells never wrap themselves in a tappable control.
      expect(find.byType(InkWell), findsNWidgets(3));
    },
  );

  testWidgets('tapping an available seat invokes onToggle with its id', (
    tester,
  ) async {
    var toggledId = '';
    await _pumpGrid(tester, onToggle: (id) => toggledId = id);

    await tester.tap(find.text('A1'));
    await tester.pump();

    expect(toggledId, 'A1');
  });

  testWidgets('booked seats are not tappable', (tester) async {
    var tapped = false;
    await _pumpGrid(tester, onToggle: (_) => tapped = true);

    await tester.tap(find.text('A2'));
    await tester.pump();

    expect(tapped, isFalse);
  });

  testWidgets('selected seat renders with onPrimary text', (tester) async {
    await _pumpGrid(
      tester,
      selectedSeats: const ['A1'],
      onToggle: (_) {},
    );

    final text = tester.widget<Text>(find.text('A1'));
    expect(text.style?.color, AppColors.onPrimary);
  });

  testWidgets('shows bus images FAB when busImageUrl is provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SeatGrid(
            seatMap: _buildSeatMap(),
            selectedSeats: const [],
            busImageUrl: 'https://example.com/bus.jpeg',
            onToggle: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(BusImagesFab), findsOneWidget);
    expect(find.byIcon(AppIcons.eye), findsOneWidget);
  });

  testWidgets('ltr salon keeps driver left when app locale is Arabic', (
    tester,
  ) async {
    const seatMap = SeatMap(
      salon: SeatSalon(
        id: 1,
        name: 'Express',
        rows: 2,
        columns: 5,
        direction: 'ltr',
      ),
      cells: [
        SeatMapCell(kind: SeatMapCellKind.driver),
        SeatMapCell(kind: SeatMapCellKind.space),
        SeatMapCell(kind: SeatMapCellKind.space),
        SeatMapCell(kind: SeatMapCellKind.space),
        SeatMapCell(kind: SeatMapCellKind.space),
        SeatMapCell(kind: SeatMapCellKind.available, id: '1', seatNo: '1'),
        SeatMapCell(kind: SeatMapCellKind.available, id: '2', seatNo: '2'),
        SeatMapCell(kind: SeatMapCellKind.space),
        SeatMapCell(kind: SeatMapCellKind.available, id: '3', seatNo: '3'),
        SeatMapCell(kind: SeatMapCellKind.available, id: '4', seatNo: '4'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SeatGrid(
            seatMap: seatMap,
            selectedSeats: const [],
            onToggle: (_) {},
          ),
        ),
      ),
    );

    final driverDx = tester.getTopLeft(find.byIcon(AppIcons.busFront)).dx;
    final seat1Dx = tester.getTopLeft(find.text('1')).dx;
    expect(driverDx, lessThan(seat1Dx));
  });

  testWidgets('rtl salon places seat 1 left of seat 2 on screen', (
    tester,
  ) async {
    const seatMap = SeatMap(
      salon: SeatSalon(
        id: 1,
        name: 'Express',
        rows: 1,
        columns: 4,
        direction: 'rtl',
      ),
      cells: [
        SeatMapCell(kind: SeatMapCellKind.space),
        SeatMapCell(kind: SeatMapCellKind.available, id: '2', seatNo: '2'),
        SeatMapCell(kind: SeatMapCellKind.space),
        SeatMapCell(kind: SeatMapCellKind.available, id: '1', seatNo: '1'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeatGrid(
            seatMap: seatMap,
            selectedSeats: const [],
            onToggle: (_) {},
          ),
        ),
      ),
    );

    final seat1Dx = tester.getTopLeft(find.text('1')).dx;
    final seat2Dx = tester.getTopLeft(find.text('2')).dx;
    expect(seat1Dx, lessThan(seat2Dx));
  });
}
