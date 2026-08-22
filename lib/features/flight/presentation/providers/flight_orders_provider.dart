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

/// IATA → airport name for tickets. Lookups are best-effort; missing
/// codes stay as IATA on the card.
final flightOrderAirportNamesProvider =
    FutureProvider<Map<String, String>>((ref) async {
  final orders = await ref.watch(flightOrdersProvider.future);
  final codes = <String>{};
  for (final order in orders) {
    for (final segment in order.segments) {
      if (segment.origin.isNotEmpty) codes.add(segment.origin);
      if (segment.destination.isNotEmpty) codes.add(segment.destination);
    }
  }
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
        // Cards still render the IATA code.
      }
    }),
  );
  return names;
});
