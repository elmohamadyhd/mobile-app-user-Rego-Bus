import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        if (AppConfig.apiKey.isNotEmpty) 'Authorization': 'Bearer ${AppConfig.apiKey}',
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(_LogInterceptor());
  return dio;
});

class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // ignore: avoid_print
    print('[HTTP] ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // ignore: avoid_print
    print('[HTTP] Error ${err.response?.statusCode}: ${err.message}');
    handler.next(err);
  }
}
