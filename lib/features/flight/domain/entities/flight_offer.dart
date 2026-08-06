import 'package:freezed_annotation/freezed_annotation.dart';

part 'flight_offer.freezed.dart';

@freezed
abstract class FlightSegment with _$FlightSegment {
  const factory FlightSegment({
    required String id,
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
  }) = _FlightSegment;
}

/// One leg of a trip (e.g. outbound, or return). [id] is the `journeyKey`
/// referenced later when selecting a bundle for Hold/Pending Trip.
@freezed
abstract class FlightJourney with _$FlightJourney {
  const factory FlightJourney({
    required String id,
    required String origin,
    required String destination,
    required int numberOfStops,
    required List<FlightSegment> segments,
  }) = _FlightJourney;
}

@freezed
abstract class FlightPriceClass with _$FlightPriceClass {
  const factory FlightPriceClass({
    required String classId,
    required String priceClassName,
    required String fareType,
    List<String>? rulesAndPenalties,
  }) = _FlightPriceClass;
}

/// A single priced offer returned by `POST /flights/search`.
///
/// [haveBundles] and [canBeHeld] are effectively mutually exclusive in
/// practice (seen across live search results): bundle-offering providers
/// (e.g. FlyNas) require the Bundles → Hold Trip flow, while others
/// (e.g. Travelport) go straight to Pending Trip via [canBeHeld].
@freezed
abstract class FlightOffer with _$FlightOffer {
  const factory FlightOffer({
    required String offerId,
    required bool haveBundles,
    required bool canBeHeld,
    required String refundability,
    required List<FlightJourney> journeys,
    required double totalAmount,
    required double taxesAmount,
    required double baseAmount,
    required double discountAmount,
    required double beforeDiscountAmount,
    required double serviceChargeAmount,
    required String currency,
    DateTime? departureDate,
    DateTime? arrivalDate,
    required List<FlightPriceClass> priceClasses,
  }) = _FlightOffer;
}
