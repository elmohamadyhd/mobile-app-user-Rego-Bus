import 'package:dio/dio.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/flight/data/flight_api.dart';
import 'package:safaria/features/flight/data/flight_dto_mapper.dart';
import 'package:safaria/features/flight/domain/entities/flight_airport_suggestion.dart';
import 'package:safaria/features/flight/domain/entities/flight_confirmed_order.dart';
import 'package:safaria/features/flight/domain/entities/flight_iata_airport.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_pagination.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
import 'package:safaria/features/flight/domain/repositories/flight_repository.dart';

class FlightRepositoryImpl implements FlightRepository {
  FlightRepositoryImpl(this._api);

  final FlightApi _api;

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
      final body = await _api.search(
        FlightDtoMapper.searchRequestBody(
          origin: params.origin,
          destination: params.destination,
          date: _yMd(params.date),
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
          tripType: params.tripType.wireValue,
          currency: params.currency,
        ),
      );
      return FlightDtoMapper.offersFromEnvelope(body);
    });
  }

  @override
  Future<FlightConfirmedOrder> confirmOrder(String offerId) {
    return _guard(() async {
      final body = await _api.confirmOrder(offerId);
      return FlightDtoMapper.confirmedOrderFromEnvelope(body);
    });
  }

  static String _yMd(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
