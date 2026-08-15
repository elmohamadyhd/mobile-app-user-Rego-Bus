import 'package:safaria/features/bus/domain/entities/bus_trip.dart';

/// Outcome of folding one search round into a list already held.
typedef BusTripMerge = ({List<BusTripSummary> trips, bool changed});

/// Upserts [incoming] into [existing], keyed on trip id.
///
/// `/buses/trips` aggregates several operator APIs and answers with whatever
/// has landed so far, so a later round is usually — but not reliably — a
/// superset of an earlier one. The merge therefore adds and replaces but never
/// removes: a trip that drops out of a later response stays on screen rather
/// than vanishing while the rider is looking at it.
///
/// [changed] is true when an id was added, or an existing entry was replaced by
/// a non-equal one (price and seat counts go stale between rounds). It is what
/// the caller's "two quiet rounds means the search settled" rule reads.
BusTripMerge mergeBusTrips(
  List<BusTripSummary> existing,
  List<BusTripSummary> incoming,
) {
  final byId = <String, BusTripSummary>{};
  final order = <String>[];

  for (final trip in existing) {
    if (byId.containsKey(trip.id)) continue;
    byId[trip.id] = trip;
    order.add(trip.id);
  }

  var changed = false;
  for (final trip in incoming) {
    final held = byId[trip.id];
    if (held == null) {
      byId[trip.id] = trip;
      order.add(trip.id);
      changed = true;
    } else if (held != trip) {
      byId[trip.id] = trip;
      changed = true;
    }
  }

  return (trips: [for (final id in order) byId[id]!], changed: changed);
}
