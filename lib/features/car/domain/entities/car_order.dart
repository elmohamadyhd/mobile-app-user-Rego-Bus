import 'package:safaria/features/car/domain/entities/car_trip_quote.dart';

enum CarOrderStatusKind { pending, confirmed, cancelled, unknown }

final class CarOrderCoords {
  const CarOrderCoords({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

/// One private-transfer order from create / list / show / pay / cancel.
final class CarOrder {
  const CarOrder({
    required this.id,
    required this.statusText,
    required this.statusKind,
    required this.price,
    required this.currency,
    required this.rounded,
    this.departureDate,
    this.returnDate,
    required this.from,
    required this.to,
    this.trip,
    this.invoiceUrl,
    this.transactionStatus,
    this.paymentGateway,
    this.paymentInvoiceId,
    required this.canBeCancel,
    this.createdAt,
  });

  final int id;
  final String statusText;
  final CarOrderStatusKind statusKind;
  final String price;
  final String currency;
  final bool rounded;
  final String? departureDate;
  final String? returnDate;
  final CarOrderCoords from;
  final CarOrderCoords to;
  final CarTripQuote? trip;
  final String? invoiceUrl;
  final String? transactionStatus;
  final String? paymentGateway;
  final String? paymentInvoiceId;
  final bool canBeCancel;
  final String? createdAt;

  String get orderId => id.toString();

  bool get isConfirmed => statusKind == CarOrderStatusKind.confirmed;

  bool get isPending => statusKind == CarOrderStatusKind.pending;
}
