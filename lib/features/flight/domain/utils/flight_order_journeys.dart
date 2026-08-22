import 'package:safaria/features/flight/domain/entities/flight_order.dart';

/// Longest layover still treated as a connection, not a new journey.
const _maxConnectionLayover = Duration(hours: 12);

/// Groups a flat order [segments] list into journeys (outbound, return, …).
///
/// Hops connect when the next origin matches the previous destination and
/// the layover is at most 12 hours. A single round-trip chain that starts
/// and ends at the same airport is then split in half.
List<List<FlightOrderSegment>> groupFlightOrderJourneys(
  List<FlightOrderSegment> segments,
) {
  if (segments.isEmpty) return const [];

  final chains = <List<FlightOrderSegment>>[];
  var current = <FlightOrderSegment>[segments.first];

  for (var i = 1; i < segments.length; i++) {
    if (_connects(current.last, segments[i])) {
      current.add(segments[i]);
    } else {
      chains.add(current);
      current = [segments[i]];
    }
  }
  chains.add(current);

  if (chains.length == 1 &&
      chains.first.length >= 2 &&
      chains.first.last.destination == chains.first.first.origin) {
    final all = chains.first;
    final split = all.length ~/ 2;
    return [all.sublist(0, split), all.sublist(split)];
  }
  return chains;
}

bool _connects(FlightOrderSegment previous, FlightOrderSegment next) {
  if (previous.destination != next.origin) return false;
  final arrival = previous.arrivalDateTime;
  final departure = next.departureDateTime;
  if (arrival == null || departure == null) return true;
  final layover = departure.difference(arrival);
  return !layover.isNegative && layover <= _maxConnectionLayover;
}
