import 'package:freezed_annotation/freezed_annotation.dart';

part 'seat_map.freezed.dart';

enum SeatMapCellKind {
  driver,
  space,
  door,
  wc,
  available,
  booked,
}

@freezed
abstract class SeatMapCell with _$SeatMapCell {
  const factory SeatMapCell({
    required SeatMapCellKind kind,
    String? id,
    String? seatNo,
    String? category,
    @Default(1) int level,
  }) = _SeatMapCell;
}

@freezed
abstract class SeatSalon with _$SeatSalon {
  const factory SeatSalon({
    required int id,
    required String name,
    required int rows,
    required int columns,
    @Default('ltr') String direction,
    @Default(1) int levels,
  }) = _SeatSalon;
}

@freezed
abstract class SeatMap with _$SeatMap {
  const factory SeatMap({
    required SeatSalon salon,
    required List<SeatMapCell> cells,
  }) = _SeatMap;
}

/// Resolves internal seat IDs to the same display label used on the grid.
extension SeatMapLabels on SeatMap {
  String labelForSeatId(String seatId) {
    for (final cell in cells) {
      if (cell.id == seatId) {
        return cell.seatNo ?? cell.id ?? seatId;
      }
    }
    return seatId;
  }

  List<String> labelsForSeatIds(Iterable<String> seatIds) =>
      seatIds.map(labelForSeatId).toList();
}
