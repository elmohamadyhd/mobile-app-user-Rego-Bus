import 'package:safaria/features/car/domain/entities/car_order.dart';

/// Whether My Tickets should offer the rate-trip CTA for [order].
bool carOrderCanRate(CarOrder order) =>
    order.statusKind == CarOrderStatusKind.confirmed &&
    order.canReview &&
    order.reviewRating == null;
