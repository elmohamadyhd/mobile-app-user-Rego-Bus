import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/features/flight/domain/entities/flight_order.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';

/// Flight orders for My Tickets. Refreshed after a payment returns so a
/// newly paid booking appears without a restart.
final flightOrdersProvider = FutureProvider<List<FlightOrder>>((ref) {
  return ref.watch(flightRepositoryProvider).orders();
});

final flightOrderProvider =
    FutureProvider.family<FlightOrder?, String>((ref, id) {
  return ref.watch(flightRepositoryProvider).order(id);
});

/// Sorted unique IATA codes from [orders], used as a names-provider key.
String packedFlightAirportCodes(Iterable<FlightOrder> orders) {
  final codes = <String>{};
  for (final order in orders) {
    for (final segment in order.segments) {
      if (segment.origin.isNotEmpty) codes.add(segment.origin);
      if (segment.destination.isNotEmpty) codes.add(segment.destination);
    }
  }
  final sorted = codes.toList()..sort();
  return sorted.join(',');
}

/// IATA → airport name. Lookups are best-effort; missing codes stay as IATA.
final flightAirportNamesProvider =
    FutureProvider.family<Map<String, String>, String>((ref, packed) async {
  final codes = packed.split(',').where((code) => code.isNotEmpty).toSet();
  if (codes.isEmpty) return const {};

  final repo = ref.watch(flightRepositoryProvider);
  final names = <String, String>{};
  await Future.wait(
    codes.map((code) async {
      try {
        final results = await repo.searchAirportSuggestions(term: code);
        for (final result in results) {
          if (result.iataCode == code && !result.isAllAirport) {
            names[code] = result.name;
            return;
          }
        }
        for (final result in results) {
          if (result.iataCode == code) {
            names[code] = result.name;
            return;
          }
        }
      } on Object {
        // Cards and details still render the IATA code.
      }
    }),
  );
  return names;
});

/// Names for every airport on the current My Tickets list.
final flightOrderAirportNamesProvider =
    FutureProvider<Map<String, String>>((ref) async {
  final orders = await ref.watch(flightOrdersProvider.future);
  return ref.watch(
    flightAirportNamesProvider(packedFlightAirportCodes(orders)).future,
  );
});
