import 'package:safaria/features/bus/domain/entities/seat_map.dart';

/// Normalizes inconsistent driver-seat data from the Wadeny seats API.
///
/// Egyptian coaches place the driver at the top-left of the layout. Some
/// integrations send duplicate or misplaced driver cells — those are
/// consolidated to a single driver at [0,0]. If the API omits the driver
/// entirely, the map is left unchanged (no invented steering-wheel cell).
abstract final class SeatMapNormalizer {
  static const _driverCell = SeatMapCell(kind: SeatMapCellKind.driver);
  static const _spaceCell = SeatMapCell(kind: SeatMapCellKind.space);

  static SeatMap normalize(SeatMap map) {
    final cells = List<SeatMapCell>.from(map.cells);
    if (cells.isEmpty) return map;

    final hadDriver = cells.any((c) => c.kind == SeatMapCellKind.driver);
    if (!hadDriver) return map;

    for (var i = 0; i < cells.length; i++) {
      if (cells[i].kind == SeatMapCellKind.driver) {
        cells[i] = _spaceCell;
      }
    }
    cells[0] = _driverCell;
    return SeatMap(salon: map.salon, cells: cells);
  }
}
