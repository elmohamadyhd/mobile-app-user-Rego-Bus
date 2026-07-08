import 'package:rego/features/bus/data/mock_bus_data.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/domain/repositories/bus_repository.dart';

/// Mock-backed for now. When the live `/buses/*` API is wired, this gains a
/// `BusApi` dependency (via `dioProvider`) and maps DTOs to entities — the
/// notifier and providers do not change.
class BusRepositoryImpl implements BusRepository {
  @override
  Future<List<BusTripSummary>> searchTrips(
    String from,
    String to,
    String date,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return MockBusData.trips;
  }

  @override
  Future<BusTripDetail> tripDetail(String tripId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return MockBusData.detailFor(tripId);
  }
}
