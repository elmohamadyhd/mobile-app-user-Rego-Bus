import 'package:dio/dio.dart';

class NotificationsApi {
  NotificationsApi(this._dio);

  final Dio _dio;

  Future<dynamic> list({int page = 1}) async {
    final res = await _dio.get(
      '/profile/notifications',
      queryParameters: {'page': page},
    );
    return res.data;
  }

  Future<void> deleteAll() async {
    await _dio.delete('/profile/notifications');
  }

  Future<void> delete(String id) async {
    await _dio.delete('/profile/notifications/$id');
  }

  Future<void> updateFirebaseToken(String token) async {
    await _dio.put(
      '/profile/firebase/token',
      data: FormData.fromMap({'firebase_token': token}),
    );
  }
}
