import 'package:rego/features/auth/domain/entities/auth_session.dart';
import 'package:rego/features/auth/domain/repositories/auth_repository.dart';

/// Minimal fake of [AuthRepository] for widget tests that only need [login]
/// or [verifyOtp] to succeed with a fixed session. All other methods throw
/// [UnimplementedError] — tests that need them should use a different fake.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this._session);
  final AuthSession _session;

  @override
  Future<AuthSession> login({
    required String phoneCode,
    required String mobile,
    required String password,
  }) async =>
      _session;

  @override
  Future<void> register({
    required String name,
    required String email,
    required String phoneCode,
    required String mobile,
    required String password,
    required String passwordConfirmation,
    String firebaseToken = '',
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> verifyOtp({
    required String phoneCode,
    required String mobile,
    required String code,
  }) async =>
      _session;

  @override
  Future<void> sendOtp({required String phoneCode, required String mobile}) =>
      throw UnimplementedError();

  @override
  Future<void> resendOtp({
    required String phoneCode,
    required String mobile,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> validateOtp({
    required String phoneCode,
    required String mobile,
    required String code,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> forgetPassword({
    required String phoneCode,
    required String mobile,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> resetPassword({
    required String phoneCode,
    required String mobile,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) =>
      throw UnimplementedError();
}
