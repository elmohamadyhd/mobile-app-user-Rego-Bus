import 'package:flutter/material.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/domain/entities/bus_trip_filters.dart';

/// Sorted, deduplicated operator names from [trips].
List<String> uniqueOperators(List<BusTripSummary> trips) {
  final names = trips.map((t) => t.operatorName).toSet().toList();
  names.sort();
  return names;
}

/// Min and max terminal fare (EGP) across [trips].
(int min, int max) priceBounds(List<BusTripSummary> trips) {
  if (trips.isEmpty) return (0, 0);
  var min = trips.first.terminalPriceEgp;
  var max = min;
  for (final trip in trips.skip(1)) {
    final price = trip.terminalPriceEgp;
    if (price < min) min = price;
    if (price > max) max = price;
  }
  return (min, max);
}

/// Earliest and latest departure (minutes since midnight) across [trips].
(int earliestMin, int latestMin) departBounds(List<BusTripSummary> trips) {
  if (trips.isEmpty) return (0, 24 * 60 - 1);
  var earliest = _minutesSinceMidnight(trips.first.departTime);
  var latest = earliest;
  for (final trip in trips.skip(1)) {
    final mins = _minutesSinceMidnight(trip.departTime);
    if (mins < earliest) earliest = mins;
    if (mins > latest) latest = mins;
  }
  return (earliest, latest);
}

int _minutesSinceMidnight(DateTime dt) => dt.hour * 60 + dt.minute;

TimeOfDay minutesToTimeOfDay(int minutes) {
  return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
}

String formatTimeOfDay(TimeOfDay time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Client-side filter over already-loaded [trips].
List<BusTripSummary> applyBusTripFilters(
  List<BusTripSummary> trips,
  BusTripFilters filters,
) {
  if (!filters.isActive) return trips;
  return trips.where((trip) => _matches(trip, filters)).toList();
}

bool _matches(BusTripSummary trip, BusTripFilters filters) {
  if (filters.operators.isNotEmpty &&
      !filters.operators.contains(trip.operatorName)) {
    return false;
  }
  if (!_matchesDepartTime(trip.departTime, filters)) return false;
  if (!_matchesPrice(trip.terminalPriceEgp, filters)) return false;
  return true;
}

bool _matchesDepartTime(DateTime depart, BusTripFilters filters) {
  final departMin = _minutesSinceMidnight(depart);
  if (filters.departAfter != null) {
    final after = filters.departAfter!;
    final afterMin = after.hour * 60 + after.minute;
    if (departMin < afterMin) return false;
  }
  if (filters.departBefore != null) {
    final before = filters.departBefore!;
    final beforeMin = before.hour * 60 + before.minute;
    if (departMin > beforeMin) return false;
  }
  return true;
}

bool _matchesPrice(int price, BusTripFilters filters) {
  if (filters.minPriceEgp != null && price < filters.minPriceEgp!) {
    return false;
  }
  if (filters.maxPriceEgp != null && price > filters.maxPriceEgp!) {
    return false;
  }
  return true;
}
