import 'package:rego/features/bus/domain/entities/bus_trip.dart';

abstract interface class BusRepository {
  Future<List<BusTripSummary>> searchTrips(String from, String to, String date);
  Future<BusTripDetail> tripDetail(String tripId);
}
