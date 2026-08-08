import 'dart:async';

import 'package:safaria/core/network/api_exception.dart';
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
import 'package:safaria/features/flight/domain/repositories/flight_repository.dart';

class FakeFlightRepository implements FlightRepository {
  FakeFlightRepository({
    this.airportSuggestionsResult,
    this.searchResult,
  });

  List<FlightAirportSuggestion>? airportSuggestionsResult;
  List<FlightOffer>? searchResult;
  FlightSearchParams? lastSearchParams;
  String? lastAirportTerm;
  bool searchShouldThrow = false;
  bool airportSearchShouldThrow = false;
  ApiException? searchException;
  ApiException? airportSearchException;
  List<FlightCountry>? countriesResult;
  String? addPassengersResult;
  ApiException? addPassengersException;
  List<FlightPassengerDraft>? lastPassengers;
  FlightContactDetails? lastContact;
  FlightSettings? settingsResult;
  FlightOrder? createOrderResult;
  ApiException? createOrderException;
  Map<String, String>? lastSelectedBundleCodes;
  String? lastCreateOrderOfferId;
  String? lastCreateOrderCurrency;
  List<FlightOrder>? ordersResult;
  FlightOrder? orderResult;
  String? lastOrderId;

  /// Per-term overrides for simulating out-of-order network responses in
  /// tests. When a term has a completer here, `searchAirportSuggestions`
  /// awaits it instead of resolving immediately — the test controls exactly
  /// when (and in what order) each in-flight search "returns" by completing
  /// these directly, rather than racing against debounce/timer arithmetic.
  Map<String, Completer<List<FlightAirportSuggestion>>>?
      airportSearchCompleterByTerm;
  Map<String, List<FlightAirportSuggestion>>? airportSuggestionsResultByTerm;

  static const sampleOrigin = FlightAirportSuggestion(
    iataCode: 'CAI',
    name: 'Cairo Intl Airport',
    city: 'Cairo',
    countryCode: 'EG',
    country: 'EGYPT',
    isDomestic: false,
    isAllAirport: false,
    ranking: 124,
  );

  static const sampleDestination = FlightAirportSuggestion(
    iataCode: 'RUH',
    name: 'King Khalid Intl Airport',
    city: 'Riyadh',
    countryCode: 'SA',
    country: 'SAUDI ARABIA',
    isDomestic: false,
    isAllAirport: false,
    ranking: 90,
  );

  static final sampleOffer = FlightOffer(
    offerId: 'offer-1',
    haveBundles: false,
    canBeHeld: true,
    refundability: 'NotRefundable',
    journeys: [
      FlightJourney(
        id: 'journey-1',
        origin: 'CAI',
        destination: 'RUH',
        numberOfStops: 0,
        segments: [
          FlightSegment(
            id: 'segment-1',
            origin: 'CAI',
            destination: 'RUH',
            departureDateTime: DateTime(2026, 9, 15, 10, 50),
            arrivalDateTime: DateTime(2026, 9, 15, 13, 35),
            flightTimeInMinutes: 165,
            operatingCarrierCode: 'XY',
            operatingFlightNumber: '264',
            marketingCarrierCode: 'XY',
            marketingFlightNumber: '264',
          ),
        ],
      ),
    ],
    totalAmount: 7601,
    taxesAmount: 3141.88,
    baseAmount: 4459.12,
    discountAmount: 0,
    beforeDiscountAmount: 7601,
    serviceChargeAmount: 0,
    currency: 'EGP',
    priceClasses: [],
  );

  @override
  Future<FlightSettings> settings() {
    return Future.value(settingsResult ?? const FlightSettings());
  }

  @override
  Future<(List<FlightIataAirport>, FlightPagination)> searchIataAirports({
    required String search,
    int page = 1,
  }) {
    return Future.value((const <FlightIataAirport>[], FlightPagination.empty));
  }

  @override
  Future<List<FlightAirportSuggestion>> searchAirportSuggestions({
    required String term,
  }) async {
    lastAirportTerm = term;
    if (airportSearchShouldThrow) {
      throw airportSearchException ??
          const ApiException('Something went wrong', statusCode: 500);
    }
    final completer = airportSearchCompleterByTerm?[term];
    if (completer != null) return completer.future;
    return airportSuggestionsResultByTerm?[term] ??
        airportSuggestionsResult ??
        [sampleOrigin, sampleDestination];
  }

  @override
  Future<List<FlightOffer>> search(FlightSearchParams params) {
    lastSearchParams = params;
    if (searchShouldThrow) {
      throw searchException ??
          const ApiException('Something went wrong', statusCode: 500);
    }
    return Future.value(searchResult ?? [sampleOffer]);
  }

  @override
  Future<FlightConfirmedOrder> confirmOrder(String offerId) {
    throw UnimplementedError('Confirm order is out of scope for this slice');
  }

  @override
  Future<List<FlightJourneyBundles>> bundles(String offerId) {
    return Future.value(const []);
  }

  @override
  Future<List<FlightCountry>> countries() {
    return Future.value(countriesResult ?? const []);
  }

  @override
  Future<String> addPassengers({
    required String offerId,
    required List<FlightPassengerDraft> passengers,
    required FlightContactDetails contact,
  }) {
    lastPassengers = passengers;
    lastContact = contact;
    if (addPassengersException != null) throw addPassengersException!;
    return Future.value(addPassengersResult ?? offerId);
  }

  static const sampleOrder = FlightOrder(
    id: '76',
    status: 'pending',
    orderStatus: 'PendingPayment',
    paymentStatus: 'pending',
    totalAmount: 13048.86,
    currency: 'EGP',
    checkoutUrl: 'https://eg.myfatoorah.com/EGY/ia/050714540828552362',
    receiptUrl: 'https://demo.safaria.travel/flight-orders/76/invoice',
  );

  @override
  Future<FlightOrder> createOrder({
    required String offerId,
    required Map<String, String> selectedBundleCodes,
    required String currency,
  }) {
    lastCreateOrderOfferId = offerId;
    lastSelectedBundleCodes = selectedBundleCodes;
    lastCreateOrderCurrency = currency;
    if (createOrderException != null) throw createOrderException!;
    return Future.value(createOrderResult ?? sampleOrder);
  }

  @override
  Future<List<FlightOrder>> orders() {
    return Future.value(ordersResult ?? const []);
  }

  @override
  Future<FlightOrder?> order(String id) {
    lastOrderId = id;
    return Future.value(orderResult ?? sampleOrder);
  }
}
