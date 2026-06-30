// lib/features/booking/presentation/providers/booking_providers.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rego/core/utils/date_formatting.dart';
import 'package:rego/features/booking/data/mock_booking_data.dart';
import 'package:rego/features/booking/domain/entities/booking.dart';
import 'package:rego/features/booking/domain/entities/trip.dart';

part 'booking_providers.freezed.dart';

enum BookingFlowStatus {
  idle,
  loadingTrips,
  loadingDetail,
  confirming,
  confirmed,
  error
}

enum PaymentMethod { wallet, card }

@freezed
abstract class BookingFlowState with _$BookingFlowState {
  const factory BookingFlowState({
    @Default([]) List<TripSummary> trips,
    @Default(BookingFlowStatus.idle) BookingFlowStatus status,
    TripSummary? selectedTrip,
    TripDetail? tripDetail,
    @Default([]) List<String> selectedSeats,
    @Default('Ahmed Hassan') String passengerName,
    @Default('+20 10 1234 5678') String passengerPhone,
    @Default(PaymentMethod.wallet) PaymentMethod paymentMethod,
    ETicket? ticket,
    String? error,
    String? searchFrom,
    String? searchTo,
    DateTime? searchDate,
    @Default(false) bool isRoundTrip,
    DateTime? searchReturnDate,
    String? flightClass,
  }) = _BookingFlowState;
}

class BookingFlowNotifier extends Notifier<BookingFlowState> {
  @override
  BookingFlowState build() => const BookingFlowState();

  Future<void> searchTrips(
    String from,
    String to,
    String date, {
    bool isRoundTrip = false,
    String? returnDate,
    String? flightClass,
  }) async {
    final parsedDate = parseIsoDate(date) ?? dateOnly(DateTime.now());
    final parsedReturn =
        isRoundTrip && returnDate != null ? parseIsoDate(returnDate) : null;
    state = state.copyWith(
      status: BookingFlowStatus.loadingTrips,
      searchFrom: from,
      searchTo: to,
      searchDate: parsedDate,
      isRoundTrip: isRoundTrip,
      searchReturnDate: parsedReturn,
      flightClass: flightClass,
    );
    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      state = state.copyWith(
        status: BookingFlowStatus.idle,
        trips: MockBookingData.trips,
      );
    } catch (e) {
      state = state.copyWith(
        status: BookingFlowStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> selectTrip(TripSummary trip) async {
    state = state.copyWith(
      status: BookingFlowStatus.loadingDetail,
      selectedTrip: trip,
      selectedSeats: [],
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    state = state.copyWith(
      status: BookingFlowStatus.idle,
      tripDetail: MockBookingData.detailFor(trip.id),
    );
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
        status: BookingFlowStatus.error,
        error: 'No trip selected',
      );
      return;
    }
    state = state.copyWith(status: BookingFlowStatus.confirming, error: null);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final ref =
        'RG-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    final ticket = ETicket(
      bookingRef: ref,
      trip: detail,
      seats: List.unmodifiable(state.selectedSeats),
      passengerName: state.passengerName,
      gate: 'A3',
      issuedAt: DateTime.now(),
    );
    state = state.copyWith(
      status: BookingFlowStatus.confirmed,
      ticket: ticket,
    );
  }

  void reset() => state = const BookingFlowState();
}

final bookingFlowProvider =
    NotifierProvider<BookingFlowNotifier, BookingFlowState>(
        BookingFlowNotifier.new);
