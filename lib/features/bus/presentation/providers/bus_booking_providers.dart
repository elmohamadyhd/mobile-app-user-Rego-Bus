import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rego/core/network/dio_client.dart';
import 'package:rego/core/utils/date_formatting.dart';
import 'package:rego/features/bus/data/bus_api.dart';
import 'package:rego/features/bus/data/bus_repository_impl.dart';
import 'package:rego/features/bus/domain/entities/bus_search_params.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/domain/entities/seat_map.dart';
import 'package:rego/features/bus/domain/repositories/bus_repository.dart';

part 'bus_booking_providers.freezed.dart';

enum BusBookingStatus {
  idle,
  loadingTrips,
  loadingDetail,
  loadingSeats,
  confirming,
  awaitingPayment,
  verifyingPayment,
  paymentPending,
  confirmed,
  error,
}

enum PaymentMethod { visa, wallet }

final busApiProvider = Provider<BusApi>((ref) => BusApi(ref.watch(dioProvider)));

final busRepositoryProvider = Provider<BusRepository>(
  (ref) => BusRepositoryImpl(ref.watch(busApiProvider)),
);

@freezed
abstract class BusBookingState with _$BusBookingState {
  const factory BusBookingState({
    BusSearchParams? searchParams,
    @Default([]) List<BusTripSummary> trips,
    @Default(1) int tripsPage,
    @Default(false) bool tripsHasMore,
    @Default(BusBookingStatus.idle) BusBookingStatus status,
    BusTripSummary? selectedTrip,
    BusStop? fromStop,
    BusStop? toStop,
    @Default(0) double segmentFare,
    SeatMap? seatMap,
    @Default([]) List<String> selectedSeats,
    @Default(PaymentMethod.visa) PaymentMethod paymentMethod,
    BusTicket? ticket,
    String? error,
    String? searchFromLabel,
    String? searchToLabel,
  }) = _BusBookingState;
}

class BusBookingNotifier extends Notifier<BusBookingState> {
  BusRepository get _repo => ref.read(busRepositoryProvider);

  @override
  BusBookingState build() => const BusBookingState();

  Future<void> searchTrips(BusSearchParams params) async {
    state = state.copyWith(
      status: BusBookingStatus.loadingTrips,
      searchParams: params,
      error: null,
      trips: [],
      tripsPage: 1,
      tripsHasMore: false,
    );
    try {
      final page = await _repo.searchTrips(params);
      state = state.copyWith(
        status: BusBookingStatus.idle,
        trips: page.trips,
        tripsPage: page.currentPage,
        tripsHasMore: page.hasMore,
      );
    } catch (e) {
      state = state.copyWith(
        status: BusBookingStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMoreTrips() async {
    final params = state.searchParams;
    if (params == null || !state.tripsHasMore) return;
    if (state.status == BusBookingStatus.loadingTrips) return;

    final nextPage = state.tripsPage + 1;
    try {
      final page = await _repo.searchTrips(params, page: nextPage);
      state = state.copyWith(
        trips: [...state.trips, ...page.trips],
        tripsPage: page.currentPage,
        tripsHasMore: page.hasMore,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void setSearchLabels({String? from, String? to}) {
    state = state.copyWith(
      searchFromLabel: from,
      searchToLabel: to,
    );
  }

  Future<void> selectTrip(BusTripSummary trip) async {
    // Seed the default pair synchronously so the detail screen can open
    // immediately, then enrich in the background behind a loading state.
    state = state.copyWith(
      status: BusBookingStatus.loadingDetail,
      selectedTrip: trip,
      fromStop: trip.defaultBoardingStop,
      toStop: trip.defaultDropoffStop,
      segmentFare: trip.defaultDropoffStop.finalPrice,
      selectedSeats: [],
      seatMap: null,
      error: null,
    );

    try {
      final currency =
          state.searchParams?.currency ?? BusCurrency.defaultCode;
      final detail = await _repo.tripById(trip.id, currency: currency);
      if (detail.id.isNotEmpty) {
        final merged = trip.mergeEnrichment(detail);
        state = state.copyWith(
          selectedTrip: merged,
          fromStop: state.fromStop ?? merged.defaultBoardingStop,
          toStop: state.toStop ?? merged.defaultDropoffStop,
          segmentFare: (state.toStop ?? merged.defaultDropoffStop).finalPrice,
        );
      }
    } catch (_) {
      // Background enrichment is best-effort.
    } finally {
      if (state.status == BusBookingStatus.loadingDetail) {
        state = state.copyWith(status: BusBookingStatus.idle);
      }
    }
  }

  void setStops({required BusStop from, required BusStop to}) {
    state = state.copyWith(
      fromStop: from,
      toStop: to,
      segmentFare: to.finalPrice,
      selectedSeats: [],
      seatMap: null,
    );
  }

  Future<void> loadSeats() async {
    final trip = state.selectedTrip;
    final params = state.searchParams;
    final from = state.fromStop;
    final to = state.toStop;
    if (trip == null || params == null || from == null || to == null) return;

    state = state.copyWith(status: BusBookingStatus.loadingSeats, error: null);
    try {
      final map = await _repo.seatMap(
        tripId: trip.id,
        fromCityId: params.cityFromId,
        toCityId: params.cityToId,
        fromLocationId: from.locationId,
        toLocationId: to.locationId,
        date: toIsoDate(params.date),
      );
      state = state.copyWith(status: BusBookingStatus.idle, seatMap: map);
    } catch (e) {
      state = state.copyWith(
        status: BusBookingStatus.error,
        error: e.toString(),
      );
    }
  }

  void toggleSeat(String seatId) {
    final seats = List<String>.from(state.selectedSeats);
    if (seats.contains(seatId)) {
      seats.remove(seatId);
    } else {
      seats.add(seatId);
    }
    state = state.copyWith(selectedSeats: seats);
  }

  void setPaymentMethod(PaymentMethod method) {
    if (method == PaymentMethod.wallet) return;
    state = state.copyWith(paymentMethod: method);
  }

  Future<void> confirmBooking() async {
    final trip = state.selectedTrip;
    final params = state.searchParams;
    final from = state.fromStop;
    final to = state.toStop;
    if (trip == null || params == null || from == null || to == null) {
      state = state.copyWith(
        status: BusBookingStatus.error,
        error: 'No trip selected',
      );
      return;
    }
    if (state.selectedSeats.isEmpty) {
      state = state.copyWith(
        status: BusBookingStatus.error,
        error: 'No seats selected',
      );
      return;
    }

    state = state.copyWith(status: BusBookingStatus.confirming, error: null);
    try {
      final ticket = await _repo.createTicket(
        BusCreateTicketRequest(
          tripId: trip.id,
          fromCityId: params.cityFromId,
          toCityId: params.cityToId,
          fromLocationId: from.locationId,
          toLocationId: to.locationId,
          date: toIsoDate(params.date),
          currency: params.currency,
          seats: state.selectedSeats
              .map((id) => BusSeatSelection(seatId: id, seatTypeId: id))
              .toList(),
        ),
        trip: trip,
        fromStop: from,
        toStop: to,
      );
      // The order is created in a `pending` state with a gateway payment_url.
      // Hand off to the payment WebView; the booking is only `confirmed` once
      // `verifyPayment` reads back a paid status. If no payment_url came back
      // (unexpected for the card path), fall through to confirmed so the rider
      // isn't stranded.
      final hasPaymentUrl = (ticket.paymentUrl ?? '').isNotEmpty;
      state = state.copyWith(
        status: hasPaymentUrl
            ? BusBookingStatus.awaitingPayment
            : BusBookingStatus.confirmed,
        ticket: ticket,
      );
    } catch (e) {
      state = state.copyWith(
        status: BusBookingStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Reads the order's authoritative status after the payment gateway returns.
  /// Paid → `confirmed` (show the e-ticket). Anything else, including a lookup
  /// error, → `paymentPending`: the seat is held and the backend auto-cancels
  /// the order in ~15 minutes if it stays unpaid, so pending is the safe
  /// resting state rather than a hard error.
  Future<void> verifyPayment() async {
    final ticket = state.ticket;
    if (ticket == null || ticket.orderId.isEmpty) {
      state = state.copyWith(status: BusBookingStatus.paymentPending);
      return;
    }

    state = state.copyWith(status: BusBookingStatus.verifyingPayment);
    try {
      final currency =
          state.searchParams?.currency ?? BusCurrency.defaultCode;
      final order = await _repo.orderStatus(ticket.orderId, currency: currency);
      state = state.copyWith(
        status: order.isConfirmed
            ? BusBookingStatus.confirmed
            : BusBookingStatus.paymentPending,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: BusBookingStatus.paymentPending,
        error: e.toString(),
      );
    }
  }

  void reset() => state = const BusBookingState();
}

final busBookingProvider =
    NotifierProvider<BusBookingNotifier, BusBookingState>(
  BusBookingNotifier.new,
);
