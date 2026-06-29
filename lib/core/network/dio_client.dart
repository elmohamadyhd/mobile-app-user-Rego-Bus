import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/core/config/app_config.dart';
import 'package:rego/core/providers/locale_controller.dart';
import 'package:rego/core/storage/secure_storage.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(_AuthInterceptor(ref));
  dio.interceptors.add(_LogInterceptor());
  return dio;
});

/// Attaches the active `Accept-Language` and the stored bearer token (when
/// present) to every request. Auth endpoints work without a token; protected
/// endpoints get the Sanctum token once the user is signed in.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._ref);

  final Ref _ref;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['Accept-Language'] =
        _ref.read(localeControllerProvider).languageCode;

    final token = await _ref.read(secureStorageProvider).readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

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
