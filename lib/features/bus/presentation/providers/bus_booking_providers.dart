import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safaria/core/network/dio_client.dart';
import 'package:safaria/core/utils/date_formatting.dart';
import 'package:safaria/features/bus/data/bus_api.dart';
import 'package:safaria/features/bus/data/bus_dto_mapper.dart';
import 'package:safaria/features/bus/data/bus_repository_impl.dart';
import 'package:safaria/features/bus/domain/entities/bus_search_params.dart';
import 'package:safaria/features/bus/domain/entities/bus_stop.dart';
import 'package:safaria/features/bus/domain/entities/bus_ticket.dart';
import 'package:safaria/features/bus/domain/entities/bus_trip.dart';
import 'package:safaria/features/bus/domain/entities/seat_map.dart';
import 'package:safaria/features/bus/domain/repositories/bus_repository.dart';
import 'package:safaria/features/bus/domain/utils/merge_bus_trips.dart';

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

/// Lifecycle of the progressive search window, kept separate from
/// [BusBookingStatus] so the existing error view, skeleton, and filter code
/// keep reading exactly the field they read today.
enum BusSearchPhase { idle, polling, complete, exhausted }

/// Schedule for the follow-up search rounds.
///
/// The aggregating backend answers with whatever operator inventory has landed
/// so far, and was observed to have more roughly 5 seconds later. These numbers
/// are a starting point to re-tune from measurement, not a result — which is
/// also why they are injected rather than hardcoded: tests override the gap to
/// zero instead of pulling in a fake clock.
class BusSearchSchedule {
  const BusSearchSchedule({
    this.gap = const Duration(seconds: 5),
    this.rounds = 3,
  });

  final Duration gap;
  final int rounds;
}

final busSearchScheduleProvider =
    Provider<BusSearchSchedule>((ref) => const BusSearchSchedule());

final busApiProvider =
    Provider<BusApi>((ref) => BusApi(ref.watch(dioProvider)));

final busRepositoryProvider = Provider<BusRepository>(
  (ref) => BusRepositoryImpl(ref.watch(busApiProvider)),
);

@freezed
abstract class BusBookingState with _$BusBookingState {
  const factory BusBookingState({
    BusSearchParams? searchParams,
    @Default([]) List<BusTripSummary> trips,
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
    @Default(BusSearchPhase.idle) BusSearchPhase searchPhase,
    @Default([]) List<BusTripSummary> stagedTrips,
    @Default(0) int searchGeneration,
  }) = _BusBookingState;
}

class BusBookingNotifier extends Notifier<BusBookingState> {
  BusRepository get _repo => ref.read(busRepositoryProvider);
  BusSearchSchedule get _schedule => ref.read(busSearchScheduleProvider);

  /// Rounds finding nothing new before the search is called settled.
  static const _quietRoundsToComplete = 2;

  /// Consecutive round failures before the window gives up.
  static const _maxConsecutiveFailures = 3;

  /// Ceiling on how many pages a single round will pull. `/buses/trips` pages
  /// at 15, so a real search is one or two pages; the cap exists only so a bad
  /// `lastPage` cannot fan out into dozens of parallel requests.
  static const _maxPagesPerRound = 5;

  Timer? _pollTimer;

  @override
  BusBookingState build() {
    ref.onDispose(_cancelPolling);
    return const BusBookingState();
  }

  Future<void> searchTrips(BusSearchParams params) async {
    _cancelPolling();
    final generation = state.searchGeneration + 1;
    state = state.copyWith(
      status: BusBookingStatus.loadingTrips,
      searchParams: params,
      error: null,
      trips: [],
      stagedTrips: [],
      searchPhase: BusSearchPhase.polling,
      searchGeneration: generation,
    );
    try {
      final page = await _repo.searchTrips(params);
      if (generation != state.searchGeneration) return;
      // Paint page 1 before pulling the rest: the first screenful is what the
      // rider is waiting on, and the later pages are usually a second or two
      // behind it.
      state = state.copyWith(
        status: BusBookingStatus.idle,
        trips: page.trips,
      );
      if (page.lastPage > 1) {
        // Do not hold the first paint (or the home-screen await) on extra
        // pages — `/buses/trips` is already a slow aggregator, and page 2
        // is another full round-trip. Merge them in the background.
        unawaited(
          _completeFirstRound(
            generation: generation,
            params: params,
            lastPage: page.lastPage,
          ),
        );
      } else {
        _scheduleRound(
          generation: generation,
          round: 1,
          quiet: 0,
          failures: 0,
        );
      }
    } catch (e) {
      if (generation != state.searchGeneration) return;
      state = state.copyWith(
        status: BusBookingStatus.error,
        error: e.toString(),
        searchPhase: BusSearchPhase.idle,
      );
    }
  }

  void _scheduleRound({
    required int generation,
    required int round,
    required int quiet,
    required int failures,
  }) {
    _pollTimer?.cancel();
    if (round > _schedule.rounds) {
      _finishPolling(generation, BusSearchPhase.exhausted);
      return;
    }
    _pollTimer = Timer(_schedule.gap, () {
      unawaited(
        _runRound(
          generation: generation,
          round: round,
          quiet: quiet,
          failures: failures,
        ),
      );
    });
  }

  Future<void> _runRound({
    required int generation,
    required int round,
    required int quiet,
    required int failures,
  }) async {
    if (generation != state.searchGeneration) return;
    final params = state.searchParams;
    if (params == null) return;

    final List<BusTripSummary> incoming;
    try {
      incoming = await _fetchAllPages(params);
    } catch (_) {
      // A failed round is not evidence the aggregation finished, so it never
      // counts toward the quiet rule — and it never surfaces a message to a
      // rider who already has results on screen.
      if (generation != state.searchGeneration) return;
      if (state.searchPhase != BusSearchPhase.polling) return;
      final nextFailures = failures + 1;
      _logRound(
        round,
        'failed failures=$nextFailures',
      );
      if (nextFailures >= _maxConsecutiveFailures) {
        _finishPolling(generation, BusSearchPhase.exhausted);
        return;
      }
      _scheduleRound(
        generation: generation,
        round: round + 1,
        quiet: quiet,
        failures: nextFailures,
      );
      return;
    }

    if (generation != state.searchGeneration) return;
    if (state.searchPhase != BusSearchPhase.polling) return;

    final visibleIds = {for (final trip in state.trips) trip.id};
    final updates = incoming.where((t) => visibleIds.contains(t.id));
    final arrivals = incoming.where((t) => !visibleIds.contains(t.id));

    // With nothing on screen there is no reading position to protect, so
    // arrivals skip the staging list entirely.
    final stageArrivals = state.trips.isNotEmpty;

    final visible = mergeBusTrips(
      state.trips,
      [...updates, if (!stageArrivals) ...arrivals],
    );
    final staged = mergeBusTrips(
      state.stagedTrips,
      [if (stageArrivals) ...arrivals],
    );

    state = state.copyWith(trips: visible.trips, stagedTrips: staged.trips);

    final nextQuiet = (visible.changed || staged.changed) ? 0 : quiet + 1;
    _logRound(
      round,
      'new=${arrivals.length} '
      'changed=${visible.changed || staged.changed} quiet=$nextQuiet',
    );
    if (nextQuiet >= _quietRoundsToComplete) {
      _finishPolling(generation, BusSearchPhase.complete);
      return;
    }
    _scheduleRound(
      generation: generation,
      round: round + 1,
      quiet: nextQuiet,
      failures: 0,
    );
  }

  /// Page 2+ of the first answer, merged into the visible list once they
  /// land. Kept off the `searchTrips` future so the home screen can navigate
  /// as soon as page 1 is in hand. Follow-up rounds still wait until these
  /// pages finish, so a `page: 1` of round 1 cannot race a lingering page 2.
  Future<void> _completeFirstRound({
    required int generation,
    required BusSearchParams params,
    required int lastPage,
  }) async {
    final rest = await _fetchRemainingPages(params, lastPage: lastPage);
    if (generation != state.searchGeneration) return;
    // These pages belong to the same first answer, so they go into the
    // visible list rather than behind the pill.
    state = state.copyWith(trips: mergeBusTrips(state.trips, rest).trips);
    _scheduleRound(
      generation: generation,
      round: 1,
      quiet: 0,
      failures: 0,
    );
  }

  /// One round's worth of results: page 1 plus every further page it says
  /// exists.
  Future<List<BusTripSummary>> _fetchAllPages(BusSearchParams params) async {
    final first = await _repo.searchTrips(params);
    final rest = await _fetchRemainingPages(params, lastPage: first.lastPage);
    return [...first.trips, ...rest];
  }

  /// Pages 2..lastPage, fetched together.
  ///
  /// Page numbers are not a stable coordinate while the aggregator is still
  /// filling in — a trip on page 2 now may be on page 1 a moment later, so the
  /// same trip can arrive twice or slip through a boundary. That is safe here
  /// only because every page is folded through [mergeBusTrips], which collapses
  /// anything seen twice and never drops what it already holds.
  Future<List<BusTripSummary>> _fetchRemainingPages(
    BusSearchParams params, {
    required int lastPage,
  }) async {
    final target = lastPage < _maxPagesPerRound ? lastPage : _maxPagesPerRound;
    if (target < 2) return const [];
    final pages = await Future.wait([
      for (var page = 2; page <= target; page++)
        _fetchPageOrEmpty(params, page),
    ]);
    return [for (final trips in pages) ...trips];
  }

  /// A single page that contributes nothing rather than sinking the round.
  /// Losing five trips beats losing the fifteen already in hand.
  Future<List<BusTripSummary>> _fetchPageOrEmpty(
    BusSearchParams params,
    int page,
  ) async {
    try {
      final result = await _repo.searchTrips(params, page: page);
      return result.trips;
    } catch (_) {
      _logRound(page, 'page $page failed');
      return const [];
    }
  }

  void _finishPolling(int generation, BusSearchPhase phase) {
    _cancelPolling();
    if (generation != state.searchGeneration) return;
    state = state.copyWith(searchPhase: phase);
  }

  void _cancelPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _logRound(int round, String details) {
    if (!kDebugMode) return;
    developer.log(
      'round $round: $details',
      name: 'bus.progressiveSearch',
    );
  }

  /// Promotes trips found after the first round into the visible list. Called
  /// by the results screen when the rider is at the top, or taps the pill.
  void revealStagedTrips() {
    if (state.stagedTrips.isEmpty) return;
    state = state.copyWith(
      trips: [...state.trips, ...state.stagedTrips],
      stagedTrips: const [],
    );
  }

  /// Ends the window early without discarding anything already found.
  ///
  /// Used when the rider leaves the results list or the app goes to the
  /// background: a progress bar that no timer will ever advance is worse than
  /// a refresh button.
  void stopProgressiveSearch() {
    _cancelPolling();
    if (state.searchPhase == BusSearchPhase.polling) {
      state = state.copyWith(searchPhase: BusSearchPhase.exhausted);
    }
  }

  /// Manual re-entry after the automatic window closed. Runs a round straight
  /// away — a tap deserves an immediate answer, not a 5-second wait — and
  /// merges rather than resetting, so the list on screen never blinks.
  void checkForMoreTrips() {
    if (state.searchPhase == BusSearchPhase.polling) return;
    if (state.searchParams == null) return;
    state = state.copyWith(searchPhase: BusSearchPhase.polling);
    unawaited(
      _runRound(
        generation: state.searchGeneration,
        round: 1,
        quiet: 0,
        failures: 0,
      ),
    );
  }

  void setSearchLabels({String? from, String? to}) {
    state = state.copyWith(
      searchFromLabel: from,
      searchToLabel: to,
    );
  }

  Future<void> selectTrip(
    BusTripSummary trip, {
    BusStop? from,
    BusStop? to,
  }) async {
    stopProgressiveSearch();
    // Seed the pair synchronously so the detail screen can open immediately,
    // then enrich in the background behind a loading state.
    final seedFrom = from ?? trip.defaultBoardingStop;
    final seedTo = to ?? trip.terminalDropoffStop;
    state = state.copyWith(
      status: BusBookingStatus.loadingDetail,
      selectedTrip: trip,
      fromStop: seedFrom,
      toStop: seedTo,
      segmentFare: seedTo.finalPrice,
      selectedSeats: [],
      seatMap: null,
      error: null,
    );

    try {
      final currency = state.searchParams?.currency ?? BusCurrency.defaultCode;
      final detail = await _repo.tripById(trip.id, currency: currency);
      if (detail.id.isNotEmpty) {
        final merged = trip.mergeEnrichment(detail);
        final keptFrom = _keepStopIfPresent(
          state.fromStop,
          merged.boardingStops,
          fallback: merged.defaultBoardingStop,
        );
        final keptTo = _keepStopIfPresent(
          state.toStop,
          merged.dropoffStops,
          fallback: merged.terminalDropoffStop,
        );
        state = state.copyWith(
          selectedTrip: merged,
          fromStop: keptFrom,
          toStop: keptTo,
          segmentFare: keptTo.finalPrice,
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

  /// Keep a user-seeded stop when enrichment still lists the same id.
  BusStop _keepStopIfPresent(
    BusStop? seeded,
    List<BusStop> candidates, {
    required BusStop fallback,
  }) {
    if (seeded == null || seeded.locationId.isEmpty) return fallback;
    for (final stop in candidates) {
      if (stop.locationId == seeded.locationId) return stop;
    }
    return fallback;
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
    if (method == state.paymentMethod) return;
    final resetStatus = state.status == BusBookingStatus.awaitingPayment
        ? BusBookingStatus.idle
        : state.status;
    state = state.copyWith(
      paymentMethod: method,
      ticket: null,
      status: resetStatus,
    );
  }

  String _apiPaymentMethod(PaymentMethod method) => switch (method) {
        PaymentMethod.visa => 'credit',
        PaymentMethod.wallet => 'wallet',
      };

  /// Whether [ticket] already represents a gateway order held for exactly
  /// this trip/stop-pair/seat selection. If so, `confirmBooking` reuses its
  /// `payment_url` instead of creating a duplicate temporary booking.
  bool _ticketReusable(
    BusTicket ticket,
    BusTripSummary trip,
    BusStop from,
    BusStop to,
    List<String> seats,
  ) {
    if ((ticket.paymentUrl ?? '').isEmpty) return false;
    if (ticket.trip.id != trip.id) return false;
    if (ticket.fromStop.locationId != from.locationId) return false;
    if (ticket.toStop.locationId != to.locationId) return false;
    return ticket.seats.length == seats.length &&
        ticket.seats.toSet().containsAll(seats);
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

    final heldTicket = state.ticket;
    if (heldTicket != null &&
        _ticketReusable(heldTicket, trip, from, to, state.selectedSeats)) {
      state = state.copyWith(status: BusBookingStatus.awaitingPayment);
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
          paymentMethod: _apiPaymentMethod(state.paymentMethod),
          seats: state.selectedSeats
              .map((id) => BusSeatSelection(seatId: id, seatTypeId: id))
              .toList(),
        ),
        trip: trip,
        fromStop: from,
        toStop: to,
      );
      state = state.copyWith(
        status: _statusAfterCreateTicket(ticket, state.paymentMethod),
        ticket: ticket,
      );
    } catch (e) {
      state = state.copyWith(
        status: BusBookingStatus.error,
        error: e.toString(),
      );
    }
  }

  BusBookingStatus _statusAfterCreateTicket(
    BusTicket ticket,
    PaymentMethod paymentMethod,
  ) {
    if (BusDtoMapper.isPaidStatus(ticket.statusCode ?? '', 0)) {
      return BusBookingStatus.confirmed;
    }
    if ((ticket.paymentUrl ?? '').isNotEmpty) {
      return BusBookingStatus.awaitingPayment;
    }
    // Unexpected for the card path — don't strand the rider without a checkout URL.
    if (paymentMethod == PaymentMethod.visa) {
      return BusBookingStatus.confirmed;
    }
    return BusBookingStatus.paymentPending;
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
      final order = await _repo.orderStatus(ticket.orderId);
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

  void reset() {
    _cancelPolling();
    // Bump so an in-flight round born under the previous generation cannot
    // match a later search that would otherwise restart at 0 → 1.
    state = BusBookingState(searchGeneration: state.searchGeneration + 1);
  }
}

final busBookingProvider =
    NotifierProvider<BusBookingNotifier, BusBookingState>(
  BusBookingNotifier.new,
);
