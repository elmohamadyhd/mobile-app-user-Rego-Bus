import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/core/network/dio_client.dart';
import 'package:safaria/features/car/data/car_api.dart';
import 'package:safaria/features/car/data/car_dto_mapper.dart';
import 'package:safaria/features/car/data/car_repository_impl.dart';
import 'package:safaria/features/car/domain/entities/car_create_order_request.dart';
import 'package:safaria/features/car/domain/entities/car_order.dart';
import 'package:safaria/features/car/domain/entities/car_search_params.dart';
import 'package:safaria/features/car/domain/entities/car_trip_quote.dart';
import 'package:safaria/features/car/domain/repositories/car_repository.dart';

final carApiProvider =
    Provider<CarApi>((ref) => CarApi(ref.watch(dioProvider)));

final carRepositoryProvider = Provider<CarRepository>(
  (ref) => CarRepositoryImpl(ref.watch(carApiProvider)),
);

enum CarBookingStatus {
  idle,
  creatingOrder,
  awaitingPayment,
  verifyingPayment,
  paymentPending,
  confirmed,
  error,
}

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
    this.status = CarBookingStatus.idle,
    this.order,
    this.bookingError,
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
  final CarBookingStatus status;
  final CarOrder? order;
  final String? bookingError;

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
    CarBookingStatus? status,
    CarOrder? order,
    String? bookingError,
    bool clearQuotesError = false,
    bool clearSelectedQuote = false,
    bool clearTripDetailsHardError = false,
    bool clearTripDetailsSoftError = false,
    bool clearOrder = false,
    bool clearBookingError = false,
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
      status: status ?? this.status,
      order: clearOrder ? null : (order ?? this.order),
      bookingError:
          clearBookingError ? null : (bookingError ?? this.bookingError),
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
      clearOrder: true,
      status: CarBookingStatus.idle,
      clearBookingError: true,
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

  bool _orderReusable(
    CarOrder order,
    CarTripQuote quote,
    CarSearchParams params,
  ) {
    if ((order.invoiceUrl ?? '').isEmpty) return false;
    if (order.statusKind != CarOrderStatusKind.pending) return false;
    final tripId = order.trip?.id;
    if (tripId != null && tripId != quote.id) return false;
    if (order.rounded != params.rounded) return false;

    final req = CarDtoMapper.createRequestFromSelection(
      quote: quote,
      params: params,
    );
    final depLat = double.tryParse(req.departureLatitude) ?? 0;
    final depLng = double.tryParse(req.departureLongitude) ?? 0;
    final destLat = double.tryParse(req.destinationLatitude) ?? 0;
    final destLng = double.tryParse(req.destinationLongitude) ?? 0;
    const eps = 0.0001;
    if ((order.from.latitude - depLat).abs() > eps) return false;
    if ((order.from.longitude - depLng).abs() > eps) return false;
    if ((order.to.latitude - destLat).abs() > eps) return false;
    if ((order.to.longitude - destLng).abs() > eps) return false;
    return true;
  }

  /// Creates a private order (or resumes a held pending one) and moves to
  /// [CarBookingStatus.awaitingPayment] when an invoice URL is available.
  Future<void> createOrder() async {
    final quote = state.selectedQuote;
    final params = state.searchParams;
    if (quote == null || params == null) {
      state = state.copyWith(
        status: CarBookingStatus.error,
        bookingError: 'No trip selected',
      );
      return;
    }

    final held = state.order;
    if (held != null && _orderReusable(held, quote, params)) {
      state = state.copyWith(
        status: CarBookingStatus.awaitingPayment,
        clearBookingError: true,
      );
      return;
    }

    state = state.copyWith(
      status: CarBookingStatus.creatingOrder,
      clearBookingError: true,
    );
    try {
      final request = CarDtoMapper.createRequestFromSelection(
        quote: quote,
        params: params,
      );
      final order = await _repo.createOrder(request);
      final invoice = order.invoiceUrl ?? '';
      state = state.copyWith(
        order: order,
        status: invoice.isNotEmpty
            ? CarBookingStatus.awaitingPayment
            : order.isConfirmed
                ? CarBookingStatus.confirmed
                : CarBookingStatus.paymentPending,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        status: CarBookingStatus.error,
        bookingError: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: CarBookingStatus.error,
        bookingError: e.toString(),
      );
    }
  }

  Future<void> verifyPayment() async {
    final order = state.order;
    if (order == null || order.id == 0) {
      state = state.copyWith(status: CarBookingStatus.paymentPending);
      return;
    }

    state = state.copyWith(status: CarBookingStatus.verifyingPayment);
    try {
      final fresh = await _repo.getOrder(order.id);
      state = state.copyWith(
        order: fresh,
        status: fresh.isConfirmed
            ? CarBookingStatus.confirmed
            : CarBookingStatus.paymentPending,
        clearBookingError: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: CarBookingStatus.paymentPending,
        bookingError: e.toString(),
      );
    }
  }

  /// Loads an existing order into booking state (tickets → voucher / pay).
  void hydrateOrder(CarOrder order) {
    state = state.copyWith(
      order: order,
      selectedQuote: order.trip ?? state.selectedQuote,
      status: order.isConfirmed
          ? CarBookingStatus.confirmed
          : order.isPending
              ? CarBookingStatus.awaitingPayment
              : CarBookingStatus.idle,
      clearBookingError: true,
    );
  }

  /// Ensures a checkout URL exists for [order], calling pay when needed.
  Future<CarOrder?> ensureCheckoutUrl(CarOrder order) async {
    if ((order.invoiceUrl ?? '').isNotEmpty) return order;
    final trip = order.trip;
    if (trip == null) return order;
    try {
      final params = state.searchParams;
      final request = params != null
          ? CarDtoMapper.createRequestFromSelection(
              quote: trip,
              params: params,
            )
          : CarCreateOrderRequest(
              tripId: trip.id,
              rounded: order.rounded,
              departureLatitude: order.from.latitude.toString(),
              departureLongitude: order.from.longitude.toString(),
              departureDate: order.departureDate ?? '',
              destinationLatitude: order.to.latitude.toString(),
              destinationLongitude: order.to.longitude.toString(),
              destinationDate: order.returnDate ?? order.departureDate ?? '',
            );
      final paid = await _repo.payOrder(orderId: order.id, request: request);
      state = state.copyWith(order: paid);
      return paid;
    } catch (_) {
      return order;
    }
  }

  void reset() => state = const CarBookingState();
}

final carBookingProvider =
    NotifierProvider<CarBookingNotifier, CarBookingState>(
  CarBookingNotifier.new,
);
