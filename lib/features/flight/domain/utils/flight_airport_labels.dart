import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';

/// Display names for one journey on the results card.
class FlightJourneyPlaceLabels {
  const FlightJourneyPlaceLabels({
    required this.origin,
    required this.destination,
  });

  final String origin;
  final String destination;
}

/// Picks a display name for one airport.
///
/// Order: the search-picker name for this IATA, then a search-leg fallback
/// (so a city/"all airports" search still has a name when the offer lands
/// at a specific airport), then the raw IATA code.
String flightAirportDisplayName({
  required String iataCode,
  String? fallbackName,
  Map<String, String> namesByIata = const {},
}) {
  final mapped = namesByIata[iataCode]?.trim();
  if (mapped != null && mapped.isNotEmpty) return mapped;
  final fallback = fallbackName?.trim();
  if (fallback != null && fallback.isNotEmpty) return fallback;
  return iataCode;
}

/// Names for journey [index] on a priced offer.
///
/// Round-trip return legs reverse the search from/to labels — the offer's
/// IATA often does not match the searched city code. Multi-city uses the
/// matching search leg so every hop gets a name, not just the first.
FlightJourneyPlaceLabels flightJourneyAirportLabels({
  required int index,
  required FlightJourney journey,
  required FlightTripType tripType,
  List<FlightSearchLeg> searchLegs = const [],
  Map<String, String> namesByIata = const {},
  String? searchFromLabel,
  String? searchToLabel,
}) {
  if (tripType == FlightTripType.roundTrip && index > 0) {
    return FlightJourneyPlaceLabels(
      origin: flightAirportDisplayName(
        iataCode: journey.origin,
        fallbackName: searchToLabel,
        namesByIata: namesByIata,
      ),
      destination: flightAirportDisplayName(
        iataCode: journey.destination,
        fallbackName: searchFromLabel,
        namesByIata: namesByIata,
      ),
    );
  }

  String? originFallback;
  String? destinationFallback;
  if (index < searchLegs.length) {
    originFallback = namesByIata[searchLegs[index].origin];
    destinationFallback = namesByIata[searchLegs[index].destination];
  }
  if (index == 0) {
    originFallback ??= searchFromLabel;
    destinationFallback ??= searchToLabel;
  }

  return FlightJourneyPlaceLabels(
    origin: flightAirportDisplayName(
      iataCode: journey.origin,
      fallbackName: originFallback,
      namesByIata: namesByIata,
    ),
    destination: flightAirportDisplayName(
      iataCode: journey.destination,
      fallbackName: destinationFallback,
      namesByIata: namesByIata,
    ),
  );
}
