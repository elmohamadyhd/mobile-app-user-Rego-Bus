import 'package:freezed_annotation/freezed_annotation.dart';

part 'flight_confirmed_order.freezed.dart';

@freezed
abstract class FlightConfirmedSegment with _$FlightConfirmedSegment {
  const factory FlightConfirmedSegment({
    required String segmentId,
    required String origin,
    required String destination,
    required DateTime departureDateTime,
    required DateTime arrivalDateTime,
    String? departureTerminal,
    String? arrivalTerminal,
    required int flightTimeInMinutes,
    required String operatingCarrierCode,
    String? operatingCarrierName,
    String? operatingCarrierLogo,
    required String operatingFlightNumber,
    required String marketingCarrierCode,
    required String marketingFlightNumber,
    String? equipment,
    String? priceClassReferenceId,
    String? baggageDetailsReferenceId,
    String? cabinCode,
    String? rbd,
  }) = _FlightConfirmedSegment;
}

@freezed
abstract class FlightFareSegmentDetail with _$FlightFareSegmentDetail {
  const factory FlightFareSegmentDetail({
    required String segmentReferenceId,
    String? priceClassReferenceId,
    String? baggageDetailsReferenceId,
    String? cabinCode,
    String? rbd,
  }) = _FlightFareSegmentDetail;
}

@freezed
abstract class FlightPassengerFareBreakdown with _$FlightPassengerFareBreakdown {
  const factory FlightPassengerFareBreakdown({
    required String passengerTypeCode,
    required int numberOfPassengers,
    required double passengerTotalAmount,
    required double passengerTaxesAmount,
    required double passengerBaseAmount,
    required double passengerDiscountAmount,
    required double passengerBeforeDiscountAmount,
    required double passengerServiceChargeAmount,
    required List<FlightFareSegmentDetail> segmentDetails,
  }) = _FlightPassengerFareBreakdown;
}

@freezed
abstract class FlightPriceDetails with _$FlightPriceDetails {
  const factory FlightPriceDetails({
    required double totalAmount,
    required double taxesAmount,
    required double baseAmount,
    required double discountAmount,
    required double beforeDiscountAmount,
    required double serviceChargeAmount,
    required String currency,
  }) = _FlightPriceDetails;
}

/// The order snapshot returned by `POST /flights/{offer_id}/confirm`.
///
/// NOTE: on the demo backend this endpoint returned `200 "Offer confirmed"`
/// even for an offer already rejected as expired by the Bundles endpoint,
/// with no prior Hold/Pending step. That strongly suggests Confirm is
/// stubbed/mocked on demo rather than backed by a real booking — treat this
/// shape as best-effort until verified against a real order.
@freezed
abstract class FlightConfirmedOrder with _$FlightConfirmedOrder {
  const factory FlightConfirmedOrder({
    required String offerId,
    required String journeyId,
    required bool haveBundles,
    required bool canBeHeld,
    required String origin,
    required String destination,
    required int numberOfStops,
    required List<FlightConfirmedSegment> segments,
    required List<FlightPassengerFareBreakdown> passengerFareBreakdown,
    required FlightPriceDetails priceDetails,
    required String refundability,
  }) = _FlightConfirmedOrder;
}
