import 'package:safaria/features/bus/domain/entities/bus_order.dart';

/// Whether My Tickets should offer the rate-trip CTA for [order].
bool busOrderCanRate(BusOrder order) =>
    order.statusKind == BusOrderStatusKind.confirmed &&
    order.canReview &&
    order.reviewRating == null;
