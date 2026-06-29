import 'package:dio/dio.dart';

/// Transport layer over the `/auth/*` endpoints. Returns the raw decoded JSON
/// body; mapping to domain types happens in the repository.
///
/// Per the Wadeny collection, auth endpoints take **form-data** (except
/// forget-password, which takes JSON).
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<dynamic> login({
    required String phoneCode,
    required String mobile,
    required String password,
  }) async {
    final res = await _dio.post(
      '/auth/login',
      data: FormData.fromMap({
        'phonecode': phoneCode,
        'mobile': mobile,
        'password': password,
      }),
    );
    return res.data;
  }

  Future<dynamic> register({
    required String name,
    required String email,
    required String phoneCode,
    required String mobile,
    required String password,
    required String passwordConfirmation,
    required String firebaseToken,
  }) async {
    final res = await _dio.post(
      '/auth/register',
      data: FormData.fromMap({
        'name': name,
        'email': email,
        'phonecode': phoneCode,
        'mobile': mobile,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'firebase_token': firebaseToken,
      }),
    );
    return res.data;
  }

  Future<dynamic> verifyOtp({
    required String phoneCode,
    required String mobile,
    required String code,
  }) async {
    final res = await _dio.post(
      '/auth/verify-otp',
      data: FormData.fromMap({
        'phonecode': phoneCode,
        'mobile': mobile,
        'code': code,
      }),
    );
    return res.data;
  }

  Future<dynamic> sendOtp({
    required String phoneCode,
    required String mobile,
  }) async {
    final res = await _dio.post(
      '/auth/send-otp',
      data: FormData.fromMap({'phonecode': phoneCode, 'mobile': mobile}),
    );
    return res.data;
  }

  Future<dynamic> resendOtp({
    required String phoneCode,
    required String mobile,
  }) async {
    final res = await _dio.post(
      '/auth/resend-otp',
      data: FormData.fromMap({'phonecode': phoneCode, 'mobile': mobile}),
    );
    return res.data;
  }

  Future<dynamic> validateOtp({
    required String phoneCode,
    required String mobile,
    required String code,
  }) async {
    final res = await _dio.post(
      '/auth/validate-otp',
      data: FormData.fromMap({
        'phonecode': phoneCode,
        'mobile': mobile,
        'code': code,
      }),
    );
    return res.data;
  }

  Future<dynamic> forgetPassword({
    required String phoneCode,
    required String mobile,
  }) async {
    final res = await _dio.post(
      '/auth/forget-password',
      data: {'phonecode': int.tryParse(phoneCode) ?? phoneCode, 'mobile': mobile},
    );
    return res.data;
  }

  Future<dynamic> resetPassword({
    required String phoneCode,
    required String mobile,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    final res = await _dio.post(
      '/auth/reset-password',
      data: FormData.fromMap({
        'phonecode': phoneCode,
        'mobile': mobile,
        'code': code,
        'password': password,
        'password_confirmation': passwordConfirmation,
      }),
    );
    return res.data;
  }
}
