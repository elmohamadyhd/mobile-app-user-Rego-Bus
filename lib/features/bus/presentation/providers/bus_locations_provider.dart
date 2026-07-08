import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/features/bus/domain/entities/bus_location.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';

final busLocationsProvider = FutureProvider<List<BusLocation>>((ref) async {
  return ref.read(busRepositoryProvider).listLocations();
});
