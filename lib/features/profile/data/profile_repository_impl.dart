import 'package:dio/dio.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/features/auth/domain/entities/auth_user.dart';
import 'package:safaria/features/profile/data/profile_api.dart';
import 'package:safaria/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._api);

  final ProfileApi _api;

  @override
  Future<AuthUser> fetchProfile() =>
      _guard(() async => _userFromEnvelope(await _api.fetch()));

  @override
  Future<AuthUser> updateProfile({
    required int id,
    required String name,
    required String email,
    required String phoneCode,
    required String mobile,
  }) =>
      _guard(() async {
        final envelope = await _api.update(
          FormData.fromMap({
            'id': id,
            'name': name,
            'email': email,
            'mobile': mobile,
            'country_code': phoneCode,
          }),
        );
        return _userFromEnvelope(envelope);
      });

  AuthUser _userFromEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    final innerStatus = envelope['status'];
    if (innerStatus is num && innerStatus.toInt() != 200) {
      throw ApiException.fromEnvelope(envelope);
    }

    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('No user data in response');
    }

    return AuthUser.fromJson(data);
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
