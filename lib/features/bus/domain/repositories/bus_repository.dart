import 'package:rego/features/bus/domain/entities/bus_location.dart';
import 'package:rego/features/bus/domain/entities/bus_search_params.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/domain/entities/seat_map.dart';

final class BusTripsPage {
  const BusTripsPage({
    required this.trips,
    required this.currentPage,
    required this.lastPage,
  });

  final List<BusTripSummary> trips;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;
}

final class BusSeatSelection {
  const BusSeatSelection({required this.seatId, required this.seatTypeId});

  final String seatId;
  final String seatTypeId;
}

/// Authoritative payment/booking status for an order, read back from the
/// backend after the rider goes through the payment gateway. The order is
/// created in a `pending` state by `create-ticket`; this reflects whether it
/// has since moved to a paid/confirmed state.
final class BusOrderStatus {
  const BusOrderStatus({
    required this.orderId,
    required this.statusCode,
    required this.isConfirmed,
    this.total,
    this.paymentUrl,
  });

  final String orderId;
  final String statusCode;
  final bool isConfirmed;
  final String? total;
  final String? paymentUrl;
}

final class BusCreateTicketRequest {
  const BusCreateTicketRequest({
    required this.tripId,
    required this.fromCityId,
    required this.toCityId,
    required this.fromLocationId,
    required this.toLocationId,
    required this.date,
    required this.seats,
    required this.currency,
    this.paymentMethod = 'myfatoorah',
  });

  final String tripId;
  final int fromCityId;
  final int toCityId;
  final String fromLocationId;
  final String toLocationId;
  final String date;
  final List<BusSeatSelection> seats;
  final String currency;
  final String paymentMethod;
}

abstract interface class BusRepository {
  Future<List<BusLocation>> listLocations();

  Future<BusTripsPage> searchTrips(BusSearchParams params, {int page = 1});

  Future<BusTripSummary> tripById(String tripId, {required String currency});

  Future<SeatMap> seatMap({
    required String tripId,
    required int fromCityId,
    required int toCityId,
    required String fromLocationId,
    required String toLocationId,
    required String date,
  });

  Future<BusTicket> createTicket(
    BusCreateTicketRequest request, {
    required BusTripSummary trip,
    required BusStop fromStop,
    required BusStop toStop,
  });

  /// Reads the current payment/booking status for an order created by
  /// [createTicket]. Used to verify the rider actually paid after the gateway
  /// hands control back to the app.
  Future<BusOrderStatus> orderStatus(
    String orderId, {
    required String currency,
  });
}
