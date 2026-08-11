import 'package:dio/dio.dart';

import 'package:safaria/features/car/data/car_dto_mapper.dart';

class CarApi {
  CarApi(this._dio);

  final Dio _dio;

  Future<dynamic> searchQuotes({
    required double fromLatitude,
    required double fromLongitude,
    required double toLatitude,
    required double toLongitude,
    required bool rounded,
    required DateTime departDate,
    DateTime? returnDate,
  }) async {
    final queryParameters = <String, dynamic>{
      'from_latitude': fromLatitude,
      'from_longitude': fromLongitude,
      'to_latitude': toLatitude,
      'to_longitude': toLongitude,
      'rounded': rounded,
      'date': CarDtoMapper.formatOrderDate(departDate),
    };
    if (rounded && returnDate != null) {
      queryParameters['return_date'] = CarDtoMapper.formatOrderDate(returnDate);
    }
    final res = await _dio.get(
      '/private/search',
      queryParameters: queryParameters,
    );
    return res.data;
  }

  Future<dynamic> getTrip(int id) async {
    final res = await _dio.get('/private/trips/$id');
    return res.data;
  }

  Future<dynamic> createOrder(Map<String, dynamic> body) async {
    final res = await _dio.post('/private/orders', data: body);
    return res.data;
  }

  Future<dynamic> payOrder({
    required int orderId,
    required Map<String, dynamic> body,
  }) async {
    final res = await _dio.post('/private/orders/$orderId/pay', data: body);
    return res.data;
  }

  Future<dynamic> cancelOrder(int orderId) async {
    final res = await _dio.put('/private/orders/$orderId/cancel');
    return res.data;
  }

  Future<dynamic> listOrders() async {
    final res = await _dio.get('/profile/private/orders');
    return res.data;
  }

  Future<dynamic> getOrder(int orderId) async {
    final res = await _dio.get('/profile/private/orders/$orderId');
    return res.data;
  }

  Future<dynamic> submitReview({
    required int orderId,
    required int rating,
    String? comment,
  }) async {
    final body = <String, dynamic>{'rating': '$rating'};
    final trimmed = comment?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      body['comment'] = trimmed;
    }
    final res = await _dio.post(
      '/profile/private/orders/$orderId/review',
      data: body,
    );
    return res.data;
  }
}
