import 'package:safaria/features/bus/domain/entities/bus_trip.dart';
import 'package:safaria/features/bus/domain/entities/trip_highlight.dart';

/// Marks cheapest / fastest trips in [trips] (ties included; both → bestDeal).
Map<String, TripHighlight> computeTripHighlights(
  List<BusTripSummary> trips,
) {
  if (trips.isEmpty) return {};
  var minPrice = trips.first.terminalPriceEgp;
  var minDuration = trips.first.durationMin;
  for (final t in trips.skip(1)) {
    if (t.terminalPriceEgp < minPrice) minPrice = t.terminalPriceEgp;
    if (t.durationMin < minDuration) minDuration = t.durationMin;
  }
  final map = <String, TripHighlight>{};
  for (final t in trips) {
    final cheap = t.terminalPriceEgp == minPrice;
    final fast = t.durationMin == minDuration;
    if (cheap && fast) {
      map[t.id] = TripHighlight.bestDeal;
    } else if (cheap) {
      map[t.id] = TripHighlight.cheapest;
    } else if (fast) {
      map[t.id] = TripHighlight.fastest;
    }
  }
  return map;
}

int _highlightRank(TripHighlight? h) {
  return switch (h) {
    TripHighlight.bestDeal => 0,
    TripHighlight.cheapest || TripHighlight.fastest => 1,
    null => 2,
  };
}

/// Pins Best deal → other marks → rest, then earliest departure within rank.
List<BusTripSummary> sortTripsWithHighlights(
  List<BusTripSummary> trips,
  Map<String, TripHighlight> highlights,
) {
  final list = [...trips];
  list.sort((a, b) {
    final ra = _highlightRank(highlights[a.id]);
    final rb = _highlightRank(highlights[b.id]);
    if (ra != rb) return ra.compareTo(rb);
    return a.departTime.compareTo(b.departTime);
  });
  return list;
}

/// Whether [highlight] satisfies cheapest/fastest filter flags (union).
bool tripMatchesHighlightFilter({
  required TripHighlight? highlight,
  required bool cheapest,
  required bool fastest,
}) {
  if (!cheapest && !fastest) return true;
  if (highlight == null) return false;
  final matchCheap = cheapest &&
      (highlight == TripHighlight.cheapest ||
          highlight == TripHighlight.bestDeal);
  final matchFast = fastest &&
      (highlight == TripHighlight.fastest ||
          highlight == TripHighlight.bestDeal);
  return matchCheap || matchFast;
}
