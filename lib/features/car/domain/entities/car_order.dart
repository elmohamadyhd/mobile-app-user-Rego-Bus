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
    this.canReview = false,
    this.reviewRating,
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
  final bool canReview;
  final int? reviewRating;

  String get orderId => id.toString();

  bool get isConfirmed => statusKind == CarOrderStatusKind.confirmed;

  bool get isPending => statusKind == CarOrderStatusKind.pending;

  CarOrder copyWith({
    int? id,
    String? statusText,
    CarOrderStatusKind? statusKind,
    String? price,
    String? currency,
    bool? rounded,
    String? departureDate,
    String? returnDate,
    CarOrderCoords? from,
    CarOrderCoords? to,
    CarTripQuote? trip,
    String? invoiceUrl,
    String? transactionStatus,
    String? paymentGateway,
    String? paymentInvoiceId,
    bool? canBeCancel,
    String? createdAt,
    bool? canReview,
    int? reviewRating,
  }) {
    return CarOrder(
      id: id ?? this.id,
      statusText: statusText ?? this.statusText,
      statusKind: statusKind ?? this.statusKind,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      rounded: rounded ?? this.rounded,
      departureDate: departureDate ?? this.departureDate,
      returnDate: returnDate ?? this.returnDate,
      from: from ?? this.from,
      to: to ?? this.to,
      trip: trip ?? this.trip,
      invoiceUrl: invoiceUrl ?? this.invoiceUrl,
      transactionStatus: transactionStatus ?? this.transactionStatus,
      paymentGateway: paymentGateway ?? this.paymentGateway,
      paymentInvoiceId: paymentInvoiceId ?? this.paymentInvoiceId,
      canBeCancel: canBeCancel ?? this.canBeCancel,
      createdAt: createdAt ?? this.createdAt,
      canReview: canReview ?? this.canReview,
      reviewRating: reviewRating ?? this.reviewRating,
    );
  }
}
