import 'package:dio/dio.dart';

class CarApi {
  CarApi(this._dio);

  final Dio _dio;

  Future<dynamic> searchQuotes({
    required double fromLatitude,
    required double fromLongitude,
    required double toLatitude,
    required double toLongitude,
    required bool rounded,
  }) async {
    final res = await _dio.get(
      '/private/search',
      queryParameters: {
        'from_latitude': fromLatitude,
        'from_longitude': fromLongitude,
        'to_latitude': toLatitude,
        'to_longitude': toLongitude,
        'rounded': rounded,
      },
    );
    return res.data;
  }
}
