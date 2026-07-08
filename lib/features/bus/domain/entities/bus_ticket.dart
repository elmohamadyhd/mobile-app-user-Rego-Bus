// lib/features/bus/domain/entities/bus_ticket.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';

part 'bus_ticket.freezed.dart';

@freezed
abstract class BusTicket with _$BusTicket {
  const factory BusTicket({
    required String bookingRef,
    required BusTripDetail trip,
    required List<String> seats,
    required String passengerName,
    required String gate,
    required DateTime issuedAt,
  }) = _BusTicket;
}
