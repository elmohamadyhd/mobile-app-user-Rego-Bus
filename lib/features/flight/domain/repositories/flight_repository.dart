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

abstract interface class FlightRepository {
  /// Booking currency and the single payment gateway.
  Future<FlightSettings> settings();

  Future<(List<FlightIataAirport>, FlightPagination)> searchIataAirports({
    required String search,
    int page,
  });

  Future<List<FlightAirportSuggestion>> searchAirportSuggestions({
    required String term,
  });

  Future<List<FlightOffer>> search(FlightSearchParams params);

  /// Re-prices and secures a searched offer, returning a **new offer id**
  /// that every later call must use. See the offer id relay in
  /// `docs/superpowers/specs/2026-08-08-flight-booking-flow-design.md`.
  Future<FlightConfirmedOrder> confirmOrder(String offerId);

  /// Fare bundles for a confirmed offer.
  ///
  /// [offerId] must be the id returned by [confirmOrder], not the one from
  /// [search].
  Future<List<FlightJourneyBundles>> bundles(String offerId);

  /// Countries for nationality, residence, and dial codes.
  Future<List<FlightCountry>> countries();

  /// Attaches travellers to a confirmed offer.
  ///
  /// [offerId] must be the id from [confirmOrder]. Returns a **new** offer id
  /// that order creation must use.
  Future<String> addPassengers({
    required String offerId,
    required List<FlightPassengerDraft> passengers,
  });

  /// Creates the order. [offerId] must be the id returned by
  /// [addPassengers] — the last hop of the relay.
  Future<FlightOrder> createOrder({
    required String offerId,
    required Map<String, String> selectedBundleCodes,
    required String currency,
  });

  Future<List<FlightOrder>> orders();

  Future<FlightOrder?> order(String id);

  Future<void> submitReview({
    required String orderId,
    required int rating,
    String? comment,
  });
}
