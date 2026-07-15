import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';

part 'bus_order.freezed.dart';

/// Derived from `status_code` + `is_confirmed` on a bus order (see
/// [BusDtoMapper.orderStatusKind]). Backend vocabulary beyond `pending` is
/// inferred, not documented — unrecognized codes render as [unknown] rather
/// than being guessed into a destructive/positive bucket.
enum BusOrderStatusKind { pending, confirmed, cancelled, unknown }

/// The fare breakdown carried by every bus order (List and Show endpoints
/// return the same fields). All money fields are preformatted strings (e.g.
/// `"EGP 205.00"`), matching every other money field in this codebase — no
/// numeric parsing, no new currency-formatting logic.
@freezed
abstract class BusOrderFare with _$BusOrderFare {
  const factory BusOrderFare({
    required String originalTicketsTotal,
    required String discount,
    required String walletDiscount,
    required String ticketsTotalAfterDiscount,
    required String paymentFees,
    required String total,
    required String currency,
  }) = _BusOrderFare;
}

/// One booked bus trip from `GET /profile/buses/orders` (list) or
/// `GET /profile/buses/orders/:id` (show) — both endpoints return this same
/// shape, mapped by the same `BusDtoMapper.orderFromJson`. Distinct from
/// [BusTicket] (the post-booking confirmation entity) and `BusOrderStatus`
/// (the payment-verify result).
@freezed
abstract class BusOrder with _$BusOrder {
  const factory BusOrder({
    required String orderId,
    required String bookingNumber,
    required String operatorName,
    String? operatorLogoUrl,
    required String category,
    required String statusText,
    required BusOrderStatusKind statusKind,
    required String dateTimeLabel,
    String? pickupStopLabel,
    String? dropoffStopLabel,
    required List<BusTicketLine> ticketLines,
    required String total,
    required bool canCancel,
    String? cancelUrl,
    String? gatewayCheckoutUrl,
    String? invoiceUrl,
    required BusOrderFare fare,
    String? paymentGateway,
    String? paymentStatusText,
    String? paymentInvoiceId,
    String? tripId,
    String? gatewayOrderId,
    String? tripType,
  }) = _BusOrder;
}
