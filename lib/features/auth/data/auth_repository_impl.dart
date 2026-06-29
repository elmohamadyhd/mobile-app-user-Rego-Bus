import 'package:dio/dio.dart';

import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/auth/data/auth_api.dart';
import 'package:rego/features/auth/data/models/auth_response_parser.dart';
import 'package:rego/features/auth/domain/entities/auth_session.dart';
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
      final data = await _api.login(
        phoneCode: phoneCode,
        mobile: mobile,
        password: password,
      );
      return AuthResponseParser.parseSession(data);
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
    return _guard(() => _api.register(
          name: name,
          email: email,
          phoneCode: phoneCode,
          mobile: mobile,
          password: password,
          passwordConfirmation: passwordConfirmation,
          firebaseToken: firebaseToken,
        ));
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
      return AuthResponseParser.parseSession(data);
    });
  }

  @override
  Future<void> sendOtp({required String phoneCode, required String mobile}) {
    return _guard(() => _api.sendOtp(phoneCode: phoneCode, mobile: mobile));
  }

  @override
  Future<void> resendOtp({required String phoneCode, required String mobile}) {
    return _guard(() => _api.resendOtp(phoneCode: phoneCode, mobile: mobile));
  }

  @override
  Future<void> validateOtp({
    required String phoneCode,
    required String mobile,
    required String code,
  }) {
    return _guard(
      () => _api.validateOtp(phoneCode: phoneCode, mobile: mobile, code: code),
    );
  }

  @override
  Future<void> forgetPassword({
    required String phoneCode,
    required String mobile,
  }) {
    return _guard(
      () => _api.forgetPassword(phoneCode: phoneCode, mobile: mobile),
    );
  }

  @override
  Future<void> resetPassword({
    required String phoneCode,
    required String mobile,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) {
    return _guard(() => _api.resetPassword(
          phoneCode: phoneCode,
          mobile: mobile,
          code: code,
          password: password,
          passwordConfirmation: passwordConfirmation,
        ));
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
