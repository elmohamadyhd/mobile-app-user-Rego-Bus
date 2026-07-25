import 'package:dio/dio.dart';

class AddressesApi {
  AddressesApi(this._dio);

  final Dio _dio;

  Future<dynamic> list({int page = 1}) async {
    final res = await _dio.get(
      '/profile/address-book',
      queryParameters: {'page': page},
    );
    return res.data;
  }

  Future<dynamic> create(Map<String, dynamic> body) async {
    final res = await _dio.post('/profile/address-book', data: body);
    return res.data;
  }

  Future<dynamic> update(int id, Map<String, dynamic> body) async {
    final res = await _dio.put('/profile/address-book/$id', data: body);
    return res.data;
  }

  Future<void> delete(int id) async {
    await _dio.delete('/profile/address-book/$id');
  }
}
