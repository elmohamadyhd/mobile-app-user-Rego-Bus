import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';

/// Hard cap on one flight booking.
const kMaxFlightPassengers = 9;

/// Why an increment is unavailable. [none] means it is available.
enum FlightPassengerLimit { none, maxTotal, infantsPerAdult }

FlightPassengerLimit flightPassengerLimit(
  FlightPassengerCounts counts,
  FlightPassengerType type,
) {
  if (counts.total >= kMaxFlightPassengers) {
    return FlightPassengerLimit.maxTotal;
  }
  if (type == FlightPassengerType.infant && counts.infants >= counts.adults) {
    return FlightPassengerLimit.infantsPerAdult;
  }
  return FlightPassengerLimit.none;
}

bool canAddFlightPassenger(
  FlightPassengerCounts counts,
  FlightPassengerType type,
) =>
    flightPassengerLimit(counts, type) == FlightPassengerLimit.none;

/// Removing an adult is blocked when it would leave the party without an
/// adult, or leave an infant without one to travel with.
bool canRemoveFlightPassenger(
  FlightPassengerCounts counts,
  FlightPassengerType type,
) {
  return switch (type) {
    FlightPassengerType.adult =>
      counts.adults > 1 && counts.adults - 1 >= counts.infants,
    FlightPassengerType.child => counts.children > 0,
    FlightPassengerType.infant => counts.infants > 0,
  };
}

String flightPassengerWireCode(FlightPassengerType type) => switch (type) {
      FlightPassengerType.adult => 'ADT',
      FlightPassengerType.child => 'CHD',
      FlightPassengerType.infant => 'INF',
    };

/// Search-request form. Types with a zero count are omitted entirely.
List<FlightPassengerCount> toWirePassengers(FlightPassengerCounts counts) {
  return [
    if (counts.adults > 0)
      FlightPassengerCount(passengerTypeCode: 'ADT', count: counts.adults),
    if (counts.children > 0)
      FlightPassengerCount(passengerTypeCode: 'CHD', count: counts.children),
    if (counts.infants > 0)
      FlightPassengerCount(passengerTypeCode: 'INF', count: counts.infants),
  ];
}

/// Rebuilds the UI-side counts from the wire list held in search params.
FlightPassengerCounts flightPassengerCountsOf(FlightSearchParams? params) {
  if (params == null) return const FlightPassengerCounts();
  var counts = const FlightPassengerCounts(adults: 0);
  for (final passenger in params.passengers) {
    counts = switch (passenger.passengerTypeCode) {
      'CHD' => counts.copyWith(children: passenger.count),
      'INF' => counts.copyWith(infants: passenger.count),
      _ => counts.copyWith(adults: passenger.count),
    };
  }
  return counts;
}
