import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/network/dio_client.dart';
import 'package:safaria/features/flight/data/flight_api.dart';
import 'package:safaria/features/flight/data/flight_repository_impl.dart';
import 'package:safaria/features/flight/domain/repositories/flight_repository.dart';

final flightApiProvider =
    Provider<FlightApi>((ref) => FlightApi(ref.watch(dioProvider)));

final flightRepositoryProvider = Provider<FlightRepository>(
  (ref) => FlightRepositoryImpl(ref.watch(flightApiProvider)),
);
