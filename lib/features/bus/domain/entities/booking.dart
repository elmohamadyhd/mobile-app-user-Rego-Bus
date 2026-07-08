// lib/features/bus/domain/entities/booking.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rego/features/bus/domain/entities/trip.dart';

part 'booking.freezed.dart';

@freezed
abstract class ETicket with _$ETicket {
  const factory ETicket({
    required String bookingRef,
    required TripDetail trip,
    required List<String> seats,
    required String passengerName,
    required String gate,
    required DateTime issuedAt,
  }) = _ETicket;
}
