import 'package:freezed_annotation/freezed_annotation.dart';

part 'flight_airport_suggestion.freezed.dart';

/// An airport suggestion from `GET /flights/airports/search` — the ranked,
/// non-paginated lookup used for the origin/destination picker. Distinct
/// from [FlightIataAirport]: no numeric id or ICAO code, but carries
/// [ranking] and an "all airports in this city" pseudo-entry
/// ([isAllAirport]) that the IATA endpoint doesn't have.
@freezed
abstract class FlightAirportSuggestion with _$FlightAirportSuggestion {
  const factory FlightAirportSuggestion({
    required String iataCode,
    required String name,
    required String city,
    required String countryCode,
    required String country,
    double? latitude,
    double? longitude,
    required bool isDomestic,
    required bool isAllAirport,
    required int ranking,
  }) = _FlightAirportSuggestion;
}
