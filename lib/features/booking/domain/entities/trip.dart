// lib/features/booking/domain/entities/trip.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'trip.freezed.dart';

@freezed
class TripSummary with _$TripSummary {
  const factory TripSummary({
    required String id,
    required String operatorName,
    required String operatorCode,
    required String serviceClass,
    required int departHour,
    required int departMinute,
    required int arriveHour,
    required int arriveMinute,
    required int durationMin,
    required int priceEgp,
    required int seatsLeft,
  }) = _TripSummary;
}

extension TripSummaryX on TripSummary {
  String get departLabel =>
      '${departHour.toString().padLeft(2, '0')}:${departMinute.toString().padLeft(2, '0')}';
  String get arriveLabel =>
      '${arriveHour.toString().padLeft(2, '0')}:${arriveMinute.toString().padLeft(2, '0')}';
  String get durationLabel {
    final h = durationMin ~/ 60;
    final m = durationMin % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

@freezed
class TripDetail with _$TripDetail {
  const factory TripDetail({
    required TripSummary summary,
    required String terminalFrom,
    required String terminalFromSub,
    required String terminalTo,
    required String terminalToSub,
    required List<String> amenities,
  }) = _TripDetail;
}
