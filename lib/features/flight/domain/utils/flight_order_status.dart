import 'package:safaria/features/flight/domain/entities/flight_order.dart';

/// Status values the backend is known to use for a completed payment.
///
/// This list is provisional — no paid order has been observed yet (open
/// question 1 in the flow spec). Phase 4 Task 9 replaces it with the real
/// set.
const _paidOrderStatuses = {'confirmed', 'ticketed', 'completed', 'paid'};
const _paidPaymentStatuses = {'paid', 'success', 'successful', 'completed'};

/// Whether [order] has actually been paid for.
///
/// Deliberately conservative: anything not positively recognised as paid is
/// treated as unpaid. Showing a paid booking as pending costs a support call;
/// showing an unpaid one as ticketed puts a rider at an airport without a
/// seat.
///
/// The strongest signals come first — a settlement timestamp or a PNR issued
/// by the airline are facts, whereas the status strings are vocabulary that
/// can change.
bool isFlightOrderPaid(FlightOrder order) {
  if (order.paidAt != null) return true;
  if ((order.airlinePnr ?? '').trim().isNotEmpty) return true;
  if ((order.gdsPnr ?? '').trim().isNotEmpty) return true;
  if (_paidPaymentStatuses.contains(
    (order.paymentStatus ?? '').trim().toLowerCase(),
  )) {
    return true;
  }
  return _paidOrderStatuses.contains(order.orderStatus.trim().toLowerCase());
}

bool _looksCancelled(String? value) =>
    (value ?? '').trim().toLowerCase().contains('cancel');

/// Whether [order] was cancelled. Checked before paid/pending for badges.
bool isFlightOrderCancelled(FlightOrder order) =>
    _looksCancelled(order.status) ||
    _looksCancelled(order.orderStatus) ||
    _looksCancelled(order.paymentStatus);
