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
