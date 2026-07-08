import 'package:dio/dio.dart';

import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/bus/data/bus_api.dart';
import 'package:rego/features/bus/data/bus_dto_mapper.dart';
import 'package:rego/features/bus/domain/entities/bus_location.dart';
import 'package:rego/features/bus/domain/entities/bus_search_params.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/domain/entities/seat_map.dart';
import 'package:rego/features/bus/domain/repositories/bus_repository.dart';

class BusRepositoryImpl implements BusRepository {
  BusRepositoryImpl(this._api);

  final BusApi _api;

  @override
  Future<List<BusLocation>> listLocations() {
    return _guard(() async {
      final body = await _api.listLocations();
      final locations = BusDtoMapper.locationsFromEnvelope(body);
      if (locations.isEmpty) {
        throw const ApiException('No locations returned', statusCode: 200);
      }
      return locations;
    });
  }

  @override
  Future<BusTripsPage> searchTrips(BusSearchParams params, {int page = 1}) {
    return _guard(() async {
      final body = await _api.searchTrips(
        cityFrom: params.cityFromId,
        cityTo: params.cityToId,
        date: _isoDate(params.date),
        currency: params.currency,
        page: page,
      );
      return BusDtoMapper.tripsPageFromEnvelope(body);
    });
  }

  @override
  Future<BusTripSummary> tripById(String tripId, {required String currency}) {
    return _guard(() async {
      final body = await _api.tripById(tripId: tripId, currency: currency);
      return BusDtoMapper.tripFromEnvelope(body);
    });
  }

  @override
  Future<SeatMap> seatMap({
    required String tripId,
    required int fromCityId,
    required int toCityId,
    required String fromLocationId,
    required String toLocationId,
    required String date,
  }) {
    return _guard(() async {
      final body = await _api.seatMap(
        tripId: tripId,
        fromCityId: fromCityId,
        toCityId: toCityId,
        fromLocationId: fromLocationId,
        toLocationId: toLocationId,
        date: date,
      );
      return BusDtoMapper.seatMapFromEnvelope(body);
    });
  }

  @override
  Future<BusTicket> createTicket(
    BusCreateTicketRequest request, {
    required BusTripSummary trip,
    required BusStop fromStop,
    required BusStop toStop,
  }) {
    return _guard(() async {
      final body = await _api.createTicket(
        tripId: request.tripId,
        body: BusDtoMapper.createTicketBody(request),
      );
      return BusDtoMapper.ticketFromEnvelope(
        body: body,
        trip: trip,
        fromStop: fromStop,
        toStop: toStop,
        selectedSeats: request.seats.map((s) => s.seatId).toList(),
      );
    });
  }

  String _isoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
