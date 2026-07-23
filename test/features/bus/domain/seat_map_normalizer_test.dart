import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rego/features/bus/data/bus_dto_mapper.dart';
import 'package:rego/features/bus/domain/entities/seat_map.dart';
import 'package:rego/features/bus/domain/seat_map_normalizer.dart';

SeatMap _loadFixture(String filename) {
  final file = File('dummy data/$filename');
  final body = jsonDecode(file.readAsStringSync());
  return BusDtoMapper.seatMapFromEnvelope(body);
}

/// Raw parse without normalization — for asserting mapper wiring separately.
SeatMap _parseWithoutNormalize(String filename) {
  final file = File('dummy data/$filename');
  final body = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final data = body['data'] as Map<String, dynamic>;
  final salonJson = data['salon'] as Map<String, dynamic>;
  final salon = SeatSalon(
    id: salonJson['id'] is int
        ? salonJson['id'] as int
        : int.tryParse('${salonJson['id']}') ?? 0,
    name: salonJson['name'] as String? ?? '',
    rows: salonJson['rows'] as int,
    columns: salonJson['columns'] as int,
    direction: salonJson['direction'] as String? ?? 'ltr',
    levels: salonJson['levels'] as int? ?? 1,
  );
  final rawCells = data['seats_map'] as List;
  final cells = rawCells
      .whereType<Map<String, dynamic>>()
      .map(BusDtoMapper.seatCellFromJson)
      .toList();
  return SeatMapNormalizer.normalize(SeatMap(salon: salon, cells: cells));
}

int _driverCount(SeatMap map) =>
    map.cells.where((c) => c.kind == SeatMapCellKind.driver).length;

void main() {
  group('SeatMapNormalizer', () {
    test('consolidates duplicate drivers to top-left (seatsResponse.json)', () {
      final map = _loadFixture('seatsResponse.json');
      final columns = map.salon.columns;

      expect(_driverCount(map), 1);
      expect(map.cells[0].kind, SeatMapCellKind.driver);

      // Passenger seats 1–4 start at row 2 (index = columns).
      expect(map.cells[columns].seatNo, '1');
      expect(map.cells[columns + 1].seatNo, '2');
      expect(map.cells[columns + 3].seatNo, '3');
      expect(map.cells[columns + 4].seatNo, '4');

      // Cell count unchanged — Rule 1 does not prepend.
      final raw = jsonDecode(
        File('dummy data/seatsResponse.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final data = raw['data'] as Map<String, dynamic>;
      final rawCells = data['seats_map'] as List;
      expect(map.cells.length, rawCells.length);
      expect(map.salon.rows, 12);
    });

    test('prepends driver row when API omits driver (seatsRespons_2.json)', () {
      final map = _loadFixture('seatsRespons_2.json');
      final columns = map.salon.columns;

      expect(_driverCount(map), 1);
      expect(map.cells[0].kind, SeatMapCellKind.driver);
      expect(
          map.cells
              .sublist(1, columns)
              .every((c) => c.kind == SeatMapCellKind.space),
          isTrue);

      // Original seat 1 shifts down by one row.
      expect(map.cells[columns].seatNo, '1');
      expect(map.cells[columns + 4].seatNo, '2');

      final raw = jsonDecode(
        File('dummy data/seatsRespons_2.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final data = raw['data'] as Map<String, dynamic>;
      final rawCells = data['seats_map'] as List;
      expect(map.cells.length, rawCells.length + columns);
      expect(map.salon.rows, 15);
    });

    test('leaves already-correct driver at index 0 unchanged', () {
      const map = SeatMap(
        salon: SeatSalon(id: 1, name: 'Express', rows: 2, columns: 3),
        cells: [
          SeatMapCell(kind: SeatMapCellKind.driver),
          SeatMapCell(kind: SeatMapCellKind.space),
          SeatMapCell(kind: SeatMapCellKind.space),
          SeatMapCell(kind: SeatMapCellKind.available, id: '1', seatNo: '1'),
          SeatMapCell(kind: SeatMapCellKind.available, id: '2', seatNo: '2'),
          SeatMapCell(kind: SeatMapCellKind.space),
        ],
      );

      final normalized = SeatMapNormalizer.normalize(map);

      expect(normalized, map);
    });

    test('is idempotent', () {
      final once = _loadFixture('seatsResponse.json');
      final twice = SeatMapNormalizer.normalize(once);

      expect(twice.cells, once.cells);
      expect(twice.salon, once.salon);
    });

    test('moves misplaced single driver to index 0', () {
      const map = SeatMap(
        salon: SeatSalon(id: 1, name: '', rows: 2, columns: 5),
        cells: [
          SeatMapCell(kind: SeatMapCellKind.space),
          SeatMapCell(kind: SeatMapCellKind.driver),
          SeatMapCell(kind: SeatMapCellKind.space),
          SeatMapCell(kind: SeatMapCellKind.space),
          SeatMapCell(kind: SeatMapCellKind.door),
          SeatMapCell(kind: SeatMapCellKind.available, id: '4', seatNo: '4'),
          SeatMapCell(kind: SeatMapCellKind.space),
          SeatMapCell(kind: SeatMapCellKind.space),
          SeatMapCell(kind: SeatMapCellKind.space),
          SeatMapCell(kind: SeatMapCellKind.available, id: '5', seatNo: '5'),
        ],
      );

      final normalized = SeatMapNormalizer.normalize(map);

      expect(_driverCount(normalized), 1);
      expect(normalized.cells[0].kind, SeatMapCellKind.driver);
      expect(normalized.cells[4].kind, SeatMapCellKind.door);
      expect(normalized.cells[5].seatNo, '4');
    });

    test('BusDtoMapper applies normalization via seatMapFromEnvelope', () {
      final viaMapper = _loadFixture('seatsRespons_2.json');
      final viaNormalizer = _parseWithoutNormalize('seatsRespons_2.json');

      expect(viaMapper.cells, viaNormalizer.cells);
      expect(viaMapper.salon.rows, viaNormalizer.salon.rows);
    });
  });
}
