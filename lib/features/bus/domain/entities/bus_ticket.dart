import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';

part 'bus_ticket.freezed.dart';

@freezed
abstract class BusTicketLine with _$BusTicketLine {
  const factory BusTicketLine({
    required int id,
    required String seatNumber,
    required String price,
  }) = _BusTicketLine;
}

@freezed
abstract class BusTicket with _$BusTicket {
  const factory BusTicket({
    required String bookingRef,
    required String orderId,
    required BusTripSummary trip,
    required BusStop fromStop,
    required BusStop toStop,
    required List<String> seats,
    required List<BusTicketLine> ticketLines,
    required String total,
    required String currency,
    String? paymentUrl,
    String? cancelUrl,
    String? invoiceUrl,
    String? statusCode,
    required DateTime issuedAt,
  }) = _BusTicket;
}
