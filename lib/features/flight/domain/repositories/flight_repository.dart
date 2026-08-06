import 'package:safaria/features/flight/domain/entities/flight_airport_suggestion.dart';
import 'package:safaria/features/flight/domain/entities/flight_confirmed_order.dart';
import 'package:safaria/features/flight/domain/entities/flight_iata_airport.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_pagination.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';

abstract interface class FlightRepository {
  Future<(List<FlightIataAirport>, FlightPagination)> searchIataAirports({
    required String search,
    int page,
  });

  Future<List<FlightAirportSuggestion>> searchAirportSuggestions({
    required String term,
  });

  Future<List<FlightOffer>> search(FlightSearchParams params);

  /// Finalizes a searched offer into a booked order.
  ///
  /// Unverified on the demo backend as a real booking action — see the
  /// warning on [FlightConfirmedOrder]. Do not surface this as a "confirmed"
  /// state to users without server-side confirmation it actually persists.
  Future<FlightConfirmedOrder> confirmOrder(String offerId);
}
