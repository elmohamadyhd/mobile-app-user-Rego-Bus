import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:safaria/core/network/dio_client.dart';
import 'package:safaria/features/flight/data/flight_api.dart';
import 'package:safaria/features/flight/data/flight_repository_impl.dart';
import 'package:safaria/features/flight/domain/entities/flight_bundle.dart';
import 'package:safaria/features/flight/domain/entities/flight_confirmed_order.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer_filters.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
import 'package:safaria/features/flight/domain/repositories/flight_repository.dart';
import 'package:safaria/features/flight/domain/utils/apply_flight_offer_filters.dart';

part 'flight_booking_providers.freezed.dart';

enum FlightBookingStatus { idle, searching, confirming, loadingBundles, error }

final flightApiProvider =
    Provider<FlightApi>((ref) => FlightApi(ref.watch(dioProvider)));

final flightRepositoryProvider = Provider<FlightRepository>(
  (ref) => FlightRepositoryImpl(ref.watch(flightApiProvider)),
);

@freezed
abstract class FlightBookingState with _$FlightBookingState {
  const FlightBookingState._();

  const factory FlightBookingState({
    FlightSearchParams? searchParams,
    @Default([]) List<FlightOffer> offers,
    @Default(FlightOfferFilters()) FlightOfferFilters filters,
    @Default(FlightBookingStatus.idle) FlightBookingStatus status,
    String? error,
    String? searchFromLabel,
    String? searchToLabel,
    FlightOffer? selectedOffer,
    FlightConfirmedOrder? confirmedOrder,
    @Default(<String, String>{}) Map<String, String> selectedBundleCodes,
    @Default([]) List<FlightJourneyBundles> journeyBundles,
  }) = _FlightBookingState;

  /// The offer id later steps must send. Confirm mints a new one and every
  /// call after it — bundles, passengers, order creation — must use that,
  /// never the id from search. Sending the searched id is what produces
  /// `400 "offer id is not valid or expired"`.
  String? get activeOfferId =>
      confirmedOrder?.offerId ?? selectedOffer?.offerId;
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

  /// Enters the wizard. Clears any state from a previous booking attempt so
  /// a second run cannot inherit the first one's confirmed order.
  void selectOffer(FlightOffer offer) {
    state = state.copyWith(
      selectedOffer: offer,
      confirmedOrder: null,
      journeyBundles: [],
      selectedBundleCodes: {},
      error: null,
    );
  }

  Future<void> confirmSelectedOffer() async {
    final offer = state.selectedOffer;
    if (offer == null) return;
    state = state.copyWith(
      status: FlightBookingStatus.confirming,
      error: null,
    );
    try {
      final confirmed = await _repo.confirmOrder(offer.offerId);
      state = state.copyWith(
        status: FlightBookingStatus.idle,
        confirmedOrder: confirmed,
      );
    } catch (e) {
      state = state.copyWith(
        status: FlightBookingStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> loadBundles() async {
    final offerId = state.activeOfferId;
    if (offerId == null || state.confirmedOrder == null) return;
    state = state.copyWith(
      status: FlightBookingStatus.loadingBundles,
      error: null,
    );
    try {
      final bundles = await _repo.bundles(offerId);
      state = state.copyWith(
        status: FlightBookingStatus.idle,
        journeyBundles: bundles,
      );
    } catch (e) {
      state = state.copyWith(
        status: FlightBookingStatus.error,
        error: e.toString(),
      );
    }
  }

  void selectBundle({required String journeyId, required String bundleCode}) {
    state = state.copyWith(
      selectedBundleCodes: {
        ...state.selectedBundleCodes,
        journeyId: bundleCode,
      },
    );
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
