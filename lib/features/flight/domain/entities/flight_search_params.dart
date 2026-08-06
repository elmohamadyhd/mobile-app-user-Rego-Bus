import 'package:freezed_annotation/freezed_annotation.dart';

part 'flight_search_params.freezed.dart';

enum FlightTripType {
  oneWay('one_way'),
  roundTrip('round_trip'),
  multiCity('multi_city');

  const FlightTripType(this.wireValue);

  final String wireValue;
}

enum FlightCabinClass {
  economy('CABIN_CLASS_ECONOMY'),
  premiumEconomy('CABIN_CLASS_PREMIUM_ECONOMY'),
  business('CABIN_CLASS_BUSINESS'),
  first('CABIN_CLASS_FIRST'),
  unspecified('CABIN_CLASS_UNSPECIFIED');

  const FlightCabinClass(this.wireValue);

  final String wireValue;
}

enum FlightSortingCriteria {
  cheapestFirst('CheapestFirst'),
  fastestFirst('FastestFirst'),
  slowestFirst('SlowestFirst'),
  mostExpensiveFirst('MostExpensiveFirst'),
  earliestDepartureFirst('EarliestDepartureFirst'),
  latestDepartureFirst('LatestDepartureFirst');

  const FlightSortingCriteria(this.wireValue);

  final String wireValue;
}

@freezed
abstract class FlightPassengerCount with _$FlightPassengerCount {
  const factory FlightPassengerCount({
    required String passengerTypeCode, // ADT, CHD, INF
    required int count,
  }) = _FlightPassengerCount;
}

/// Params for `POST /flights/search`.
///
/// Only the one-way shape is confirmed against the live API. Round-trip and
/// multi-city searches almost certainly need extra fields (e.g. multiple
/// origin/destination/date legs) not present in the documented Postman
/// request body — confirm the real shape before wiring those trip types up.
@freezed
abstract class FlightSearchParams with _$FlightSearchParams {
  const factory FlightSearchParams({
    required String origin,
    required String destination,
    required DateTime date,
    required List<FlightPassengerCount> passengers,
    @Default(FlightSortingCriteria.cheapestFirst)
    FlightSortingCriteria sortingCriteria,
    @Default(FlightCabinClass.economy) FlightCabinClass cabinClass,
    @Default(false) bool directFlightsOnly,
    @Default(FlightTripType.oneWay) FlightTripType tripType,
    required String currency,
  }) = _FlightSearchParams;
}
