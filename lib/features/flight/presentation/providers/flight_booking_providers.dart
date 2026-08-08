import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:safaria/core/network/dio_client.dart';
import 'package:safaria/features/flight/data/flight_api.dart';
import 'package:safaria/features/flight/data/flight_repository_impl.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer_filters.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
import 'package:safaria/features/flight/domain/repositories/flight_repository.dart';
import 'package:safaria/features/flight/domain/utils/apply_flight_offer_filters.dart';

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
    @Default(FlightOfferFilters()) FlightOfferFilters filters,
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

  /// Runs a server-side search. [preserveFilters] is true when the rider
  /// changed a server-backed control from the filter sheet — their local
  /// filters carry over onto the new results. A brand-new search from the
  /// form clears them.
  Future<void> search(
    FlightSearchParams params, {
    bool preserveFilters = false,
  }) async {
    state = state.copyWith(
      status: FlightBookingStatus.searching,
      searchParams: params,
      error: null,
      offers: [],
      filters: preserveFilters ? state.filters : const FlightOfferFilters(),
    );
    try {
      final offers = await _repo.search(params);
      state = state.copyWith(
        status: FlightBookingStatus.idle,
        offers: offers,
        filters: preserveFilters
            ? preserveFlightFilters(filters: state.filters, offers: offers)
            : const FlightOfferFilters(),
      );
    } catch (e) {
      state = state.copyWith(
        status: FlightBookingStatus.error,
        error: e.toString(),
      );
    }
  }

  void setFilters(FlightOfferFilters filters) {
    state = state.copyWith(filters: filters);
  }
}

final flightBookingProvider =
    NotifierProvider<FlightBookingNotifier, FlightBookingState>(
  FlightBookingNotifier.new,
);

/// Offers after local filtering. The results list watches this; the filter
/// sheet derives its options from the unfiltered `offers`.
final flightFilteredOffersProvider = Provider<List<FlightOffer>>((ref) {
  final state = ref.watch(flightBookingProvider);
  return applyFlightOfferFilters(state.offers, state.filters);
});
