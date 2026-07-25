import 'package:dio/dio.dart';

/// Transport layer over `/profile`. Returns raw decoded JSON bodies.
class ProfileApi {
  ProfileApi(this._dio);

  final Dio _dio;

  Future<dynamic> fetch() async {
    final res = await _dio.get('/profile');
    return res.data;
  }

  Future<dynamic> update(FormData body) async {
    final res = await _dio.post('/profile', data: body);
    return res.data;
  }
}
