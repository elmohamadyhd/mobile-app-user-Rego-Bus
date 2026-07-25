import 'package:dio/dio.dart';

class PagesApi {
  PagesApi(this._dio);

  final Dio _dio;

  Future<dynamic> list() async {
    final res = await _dio.get('/pages');
    return res.data;
  }

  Future<dynamic> show(String slug) async {
    final res = await _dio.get('/pages/$slug');
    return res.data;
  }
}
