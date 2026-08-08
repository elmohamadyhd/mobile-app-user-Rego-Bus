import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/core/utils/date_formatting.dart';
import 'package:safaria/features/flight/domain/entities/flight_airport_suggestion.dart';
import 'package:safaria/features/flight/domain/entities/flight_bundle.dart';
import 'package:safaria/features/flight/domain/entities/flight_confirmed_order.dart';
import 'package:safaria/features/flight/domain/entities/flight_country.dart';
import 'package:safaria/features/flight/domain/entities/flight_iata_airport.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_order.dart';
import 'package:safaria/features/flight/domain/entities/flight_pagination.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
import 'package:safaria/features/flight/domain/entities/flight_settings.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_rules.dart';

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

  /// The demo backend answers an empty search with HTTP 400 and this message
  /// instead of a 200 + empty list. Riders should see "no flights", not a
  /// retryable load error.
  static bool isNoOffersEnvelope(dynamic body) {
    if (body is! Map) return false;
    final message = body['message'];
    if (message is! String) return false;
    return message.toLowerCase().contains('no available offers');
  }

  static List<FlightOffer> offersFromEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    if (isNoOffersEnvelope(envelope)) return const [];
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

  // ---- Settings (GET /settings) ----

  /// Defaults to EGP rather than failing: a missing currency should not stop
  /// a rider booking, and EGP is the only value the backend has ever sent.
  static FlightSettings settingsFromEnvelope(dynamic body) {
    final data = body is Map ? body['data'] : null;
    if (data is! Map) return const FlightSettings();
    return FlightSettings(
      bookingCurrency: _string(data['default_booking_currency']) ?? 'EGP',
      paymentGateway: _string(data['payment_gateway']) ?? '',
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

  // ---- Orders (POST /flights/{offer_id}, GET /profile/flights/orders*) ----

  /// Builds the `POST /flights/{offer_id}` body that creates the order.
  ///
  /// An offer without bundles sends `selectedBundles: []` — confirmed by
  /// product. Do not omit the key.
  ///
  /// Note this endpoint takes `currency` spelled correctly, while
  /// `POST /flights/search` takes `curreny`. The two genuinely disagree.
  static Map<String, dynamic> createOrderBody({
    required Map<String, String> selectedBundleCodes,
    required String currency,
  }) {
    return {
      'selectedBundles': [
        for (final entry in selectedBundleCodes.entries)
          {'journeyKey': entry.key, 'selectedBundleCode': entry.value},
      ],
      'currency': currency,
    };
  }

  static List<FlightOrder> ordersFromEnvelope(dynamic body) {
    final data = body is Map ? body['data'] : null;
    if (data is! List) return const [];
    return data.whereType<Map>().map(_orderFromJson).toList(growable: false);
  }

  static FlightOrder? orderFromEnvelope(dynamic body) {
    final data = body is Map ? body['data'] : null;
    return data is Map ? _orderFromJson(data) : null;
  }

  static FlightOrder _orderFromJson(Map json) {
    final transaction = json['transaction'];
    final passengers = json['passengers'];
    final segments = json['segments'];

    return FlightOrder(
      id: _string(json['id']) ?? '',
      status: _string(json['status']) ?? '',
      orderStatus: _string(json['order_status']) ?? '',
      paymentStatus: transaction is Map
          ? _string(transaction['status'])
          : _string(json['payment_status']),
      airlinePnr: _string(json['airline_pnr']),
      gdsPnr: _string(json['gds_pnr']),
      paidAt: transaction is Map ? _dateTime(transaction['paid_at']) : null,
      totalAmount: _double(json['total_amount']) ?? 0,
      currency: _string(json['currency']) ?? 'EGP',
      checkoutUrl:
          transaction is Map ? _string(transaction['invoice_url']) : null,
      receiptUrl: _string(json['invoice_url']),
      canBeCancelled: json['can_be_cancel'] == true,
      passengers: passengers is List
          ? passengers.whereType<Map>().map(_orderPassengerFromJson).toList()
          : const [],
      segments: segments is List
          ? segments.whereType<Map>().map(_orderSegmentFromJson).toList()
          : const [],
    );
  }

  static FlightOrderPassenger _orderPassengerFromJson(Map json) {
    return FlightOrderPassenger(
      id: _string(json['id']) ?? '',
      passengerTypeCode: _string(json['passenger_type_code']) ?? 'ADT',
      firstName: _string(json['first_name']),
      lastName: _string(json['last_name']),
    );
  }

  static FlightOrderSegment _orderSegmentFromJson(Map json) {
    return FlightOrderSegment(
      id: _string(json['id']) ?? '',
      origin: _string(json['origin']) ?? '',
      destination: _string(json['destination']) ?? '',
      departureDateTime: _dateTime(json['departure_datetime']),
      arrivalDateTime: _dateTime(json['arrival_datetime']),
      marketingCarrierCode: _string(json['marketing_carrier_code']),
      marketingFlightNumber: _string(json['marketing_flight_number']),
    );
  }

  // ---- Bundles (GET /flights/{offer_id}/bundles) ----

  static List<FlightJourneyBundles> journeyBundlesFromEnvelope(dynamic body) {
    final data = body is Map ? body['data'] : null;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(_journeyBundlesFromJson)
        .toList(growable: false);
  }

  static FlightJourneyBundles _journeyBundlesFromJson(Map json) {
    final bundles = json['bundles'];
    return FlightJourneyBundles(
      offerJourneyId: _string(json['offer_journey_id']) ?? '',
      bundles: bundles is List
          ? bundles.whereType<Map>().map(_bundleFromJson).toList()
          : const [],
    );
  }

  static FlightBundle _bundleFromJson(Map json) {
    final services = json['included_services'];
    return FlightBundle(
      code: _string(json['bundle_code']) ?? '',
      name: _string(json['bundle_name']) ?? '',
      prices: _bundlePrices(json['bundle_prices']),
      includedServices: services is List
          ? services.map((s) => s.toString()).toList()
          : const [],
    );
  }

  /// `bundle_prices` arrives as a single object on some providers and an
  /// array on others. Normalizing to a list here means the pricing rules
  /// downstream only handle one shape.
  static List<FlightBundlePrice> _bundlePrices(dynamic raw) {
    if (raw is Map) return [_bundlePriceFromJson(raw)];
    if (raw is List) {
      return raw.whereType<Map>().map(_bundlePriceFromJson).toList();
    }
    return const [];
  }

  static FlightBundlePrice _bundlePriceFromJson(Map json) {
    return FlightBundlePrice(
      passengerTypeCode: _string(json['passenger_type_code']) ?? 'ADT',
      totalAmount: _double(json['total_amount']) ?? 0,
      taxesAmount: _double(json['taxes_amount']) ?? 0,
      feeAmount: _double(json['fee_mount']) ?? 0,
      currency: _string(json['currency']),
      bundleReferences: _string(json['bundle_references']),
    );
  }

  // ---- Search request body ----

  /// Builds the `POST /flights/search` body. Note the backend expects the
  /// misspelled `curreny` key, not `currency` — confirmed against the live
  /// API (`currency` is silently rejected as invalid).
  /// Builds the `POST /flights/search` body.
  ///
  /// Multi-city replaces the flat `origin`/`destination`/`date` trio with a
  /// `segments` array; round-trip keeps the trio and adds `return_date`.
  ///
  /// The backend expects the misspelled `curreny` key here — `currency` is
  /// silently rejected. Note that the *order creation* endpoint wants the
  /// correct spelling; the two endpoints genuinely disagree.
  static Map<String, dynamic> searchRequestBody({
    required FlightTripType tripType,
    required List<Map<String, String>> legs,
    required List<Map<String, dynamic>> passengers,
    required String sortingCriteria,
    required String cabinClass,
    required bool directFlightsOnly,
    required String currency,
    String? returnDate,
  }) {
    final common = <String, dynamic>{
      'passengers': passengers,
      'sortingCriteria': sortingCriteria,
      'cabinClass': cabinClass,
      'directFlightsOnly': directFlightsOnly,
      'trip_type': tripType.wireValue,
      'curreny': currency,
    };

    if (tripType == FlightTripType.multiCity) {
      return {'segments': legs, ...common};
    }

    final leg = legs.first;
    return {
      'origin': leg['origin'],
      'destination': leg['destination'],
      'date': leg['date'],
      if (tripType == FlightTripType.roundTrip && returnDate != null)
        'return_date': returnDate,
      ...common,
    };
  }

  /// Builds the `POST /flights/{offer_id}/passengers` body.
  ///
  /// [contact] is written onto every traveller: the endpoint takes an email
  /// and phone per passenger, but they are the booker's in practice.
  ///
  /// Address is required by the live backend (Phase 3 Task 1 spike).
  static Map<String, dynamic> passengersRequestBody({
    required List<FlightPassengerDraft> passengers,
    required FlightContactDetails contact,
  }) {
    return {
      'passengers': [
        for (final p in passengers)
          {
            'title': p.title ?? '',
            'firstName': p.firstName ?? '',
            'middleName': p.middleName ?? '',
            'lastName': p.lastName ?? '',
            'birthDate': p.birthDate == null ? '' : toIsoDate(p.birthDate!),
            'documentNumber': p.documentNumber ?? '',
            'nationalityCountryCode': p.nationalityCode ?? '',
            'residenceCountryCode': p.residenceCode ?? '',
            'gender': p.gender ?? '',
            'email': contact.email,
            'phone': contact.phone,
            'passengerTypeCode': flightPassengerWireCode(p.type),
            'address': {
              'countryCode': p.addressCountryCode ?? '',
              'cityCode': p.addressCityCode ?? '',
              'line1': p.addressLine1 ?? '',
              'line2': p.addressLine2 ?? '',
            },
          },
      ],
    };
  }

  /// Reads `data.offerId` — the id minted by confirm and again by adding
  /// passengers. Every later call must use the most recent one.
  static String? offerIdFromEnvelope(dynamic body) {
    final data = body is Map ? body['data'] : null;
    return data is Map ? _string(data['offerId']) : null;
  }

  // ---- Countries (GET /countries) ----

  static List<FlightCountry> countriesFromEnvelope(dynamic body) {
    final data = body is Map ? body['data'] : null;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(_countryFromJson)
        .whereType<FlightCountry>()
        .toList(growable: false);
  }

  /// Rows missing a name or either ISO code are unusable in a picker, so they
  /// are dropped rather than rendered as blanks.
  static FlightCountry? _countryFromJson(Map<dynamic, dynamic> json) {
    final name = _string(json['name']);
    final iso2 = _string(json['iso2']);
    final iso3 = _string(json['iso3']);
    if (name == null || iso2 == null || iso3 == null) return null;
    return FlightCountry(
      name: name,
      iso2: iso2,
      iso3: iso3,
      phoneCode: _string(json['phonecode']) ?? '',
    );
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
