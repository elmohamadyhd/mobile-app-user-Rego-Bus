import 'package:dio/dio.dart';

/// A user-presentable error derived from a failed API call.
///
/// Pulls Laravel's `{ "message": ..., "errors": { field: [..] } }` envelope
/// when present, and otherwise maps transport failures (timeouts, no network)
/// to a friendly message.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;

  /// Field-level validation errors keyed by field name.
  final Map<String, List<String>>? errors;

  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    final data = response?.data;
    String? message;
    Map<String, List<String>>? errors;

    if (data is Map) {
      final m = data['message'];
      if (m is String && m.isNotEmpty) message = m;

      final rawErrors = data['errors'];
      if (rawErrors is Map && rawErrors.isNotEmpty) {
        errors = rawErrors.map(
          (key, value) => MapEntry(
            key.toString(),
            value is List
                ? value.map((v) => v.toString()).toList()
                : [value.toString()],
          ),
        );
        // Surface the first field error when there's no top-level message.
        if (message == null) {
          final firstList = errors.values.first;
          if (firstList.isNotEmpty) message = firstList.first;
        }
      }
    }

    message ??= switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        'Connection timed out. Please try again.',
      DioExceptionType.connectionError => 'No internet connection.',
      _ => 'Something went wrong. Please try again.',
    };

    return ApiException(
      message,
      statusCode: response?.statusCode,
      errors: errors,
    );
  }

  @override
  String toString() => message;
}
