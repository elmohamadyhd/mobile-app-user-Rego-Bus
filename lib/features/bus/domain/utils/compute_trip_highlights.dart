import 'package:safaria/features/bus/domain/entities/bus_trip.dart';
import 'package:safaria/features/bus/domain/entities/trip_highlight.dart';

/// Marks cheapest / fastest trips in [trips] (ties included; both flags when dual).
Map<String, TripHighlights> computeTripHighlights(
  List<BusTripSummary> trips,
) {
  if (trips.isEmpty) return {};
  var minPrice = trips.first.terminalPriceEgp;
  var minDuration = trips.first.durationMin;
  for (final t in trips.skip(1)) {
    if (t.terminalPriceEgp < minPrice) minPrice = t.terminalPriceEgp;
    if (t.durationMin < minDuration) minDuration = t.durationMin;
  }
  final map = <String, TripHighlights>{};
  for (final t in trips) {
    final cheap = t.terminalPriceEgp == minPrice;
    final fast = t.durationMin == minDuration;
    if (cheap || fast) {
      map[t.id] = TripHighlights(isCheapest: cheap, isFastest: fast);
    }
  }
  return map;
}

int _highlightRank(TripHighlights? h) {
  if (h == null || !h.hasAny) return 2;
  if (h.isDualWinner) return 0;
  return 1;
}

/// Pins dual winners → other marks → rest, then earliest departure within rank.
List<BusTripSummary> sortTripsWithHighlights(
  List<BusTripSummary> trips,
  Map<String, TripHighlights> highlights,
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
  required TripHighlights? highlight,
  required bool cheapest,
  required bool fastest,
}) {
  if (!cheapest && !fastest) return true;
  if (highlight == null || !highlight.hasAny) return false;
  final matchCheap = cheapest && highlight.isCheapest;
  final matchFast = fastest && highlight.isFastest;
  return matchCheap || matchFast;
}
