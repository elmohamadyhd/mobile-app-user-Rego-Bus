import 'package:freezed_annotation/freezed_annotation.dart';

part 'bus_order.freezed.dart';

/// Derived from `status_code` + `is_confirmed` on a bus order (see
/// [BusDtoMapper.orderStatusKind]). Backend vocabulary beyond `pending` is
/// inferred, not documented — unrecognized codes render as [unknown] rather
/// than being guessed into a destructive/positive bucket.
enum BusOrderStatusKind { pending, confirmed, cancelled, unknown }

/// One booked bus trip from `GET /profile/buses/orders` — the "My Tickets"
/// list-item shape. Distinct from [BusTicket] (the post-booking confirmation
/// entity) and `BusOrderStatus` (the payment-verify result).
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
    required List<String> seats,
    required String total,
    required bool canCancel,
    String? gatewayCheckoutUrl,
    String? invoiceUrl,
  }) = _BusOrder;
}
