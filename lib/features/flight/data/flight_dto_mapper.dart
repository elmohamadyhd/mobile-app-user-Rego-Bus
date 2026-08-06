import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/flight/domain/entities/flight_airport_suggestion.dart';
import 'package:safaria/features/flight/domain/entities/flight_confirmed_order.dart';
import 'package:safaria/features/flight/domain/entities/flight_iata_airport.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_pagination.dart';

abstract final class FlightDtoMapper {
  static void ensureSuccess(Map<String, dynamic> envelope) {
    final innerStatus = envelope['status'];
    if (innerStatus is num && innerStatus.toInt() != 200) {
      throw ApiException.fromEnvelope(envelope);
    }
  }

  // ---- IATA airports (GET /flights/iata) ----

  static (List<FlightIataAirport>, FlightPagination) iataAirportsFromEnvelope(
    dynamic body,
  ) {
    final envelope = body as Map<String, dynamic>;
    ensureSuccess(envelope);
    final data = envelope['data'];
    final airports = data is List
        ? data.whereType<Map<String, dynamic>>().map(_iataAirportFromJson).toList()
        : const <FlightIataAirport>[];
    final pagination = envelope['pagination'];
    return (
      airports,
      pagination is Map<String, dynamic>
          ? _paginationFromJson(pagination)
          : FlightPagination.empty,
    );
  }

  static FlightIataAirport _iataAirportFromJson(Map<String, dynamic> json) {
    return FlightIataAirport(
      id: _int(json['id']) ?? 0,
      name: _string(json['name']) ?? '',
      city: _string(json['city']),
      country: _string(json['country']) ?? '',
      iataCode: _string(json['iata_code']) ?? '',
      icaoCode: _string(json['icao_code']),
      countryCode: _string(json['country_code']) ?? '',
      latitude: _double(json['latitude']),
      longitude: _double(json['longitude']),
    );
  }

  static FlightPagination _paginationFromJson(Map<String, dynamic> json) {
    return FlightPagination(
      total: _int(json['total']) ?? 0,
      lastPage: _int(json['lastPage']) ?? 1,
      perPage: _int(json['perPage']) ?? 0,
      currentPage: _int(json['currentPage']) ?? 1,
      nextPageUrl: _string(json['nextPageUrl']),
      previousPageUrl: _string(json['previousPageUrl']),
    );
  }

  // ---- Airport suggestions (GET /flights/airports/search) ----

  static List<FlightAirportSuggestion> airportSuggestionsFromEnvelope(
    dynamic body,
  ) {
    final envelope = body as Map<String, dynamic>;
    ensureSuccess(envelope);
    final data = envelope['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(_airportSuggestionFromJson)
        .toList();
  }

  static FlightAirportSuggestion _airportSuggestionFromJson(
    Map<String, dynamic> json,
  ) {
    return FlightAirportSuggestion(
      iataCode: _string(json['iata_code']) ?? '',
      name: _string(json['name']) ?? '',
      city: _string(json['city']) ?? '',
      countryCode: _string(json['country_code']) ?? '',
      country: _string(json['country']) ?? '',
      latitude: _double(json['latitude']),
      longitude: _double(json['longitude']),
      isDomestic: json['is_domestic'] == true,
      isAllAirport: json['is_all_airport'] == true,
      ranking: _int(json['ranking']) ?? 0,
    );
  }

  // ---- Search (POST /flights/search) ----

  static List<FlightOffer> offersFromEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    ensureSuccess(envelope);
    final data = envelope['data'];
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().map(_offerFromJson).toList();
  }

  static FlightOffer _offerFromJson(Map<String, dynamic> json) {
    final journeys = json['journeys'];
    final priceClasses = json['priceClasses'];
    return FlightOffer(
      offerId: _string(json['offerId']) ?? '',
      haveBundles: json['haveBundles'] == true,
      canBeHeld: json['canBeHeld'] == true,
      refundability: _string(json['refundability']) ?? 'UnKnown',
      journeys: journeys is List
          ? journeys.whereType<Map<String, dynamic>>().map(_journeyFromJson).toList()
          : const [],
      totalAmount: _double(json['totalAmount']) ?? 0,
      taxesAmount: _double(json['taxesAmount']) ?? 0,
      baseAmount: _double(json['baseAmount']) ?? 0,
      discountAmount: _double(json['discountAmount']) ?? 0,
      beforeDiscountAmount: _double(json['beforeDiscountAmount']) ?? 0,
      serviceChargeAmount: _double(json['serviceChargeAmount']) ?? 0,
      currency: _string(json['currency']) ?? '',
      departureDate: _dateTime(json['departureDate']),
      arrivalDate: _dateTime(json['arrivalDate']),
      priceClasses: priceClasses is List
          ? priceClasses
              .whereType<Map<String, dynamic>>()
              .map(_priceClassFromJson)
              .toList()
          : const [],
    );
  }

  static FlightJourney _journeyFromJson(Map<String, dynamic> json) {
    final segments = json['segment'];
    return FlightJourney(
      id: _string(json['id']) ?? '',
      origin: _string(json['origin']) ?? '',
      destination: _string(json['destination']) ?? '',
      numberOfStops: _int(json['numberOfStops']) ?? 0,
      segments: segments is List
          ? segments.whereType<Map<String, dynamic>>().map(_segmentFromJson).toList()
          : const [],
    );
  }

  static FlightSegment _segmentFromJson(Map<String, dynamic> json) {
    return FlightSegment(
      id: _string(json['id']) ?? '',
      origin: _string(json['origin']) ?? '',
      destination: _string(json['destination']) ?? '',
      departureDateTime: _dateTime(json['departureDateTime']) ?? DateTime(1970),
      arrivalDateTime: _dateTime(json['arrivalDateTime']) ?? DateTime(1970),
      departureTerminal: _string(json['departureTerminal']),
      arrivalTerminal: _string(json['arrivalTerminal']),
      flightTimeInMinutes: _int(json['flightTimeInMinutes']) ?? 0,
      operatingCarrierCode: _string(json['operatingCarrierCode']) ?? '',
      operatingCarrierName: _string(json['operatingCarrierName']),
      operatingCarrierLogo: _string(json['operatingCarrierLogo']),
      operatingFlightNumber: _string(json['operatingFlightNumber']) ?? '',
      marketingCarrierCode: _string(json['marketingCarrierCode']) ?? '',
      marketingFlightNumber: _string(json['marketingFlightNumber']) ?? '',
      equipment: _string(json['equipment']),
    );
  }

  static FlightPriceClass _priceClassFromJson(Map<String, dynamic> json) {
    final rules = json['rulesAndPenalties'];
    return FlightPriceClass(
      classId: _string(json['classId']) ?? '',
      priceClassName: _string(json['priceClassName']) ?? '',
      fareType: _string(json['fareType']) ?? '',
      rulesAndPenalties:
          rules is List ? rules.map((e) => e.toString()).toList() : null,
    );
  }

  // ---- Confirm order (POST /flights/{offer_id}/confirm) ----

  static FlightConfirmedOrder confirmedOrderFromEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    ensureSuccess(envelope);
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException.fromEnvelope(envelope);
    }
    final segments = data['segments'];
    final fareBreakdown = data['passengerFareBreakdown'];
    final priceDetails = data['priceDetails'];
    return FlightConfirmedOrder(
      offerId: _string(data['offerId']) ?? '',
      journeyId: _string(data['journey_id']) ?? '',
      haveBundles: data['haveBundles'] == true,
      canBeHeld: data['canBeHeld'] == true,
      origin: _string(data['origin']) ?? '',
      destination: _string(data['destination']) ?? '',
      numberOfStops: _int(data['numberOfStops']) ?? 0,
      segments: segments is List
          ? segments
              .whereType<Map<String, dynamic>>()
              .map(_confirmedSegmentFromJson)
              .toList()
          : const [],
      passengerFareBreakdown: fareBreakdown is List
          ? fareBreakdown
              .whereType<Map<String, dynamic>>()
              .map(_fareBreakdownFromJson)
              .toList()
          : const [],
      priceDetails: priceDetails is Map<String, dynamic>
          ? _priceDetailsFromJson(priceDetails)
          : const FlightPriceDetails(
              totalAmount: 0,
              taxesAmount: 0,
              baseAmount: 0,
              discountAmount: 0,
              beforeDiscountAmount: 0,
              serviceChargeAmount: 0,
              currency: '',
            ),
      refundability: _string(data['refundability']) ?? 'UnKnown',
    );
  }

  static FlightConfirmedSegment _confirmedSegmentFromJson(
    Map<String, dynamic> json,
  ) {
    return FlightConfirmedSegment(
      segmentId: _string(json['segmentId']) ?? '',
      origin: _string(json['origin']) ?? '',
      destination: _string(json['destination']) ?? '',
      departureDateTime: _dateTime(json['departureDateTime']) ?? DateTime(1970),
      arrivalDateTime: _dateTime(json['arrivalDateTime']) ?? DateTime(1970),
      departureTerminal: _string(json['departureTerminal']),
      arrivalTerminal: _string(json['arrivalTerminal']),
      flightTimeInMinutes: _int(json['flightTimeInMinutes']) ?? 0,
      operatingCarrierCode: _string(json['operatingCarrierCode']) ?? '',
      operatingCarrierName: _string(json['operatingCarrierName']),
      operatingCarrierLogo: _string(json['operatingCarrierLogo']),
      operatingFlightNumber: _string(json['operatingFlightNumber']) ?? '',
      marketingCarrierCode: _string(json['marketingCarrierCode']) ?? '',
      marketingFlightNumber: _string(json['marketingFlightNumber']) ?? '',
      equipment: _string(json['equipment']),
      priceClassReferenceId: _string(json['priceClassReferenceId']),
      baggageDetailsReferenceId: _string(json['baggageDetailsReferenceId']),
      cabinCode: _string(json['cabinCode']),
      rbd: _string(json['rbd']),
    );
  }

  static FlightPassengerFareBreakdown _fareBreakdownFromJson(
    Map<String, dynamic> json,
  ) {
    final segmentDetails = json['segmentDetails'];
    return FlightPassengerFareBreakdown(
      passengerTypeCode: _string(json['passengerTypeCode']) ?? '',
      numberOfPassengers: _int(json['numberOfPassengers']) ?? 0,
      passengerTotalAmount: _double(json['passengerTotalAmount']) ?? 0,
      passengerTaxesAmount: _double(json['passengerTaxesAmount']) ?? 0,
      passengerBaseAmount: _double(json['passengerBaseAmount']) ?? 0,
      passengerDiscountAmount: _double(json['passengerDiscountAmount']) ?? 0,
      passengerBeforeDiscountAmount:
          _double(json['passengerBeforeDiscountAmount']) ?? 0,
      passengerServiceChargeAmount:
          _double(json['passengerServiceChargeAmount']) ?? 0,
      segmentDetails: segmentDetails is List
          ? segmentDetails
              .whereType<Map<String, dynamic>>()
              .map(_fareSegmentDetailFromJson)
              .toList()
          : const [],
    );
  }

  static FlightFareSegmentDetail _fareSegmentDetailFromJson(
    Map<String, dynamic> json,
  ) {
    return FlightFareSegmentDetail(
      segmentReferenceId: _string(json['segmentReferenceId']) ?? '',
      priceClassReferenceId: _string(json['priceClassReferenceId']),
      baggageDetailsReferenceId: _string(json['baggageDetailsReferenceId']),
      cabinCode: _string(json['cabinCode']),
      rbd: _string(json['rbd']),
    );
  }

  static FlightPriceDetails _priceDetailsFromJson(Map<String, dynamic> json) {
    return FlightPriceDetails(
      totalAmount: _double(json['totalAmount']) ?? 0,
      taxesAmount: _double(json['taxesAmount']) ?? 0,
      baseAmount: _double(json['baseAmount']) ?? 0,
      discountAmount: _double(json['discountAmount']) ?? 0,
      beforeDiscountAmount: _double(json['beforeDiscountAmount']) ?? 0,
      serviceChargeAmount: _double(json['serviceChargeAmount']) ?? 0,
      currency: _string(json['currency']) ?? '',
    );
  }

  // ---- Search request body ----

  /// Builds the `POST /flights/search` body. Note the backend expects the
  /// misspelled `curreny` key, not `currency` — confirmed against the live
  /// API (`currency` is silently rejected as invalid).
  static Map<String, dynamic> searchRequestBody({
    required String origin,
    required String destination,
    required String date,
    required List<Map<String, dynamic>> passengers,
    required String sortingCriteria,
    required String cabinClass,
    required bool directFlightsOnly,
    required String tripType,
    required String currency,
  }) {
    return {
      'origin': origin,
      'destination': destination,
      'date': date,
      'passengers': passengers,
      'sortingCriteria': sortingCriteria,
      'cabinClass': cabinClass,
      'directFlightsOnly': directFlightsOnly,
      'trip_type': tripType,
      'curreny': currency,
    };
  }

  // ---- primitives ----

  static String? _string(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _double(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static DateTime? _dateTime(dynamic v) {
    if (v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }
}
