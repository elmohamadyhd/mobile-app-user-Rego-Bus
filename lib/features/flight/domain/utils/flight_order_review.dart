import 'package:safaria/features/flight/domain/entities/flight_order.dart';
import 'package:safaria/features/flight/domain/utils/flight_order_status.dart';

/// Whether My Tickets should offer the rate-trip CTA for [order].
bool flightOrderCanRate(FlightOrder order) =>
    isFlightOrderPaid(order) &&
    order.canReview &&
    order.reviewRating == null;
