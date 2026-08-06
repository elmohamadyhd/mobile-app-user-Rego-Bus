import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:safaria/core/network/dio_client.dart';
import 'package:safaria/features/flight/data/flight_api.dart';
import 'package:safaria/features/flight/data/flight_repository_impl.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
import 'package:safaria/features/flight/domain/repositories/flight_repository.dart';

part 'flight_booking_providers.freezed.dart';

enum FlightBookingStatus { idle, searching, error }

final flightApiProvider =
    Provider<FlightApi>((ref) => FlightApi(ref.watch(dioProvider)));

final flightRepositoryProvider = Provider<FlightRepository>(
  (ref) => FlightRepositoryImpl(ref.watch(flightApiProvider)),
);

@freezed
abstract class FlightBookingState with _$FlightBookingState {
  const factory FlightBookingState({
    FlightSearchParams? searchParams,
    @Default([]) List<FlightOffer> offers,
    @Default(FlightBookingStatus.idle) FlightBookingStatus status,
    String? error,
    String? searchFromLabel,
    String? searchToLabel,
  }) = _FlightBookingState;
}

class FlightBookingNotifier extends Notifier<FlightBookingState> {
  FlightRepository get _repo => ref.read(flightRepositoryProvider);

  @override
  FlightBookingState build() => const FlightBookingState();

  void setSearchLabels({required String from, required String to}) {
    state = state.copyWith(searchFromLabel: from, searchToLabel: to);
  }

  Future<void> search(FlightSearchParams params) async {
    state = state.copyWith(
      status: FlightBookingStatus.searching,
      searchParams: params,
      error: null,
      offers: [],
    );
    try {
      final offers = await _repo.search(params);
      state = state.copyWith(status: FlightBookingStatus.idle, offers: offers);
    } catch (e) {
      state = state.copyWith(
        status: FlightBookingStatus.error,
        error: e.toString(),
      );
    }
  }
}

final flightBookingProvider =
    NotifierProvider<FlightBookingNotifier, FlightBookingState>(
  FlightBookingNotifier.new,
);
