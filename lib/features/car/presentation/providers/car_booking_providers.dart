import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/core/network/dio_client.dart';
import 'package:safaria/features/car/data/car_api.dart';
import 'package:safaria/features/car/data/car_repository_impl.dart';
import 'package:safaria/features/car/domain/entities/car_search_params.dart';
import 'package:safaria/features/car/domain/entities/car_trip_quote.dart';
import 'package:safaria/features/car/domain/repositories/car_repository.dart';

final carApiProvider =
    Provider<CarApi>((ref) => CarApi(ref.watch(dioProvider)));

final carRepositoryProvider = Provider<CarRepository>(
  (ref) => CarRepositoryImpl(ref.watch(carApiProvider)),
);

class CarBookingState {
  const CarBookingState({
    this.searchParams,
    this.quotes = const [],
    this.selectedQuote,
    this.isLoadingQuotes = false,
    this.quotesError,
    this.needsAuthRetry = false,
    this.isLoadingTripDetails = false,
    this.tripDetailsHardError,
    this.tripDetailsSoftError,
  });

  final CarSearchParams? searchParams;
  final List<CarTripQuote> quotes;
  final CarTripQuote? selectedQuote;
  final bool isLoadingQuotes;
  final String? quotesError;
  final bool needsAuthRetry;
  final bool isLoadingTripDetails;
  final String? tripDetailsHardError;
  final String? tripDetailsSoftError;

  CarBookingState copyWith({
    CarSearchParams? searchParams,
    List<CarTripQuote>? quotes,
    CarTripQuote? selectedQuote,
    bool? isLoadingQuotes,
    String? quotesError,
    bool? needsAuthRetry,
    bool? isLoadingTripDetails,
    String? tripDetailsHardError,
    String? tripDetailsSoftError,
    bool clearQuotesError = false,
    bool clearSelectedQuote = false,
    bool clearTripDetailsHardError = false,
    bool clearTripDetailsSoftError = false,
  }) {
    return CarBookingState(
      searchParams: searchParams ?? this.searchParams,
      quotes: quotes ?? this.quotes,
      selectedQuote:
          clearSelectedQuote ? null : (selectedQuote ?? this.selectedQuote),
      isLoadingQuotes: isLoadingQuotes ?? this.isLoadingQuotes,
      quotesError: clearQuotesError ? null : (quotesError ?? this.quotesError),
      needsAuthRetry: needsAuthRetry ?? this.needsAuthRetry,
      isLoadingTripDetails: isLoadingTripDetails ?? this.isLoadingTripDetails,
      tripDetailsHardError: clearTripDetailsHardError
          ? null
          : (tripDetailsHardError ?? this.tripDetailsHardError),
      tripDetailsSoftError: clearTripDetailsSoftError
          ? null
          : (tripDetailsSoftError ?? this.tripDetailsSoftError),
    );
  }
}

class CarBookingNotifier extends Notifier<CarBookingState> {
  CarRepository get _repo => ref.read(carRepositoryProvider);

  @override
  CarBookingState build() => const CarBookingState();

  Future<void> searchQuotes(CarSearchParams params) async {
    state = state.copyWith(
      searchParams: params,
      isLoadingQuotes: true,
      quotes: [],
      clearQuotesError: true,
      needsAuthRetry: false,
      clearSelectedQuote: true,
    );
    try {
      final quotes = await _repo.searchQuotes(params);
      state = state.copyWith(
        isLoadingQuotes: false,
        quotes: quotes,
        selectedQuote: quotes.isEmpty ? null : quotes.first,
        clearSelectedQuote: quotes.isEmpty,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoadingQuotes: false,
        quotesError: e.message,
        needsAuthRetry: e.statusCode == 401,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingQuotes: false,
        quotesError: e.toString(),
      );
    }
  }

  void selectQuote(CarTripQuote quote) {
    state = state.copyWith(selectedQuote: quote);
  }

  Future<void> loadTripDetails(int id) async {
    state = state.copyWith(
      isLoadingTripDetails: true,
      clearTripDetailsHardError: true,
      clearTripDetailsSoftError: true,
    );
    try {
      final quote = await _repo.getTrip(id);
      state = state.copyWith(
        isLoadingTripDetails: false,
        selectedQuote: quote,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        state = state.copyWith(
          isLoadingTripDetails: false,
          tripDetailsHardError: e.message,
        );
      } else {
        state = state.copyWith(
          isLoadingTripDetails: false,
          tripDetailsSoftError: e.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoadingTripDetails: false,
        tripDetailsSoftError: e.toString(),
      );
    }
  }

  void clearTripDetailsErrors() {
    state = state.copyWith(
      clearTripDetailsHardError: true,
      clearTripDetailsSoftError: true,
    );
  }

  void clearAuthRetry() {
    state = state.copyWith(needsAuthRetry: false);
  }
}

final carBookingProvider =
    NotifierProvider<CarBookingNotifier, CarBookingState>(
  CarBookingNotifier.new,
);
