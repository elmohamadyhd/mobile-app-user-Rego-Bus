import 'package:freezed_annotation/freezed_annotation.dart';

part 'flight_order.freezed.dart';

@freezed
abstract class FlightOrderPassenger with _$FlightOrderPassenger {
  const factory FlightOrderPassenger({
    required String id,
    required String passengerTypeCode,
    String? firstName,
    String? lastName,
  }) = _FlightOrderPassenger;
}

@freezed
abstract class FlightOrderSegment with _$FlightOrderSegment {
  const factory FlightOrderSegment({
    required String id,
    required String origin,
    required String destination,
    DateTime? departureDateTime,
    DateTime? arrivalDateTime,
    String? marketingCarrierCode,
    String? marketingFlightNumber,
  }) = _FlightOrderSegment;
}

/// A created flight order.
///
/// [checkoutUrl] is the gateway's hosted payment page. It comes from
/// `transaction.invoice_url` — **not** the top-level `invoice_url`, which is
/// a receipt on the REGO site and will not take a payment.
@freezed
abstract class FlightOrder with _$FlightOrder {
  const factory FlightOrder({
    required String id,
    required String status,
    required String orderStatus,
    String? paymentStatus,
    String? airlinePnr,
    String? gdsPnr,
    DateTime? paidAt,
    required double totalAmount,
    required String currency,
    String? checkoutUrl,
    String? receiptUrl,
    @Default(false) bool canBeCancelled,
    @Default(false) bool canReview,
    int? reviewRating,
    @Default([]) List<FlightOrderPassenger> passengers,
    @Default([]) List<FlightOrderSegment> segments,
  }) = _FlightOrder;
}
