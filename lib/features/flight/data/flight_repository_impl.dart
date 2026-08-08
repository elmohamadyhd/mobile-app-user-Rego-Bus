import 'package:dio/dio.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/core/utils/date_formatting.dart';
import 'package:safaria/features/flight/data/flight_api.dart';
import 'package:safaria/features/flight/data/flight_dto_mapper.dart';
import 'package:safaria/features/flight/domain/entities/flight_airport_suggestion.dart';
import 'package:safaria/features/flight/domain/entities/flight_bundle.dart';
import 'package:safaria/features/flight/domain/entities/flight_confirmed_order.dart';
import 'package:safaria/features/flight/domain/entities/flight_country.dart';
import 'package:safaria/features/flight/domain/entities/flight_iata_airport.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_pagination.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
import 'package:safaria/features/flight/domain/entities/flight_settings.dart';
import 'package:safaria/features/flight/domain/repositories/flight_repository.dart';

class FlightRepositoryImpl implements FlightRepository {
  FlightRepositoryImpl(this._api);

  final FlightApi _api;

  @override
  Future<FlightSettings> settings() {
    return _guard(() async {
      final body = await _api.settings();
      return FlightDtoMapper.settingsFromEnvelope(body);
    });
  }

  @override
  Future<(List<FlightIataAirport>, FlightPagination)> searchIataAirports({
    required String search,
    int page = 1,
  }) {
    return _guard(() async {
      final body = await _api.searchIata(search: search, page: page);
      return FlightDtoMapper.iataAirportsFromEnvelope(body);
    });
  }

  @override
  Future<List<FlightAirportSuggestion>> searchAirportSuggestions({
    required String term,
  }) {
    return _guard(() async {
      final body = await _api.searchAirports(term: term);
      return FlightDtoMapper.airportSuggestionsFromEnvelope(body);
    });
  }

  @override
  Future<List<FlightOffer>> search(FlightSearchParams params) {
    return _guard(() async {
      try {
        final body = await _api.search(
          FlightDtoMapper.searchRequestBody(
            tripType: params.tripType,
            legs: params.legs
                .map(
                  (leg) => {
                    'origin': leg.origin,
                    'destination': leg.destination,
                    'date': toIsoDate(leg.date),
                  },
                )
                .toList(),
            returnDate: params.returnDate == null
                ? null
                : toIsoDate(params.returnDate!),
            passengers: params.passengers
                .map(
                  (p) => {
                    'passengerTypeCode': p.passengerTypeCode,
                    'count': p.count,
                  },
                )
                .toList(),
            sortingCriteria: params.sortingCriteria.wireValue,
            cabinClass: params.cabinClass.wireValue,
            directFlightsOnly: params.directFlightsOnly,
            currency: params.currency,
          ),
        );
        return FlightDtoMapper.offersFromEnvelope(body);
      } on DioException catch (e) {
        // Backend uses HTTP 400 + "No available offers !" for empty results.
        if (FlightDtoMapper.isNoOffersEnvelope(e.response?.data)) {
          return const [];
        }
        rethrow;
      }
    });
  }

  @override
  Future<FlightConfirmedOrder> confirmOrder(String offerId) {
    return _guard(() async {
      final body = await _api.confirmOrder(offerId);
      return FlightDtoMapper.confirmedOrderFromEnvelope(body);
    });
  }

  @override
  Future<List<FlightJourneyBundles>> bundles(String offerId) {
    return _guard(() async {
      final body = await _api.bundles(offerId);
      return FlightDtoMapper.journeyBundlesFromEnvelope(body);
    });
  }

  @override
  Future<List<FlightCountry>> countries() {
    return _guard(() async {
      final body = await _api.countries();
      return FlightDtoMapper.countriesFromEnvelope(body);
    });
  }

  @override
  Future<String> addPassengers({
    required String offerId,
    required List<FlightPassengerDraft> passengers,
    required FlightContactDetails contact,
  }) {
    return _guard(() async {
      final body = await _api.addPassengers(
        offerId: offerId,
        body: FlightDtoMapper.passengersRequestBody(
          passengers: passengers,
          contact: contact,
        ),
      );
      final newOfferId = FlightDtoMapper.offerIdFromEnvelope(body);
      if (newOfferId == null || newOfferId.isEmpty) {
        throw const ApiException(
          'The booking did not return an offer reference. Please try again.',
        );
      }
      return newOfferId;
    });
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
