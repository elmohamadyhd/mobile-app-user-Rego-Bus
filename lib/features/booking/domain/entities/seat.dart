// lib/features/booking/domain/entities/seat.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'seat.freezed.dart';

enum SeatStatus { available, booked }

@freezed
class SeatCell with _$SeatCell {
  const factory SeatCell({
    required String id,
    required SeatStatus status,
  }) = _SeatCell;
}

@freezed
class SeatRow with _$SeatRow {
  const factory SeatRow({
    required List<SeatCell?> cells, // null element = aisle gap
  }) = _SeatRow;
}
