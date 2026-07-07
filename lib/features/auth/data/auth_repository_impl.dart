import 'package:dio/dio.dart';

import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/auth/data/auth_api.dart';
import 'package:rego/features/auth/data/auth_envelope_keys.dart';
import 'package:rego/features/auth/data/models/auth_response_dto.dart';
import 'package:rego/features/auth/domain/entities/auth_session.dart';
import 'package:rego/features/auth/domain/exceptions/account_not_verified_exception.dart';
import 'package:rego/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api);

  final AuthApi _api;

  @override
  Future<AuthSession> login({
    required String phoneCode,
    required String mobile,
    required String password,
  }) {
    return _guard(() async {
      final envelope = await _api.login(
        phoneCode: phoneCode,
        mobile: mobile,
        password: password,
      ) as Map<String, dynamic>;
      if (envelope[AuthEnvelopeKeys.needVerfication] == true) {
        throw AccountNotVerifiedException(
          (envelope['message'] as String?) ?? 'Account verification required',
        );
      }

      return _parseSession(envelope);
    });
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String phoneCode,
    required String mobile,
    required String password,
    required String passwordConfirmation,
    String firebaseToken = '',
  }) {
    return _guard(() async {
      final envelope = await _api.register(
        name: name,
        email: email,
        phoneCode: phoneCode,
        mobile: mobile,
        password: password,
        passwordConfirmation: passwordConfirmation,
        firebaseToken: firebaseToken,
      );
      _ensureSuccessEnvelope(envelope);
    });
  }

  @override
  Future<AuthSession> verifyOtp({
    required String phoneCode,
    required String mobile,
    required String code,
  }) {
    return _guard(() async {
      final data = await _api.verifyOtp(
        phoneCode: phoneCode,
        mobile: mobile,
        code: code,
      );
      return _parseSession(data);
    });
  }

  @override
  Future<void> sendOtp({required String phoneCode, required String mobile}) {
    return _guard(() async {
      final envelope = await _api.sendOtp(phoneCode: phoneCode, mobile: mobile);
      _ensureSuccessEnvelope(envelope);
    });
  }

  @override
  Future<void> resendOtp({required String phoneCode, required String mobile}) {
    return _guard(() async {
      final envelope =
          await _api.resendOtp(phoneCode: phoneCode, mobile: mobile);
      _ensureSuccessEnvelope(envelope);
    });
  }

  @override
  Future<void> validateOtp({
    required String phoneCode,
    required String mobile,
    required String code,
  }) {
    return _guard(() async {
      final envelope = await _api.validateOtp(
        phoneCode: phoneCode,
        mobile: mobile,
        code: code,
      );
      _ensureSuccessEnvelope(envelope);
    });
  }

  @override
  Future<void> forgetPassword({
    required String phoneCode,
    required String mobile,
  }) {
    return _guard(() async {
      final envelope =
          await _api.forgetPassword(phoneCode: phoneCode, mobile: mobile);
      _ensureSuccessEnvelope(envelope);
    });
  }

  @override
  Future<void> resetPassword({
    required String phoneCode,
    required String mobile,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) {
    return _guard(() async {
      final envelope = await _api.resetPassword(
        phoneCode: phoneCode,
        mobile: mobile,
        code: code,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      _ensureSuccessEnvelope(envelope);
    });
  }

  void _ensureSuccessEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    final innerStatus = envelope['status'];
    if (innerStatus is num && innerStatus.toInt() != 200) {
      throw ApiException.fromEnvelope(envelope);
    }
  }

  AuthSession _parseSession(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    _ensureSuccessEnvelope(envelope);

    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('No auth token found in response');
    }

    final token = data['api_token'];
    if (token is! String || token.isEmpty) {
      throw const ApiException('No auth token found in response');
    }

    return AuthResponseDto.fromJson(data).toEntity();
  }

  /// Runs [action], converting Dio transport failures into [ApiException].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
