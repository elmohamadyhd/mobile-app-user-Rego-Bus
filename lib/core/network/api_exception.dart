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

  /// Parses the Wadeny JSON envelope when HTTP succeeded but `status` != 200.
  factory ApiException.fromEnvelope(Map<String, dynamic> envelope) {
    final parsed = _parseEnvelopeFields(envelope);
    return ApiException(
      parsed.message ?? 'Something went wrong. Please try again.',
      statusCode: _innerStatusCode(envelope['status']),
      errors: parsed.errors,
    );
  }

  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    final data = response?.data;
    String? message;
    Map<String, List<String>>? errors;

    if (data is Map<String, dynamic>) {
      final parsed = _parseEnvelopeFields(data);
      message = parsed.message;
      errors = parsed.errors;
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

  static int? _innerStatusCode(dynamic status) {
    if (status is num) return status.toInt();
    return null;
  }

  static _EnvelopeFields _parseEnvelopeFields(Map<String, dynamic> envelope) {
    String? message;
    Map<String, List<String>>? errors;

    final m = envelope['message'];
    if (m is String && m.isNotEmpty) message = m;

    final rawErrors = envelope['errors'];
    if (rawErrors is Map && rawErrors.isNotEmpty) {
      errors = rawErrors.map(
        (key, value) => MapEntry(
          key.toString(),
          value is List
              ? value.map((v) => v.toString()).toList()
              : [value.toString()],
        ),
      );
      if (message == null) {
        final firstList = errors.values.first;
        if (firstList.isNotEmpty) message = firstList.first;
      }
    }

    return _EnvelopeFields(message: message, errors: errors);
  }

  @override
  String toString() => message;
}

class _EnvelopeFields {
  const _EnvelopeFields({this.message, this.errors});

  final String? message;
  final Map<String, List<String>>? errors;
}
