import 'package:dio/dio.dart';

/// Transport layer over `/buses/*`. Returns raw decoded JSON bodies.
class BusApi {
  BusApi(this._dio);

  final Dio _dio;

  Future<dynamic> listLocations() async {
    final res = await _dio.get('/buses/locations');
    return res.data;
  }

  Future<dynamic> searchTrips({
    required int cityFrom,
    required int cityTo,
    required String date,
    required String currency,
    int page = 1,
  }) async {
    final res = await _dio.get(
      '/buses/trips',
      queryParameters: {
        'city_from': cityFrom,
        'city_to': cityTo,
        'date': date,
        'currency': currency,
        'page': page,
      },
    );
    return res.data;
  }

  Future<dynamic> tripById({
    required String tripId,
    required String currency,
  }) async {
    final res = await _dio.get(
      '/buses/trips/$tripId',
      queryParameters: {'currency': currency},
    );
    return res.data;
  }

  Future<dynamic> seatMap({
    required String tripId,
    required int fromCityId,
    required int toCityId,
    required String fromLocationId,
    required String toLocationId,
    required String date,
  }) async {
    final res = await _dio.get(
      '/buses/trips/$tripId/seats',
      queryParameters: {
        'from_city_id': fromCityId,
        'to_city_id': toCityId,
        'from_location_id': fromLocationId,
        'to_location_id': toLocationId,
        'date': date,
      },
    );
    return res.data;
  }

  Future<dynamic> createTicket({
    required String tripId,
    required Map<String, dynamic> body,
  }) async {
    final res = await _dio.post(
      '/buses/trips/$tripId/create-ticket',
      data: body,
    );
    return res.data;
  }
}
