import 'package:freezed_annotation/freezed_annotation.dart';

part 'flight_iata_airport.freezed.dart';

/// An airport as returned by `GET /flights/iata` — the paginated, id-backed
/// lookup used for broad "search=CAI" style autocomplete.
@freezed
abstract class FlightIataAirport with _$FlightIataAirport {
  const factory FlightIataAirport({
    required int id,
    required String name,
    String? city,
    required String country,
    required String iataCode,
    String? icaoCode,
    required String countryCode,
    double? latitude,
    double? longitude,
  }) = _FlightIataAirport;
}
