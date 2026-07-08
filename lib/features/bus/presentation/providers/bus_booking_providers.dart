// lib/features/bus/presentation/providers/bus_booking_providers.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rego/core/utils/date_formatting.dart';
import 'package:rego/features/bus/data/bus_repository_impl.dart';
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/domain/repositories/bus_repository.dart';

part 'bus_booking_providers.freezed.dart';

enum BusBookingStatus {
  idle,
  loadingTrips,
  loadingDetail,
  confirming,
  confirmed,
  error,
}

enum PaymentMethod { wallet, card }

final busRepositoryProvider =
    Provider<BusRepository>((ref) => BusRepositoryImpl());

@freezed
abstract class BusBookingState with _$BusBookingState {
  const factory BusBookingState({
    @Default([]) List<BusTripSummary> trips,
    @Default(BusBookingStatus.idle) BusBookingStatus status,
    BusTripSummary? selectedTrip,
    BusTripDetail? tripDetail,
    @Default([]) List<String> selectedSeats,
    @Default('Ahmed Hassan') String passengerName,
    @Default('+20 10 1234 5678') String passengerPhone,
    @Default(PaymentMethod.wallet) PaymentMethod paymentMethod,
    BusTicket? ticket,
    String? error,
    String? searchFrom,
    String? searchTo,
    DateTime? searchDate,
  }) = _BusBookingState;
}

class BusBookingNotifier extends Notifier<BusBookingState> {
  BusRepository get _repo => ref.read(busRepositoryProvider);

  @override
  BusBookingState build() => const BusBookingState();

  Future<void> searchTrips(String from, String to, String date) async {
    final parsedDate = parseIsoDate(date) ?? dateOnly(DateTime.now());
    state = state.copyWith(
      status: BusBookingStatus.loadingTrips,
      searchFrom: from,
      searchTo: to,
      searchDate: parsedDate,
    );
    try {
      final trips = await _repo.searchTrips(from, to, date);
      state = state.copyWith(status: BusBookingStatus.idle, trips: trips);
    } catch (e) {
      state = state.copyWith(
        status: BusBookingStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> selectTrip(BusTripSummary trip) async {
    state = state.copyWith(
      status: BusBookingStatus.loadingDetail,
      selectedTrip: trip,
      selectedSeats: [],
    );
    final detail = await _repo.tripDetail(trip.id);
    state = state.copyWith(status: BusBookingStatus.idle, tripDetail: detail);
  }

  void toggleSeat(String id) {
    final seats = List<String>.from(state.selectedSeats);
    if (seats.contains(id)) {
      seats.remove(id);
    } else {
      seats.add(id);
    }
    state = state.copyWith(selectedSeats: seats);
  }

  void setPaymentMethod(PaymentMethod method) {
    state = state.copyWith(paymentMethod: method);
  }

  Future<void> confirmBooking() async {
    final detail = state.tripDetail;
    if (detail == null) {
      state = state.copyWith(
        status: BusBookingStatus.error,
        error: 'No trip selected',
      );
      return;
    }
    state = state.copyWith(status: BusBookingStatus.confirming, error: null);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final bookingRef =
        'RG-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    final ticket = BusTicket(
      bookingRef: bookingRef,
      trip: detail,
      seats: List.unmodifiable(state.selectedSeats),
      passengerName: state.passengerName,
      gate: 'A3',
      issuedAt: DateTime.now(),
    );
    state = state.copyWith(
      status: BusBookingStatus.confirmed,
      ticket: ticket,
    );
  }

  void reset() => state = const BusBookingState();
}

final busBookingProvider =
    NotifierProvider<BusBookingNotifier, BusBookingState>(
        BusBookingNotifier.new);
