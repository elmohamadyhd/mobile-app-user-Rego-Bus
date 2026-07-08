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
