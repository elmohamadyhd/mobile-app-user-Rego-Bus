import 'package:rego/features/bus/domain/entities/bus_stop.dart';

/// All boarding stops (by arrival), then all drop-off stops (by arrival) —
/// the same order shown on the trip route timeline.
List<BusStop> orderTripRouteStops({
  required List<BusStop> boardingStops,
  required List<BusStop> dropoffStops,
}) {
  final board = boardingStops.where((stop) => stop != BusStop.empty).toList()
    ..sort(_byArrival);
  final drop = dropoffStops.where((stop) => stop != BusStop.empty).toList()
    ..sort(_byArrival);
  return [...board, ...drop];
}

/// Nulls sort first — a missing `arrivalAt` is treated as the earliest time.
int _byArrival(BusStop a, BusStop b) {
  if (a.arrivalAt == null && b.arrivalAt == null) return 0;
  if (a.arrivalAt == null) return -1;
  if (b.arrivalAt == null) return 1;
  return a.arrivalAt!.compareTo(b.arrivalAt!);
}
