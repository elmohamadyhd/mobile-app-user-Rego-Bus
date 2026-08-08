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

/// One origin→destination hop on a given date. One-way and round-trip
/// searches carry exactly one; multi-city carries one per city pair.
@freezed
abstract class FlightSearchLeg with _$FlightSearchLeg {
  const factory FlightSearchLeg({
    required String origin,
    required String destination,
    required DateTime date,
  }) = _FlightSearchLeg;
}

/// Params for `POST /flights/search`.
///
/// [legs] is the single source of truth for the route. [returnDate] applies
/// only to [FlightTripType.roundTrip]; multi-city expresses the return as
/// another entry in [legs].
@freezed
abstract class FlightSearchParams with _$FlightSearchParams {
  const FlightSearchParams._();

  const factory FlightSearchParams({
    required List<FlightSearchLeg> legs,
    DateTime? returnDate,
    required List<FlightPassengerCount> passengers,
    @Default(FlightSortingCriteria.cheapestFirst)
    FlightSortingCriteria sortingCriteria,
    @Default(FlightCabinClass.economy) FlightCabinClass cabinClass,
    @Default(false) bool directFlightsOnly,
    @Default(FlightTripType.oneWay) FlightTripType tripType,
    required String currency,
  }) = _FlightSearchParams;

  FlightSearchLeg get firstLeg => legs.first;
}
