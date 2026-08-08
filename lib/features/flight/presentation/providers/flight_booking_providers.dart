import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/core/network/dio_client.dart';
import 'package:safaria/features/flight/data/flight_api.dart';
import 'package:safaria/features/flight/data/flight_repository_impl.dart';
import 'package:safaria/features/flight/domain/entities/flight_bundle.dart';
import 'package:safaria/features/flight/domain/entities/flight_confirmed_order.dart';
import 'package:safaria/features/flight/domain/entities/flight_country.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer_filters.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
import 'package:safaria/features/flight/domain/repositories/flight_repository.dart';
import 'package:safaria/features/flight/domain/utils/apply_flight_offer_filters.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_errors.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_rules.dart';

part 'flight_booking_providers.freezed.dart';

enum FlightBookingStatus {
  idle,
  searching,
  confirming,
  loadingBundles,
  submittingPassengers,
  error,
}

final flightApiProvider =
    Provider<FlightApi>((ref) => FlightApi(ref.watch(dioProvider)));

final flightRepositoryProvider = Provider<FlightRepository>(
  (ref) => FlightRepositoryImpl(ref.watch(flightApiProvider)),
);

/// The country list is static for a session — fetch once and reuse across
/// every passenger form.
final flightCountriesProvider = FutureProvider<List<FlightCountry>>((ref) {
  return ref.watch(flightRepositoryProvider).countries();
});

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
    @Default([]) List<FlightPassengerDraft> passengerDrafts,
    @Default(FlightContactDetails()) FlightContactDetails contact,
    String? passengersOfferId,
    @Default(<int, Map<String, String>>{})
    Map<int, Map<String, String>> passengerErrors,
  }) = _FlightBookingState;

  /// The offer id the next call must send. Each step that mints a new id
  /// takes precedence over the one before it: search → confirm → passengers.
  String? get activeOfferId =>
      passengersOfferId ?? confirmedOrder?.offerId ?? selectedOffer?.offerId;
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
      passengerDrafts: [],
      contact: const FlightContactDetails(),
      passengersOfferId: null,
      passengerErrors: {},
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

  void seedPassengerDrafts() {
    if (state.passengerDrafts.isNotEmpty) return;
    final counts = flightPassengerCountsOf(state.searchParams);
    state = state.copyWith(
      passengerDrafts: [
        for (var i = 0; i < counts.adults; i++)
          const FlightPassengerDraft(type: FlightPassengerType.adult),
        for (var i = 0; i < counts.children; i++)
          const FlightPassengerDraft(type: FlightPassengerType.child),
        for (var i = 0; i < counts.infants; i++)
          const FlightPassengerDraft(type: FlightPassengerType.infant),
      ],
    );
  }

  void updatePassengerDraft(int index, FlightPassengerDraft draft) {
    final drafts = List<FlightPassengerDraft>.from(state.passengerDrafts);
    if (index < 0 || index >= drafts.length) return;
    drafts[index] = draft;
    final errors = Map<int, Map<String, String>>.from(state.passengerErrors)
      ..remove(index);
    state = state.copyWith(passengerDrafts: drafts, passengerErrors: errors);
  }

  void setContactDetails(FlightContactDetails contact) {
    state = state.copyWith(contact: contact);
  }

  /// Submits every traveller. On validation failure the errors are pinned to
  /// the passengers they belong to so the list can point at the right row.
  Future<bool> submitPassengers() async {
    final offerId = state.confirmedOrder?.offerId;
    if (offerId == null) return false;
    state = state.copyWith(
      status: FlightBookingStatus.submittingPassengers,
      error: null,
      passengerErrors: {},
    );
    try {
      final newOfferId = await _repo.addPassengers(
        offerId: offerId,
        passengers: state.passengerDrafts,
        contact: state.contact,
      );
      state = state.copyWith(
        status: FlightBookingStatus.idle,
        passengersOfferId: newOfferId,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        status: FlightBookingStatus.error,
        error: e.message,
        passengerErrors: flightPassengerErrorsByIndex(e.errors),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: FlightBookingStatus.error,
        error: e.toString(),
      );
      return false;
    }
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
