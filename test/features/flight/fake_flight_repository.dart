import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/flight/domain/entities/flight_airport_suggestion.dart';
import 'package:safaria/features/flight/domain/entities/flight_confirmed_order.dart';
import 'package:safaria/features/flight/domain/entities/flight_iata_airport.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_pagination.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
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
  Future<(List<FlightIataAirport>, FlightPagination)> searchIataAirports({
    required String search,
    int page = 1,
  }) {
    return Future.value((const <FlightIataAirport>[], FlightPagination.empty));
  }

  @override
  Future<List<FlightAirportSuggestion>> searchAirportSuggestions({
    required String term,
  }) {
    lastAirportTerm = term;
    if (airportSearchShouldThrow) {
      throw airportSearchException ??
          const ApiException('Something went wrong', statusCode: 500);
    }
    return Future.value(
      airportSuggestionsResult ?? [sampleOrigin, sampleDestination],
    );
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
}
