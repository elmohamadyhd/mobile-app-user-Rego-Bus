import 'package:rego/features/bus/domain/entities/seat_map.dart';

/// Normalizes inconsistent driver-seat data from the Wadeny seats API.
///
/// Egyptian coaches always place the driver at the top-left of the layout.
/// Some integrations send duplicate or misplaced driver cells; others omit
/// them entirely. This normalizer enforces a single driver at [0,0].
abstract final class SeatMapNormalizer {
  static const _driverCell = SeatMapCell(kind: SeatMapCellKind.driver);
  static const _spaceCell = SeatMapCell(kind: SeatMapCellKind.space);

  static SeatMap normalize(SeatMap map) {
    final columns = map.salon.columns > 0 ? map.salon.columns : 1;
    final cells = List<SeatMapCell>.from(map.cells);
    if (cells.isEmpty) return map;

    final hadDriver = cells.any((c) => c.kind == SeatMapCellKind.driver);

    if (hadDriver) {
      for (var i = 0; i < cells.length; i++) {
        if (cells[i].kind == SeatMapCellKind.driver) {
          cells[i] = _spaceCell;
        }
      }
      cells[0] = _driverCell;
      return SeatMap(salon: map.salon, cells: cells);
    }

    final headerRow = <SeatMapCell>[
      _driverCell,
      ...List.filled(columns - 1, _spaceCell),
    ];
    return SeatMap(
      salon: map.salon.copyWith(rows: map.salon.rows + 1),
      cells: [...headerRow, ...cells],
    );
  }
}
