import 'package:safaria/features/auth/domain/entities/auth_user.dart';
import 'package:safaria/features/profile/domain/repositories/profile_repository.dart';

/// Minimal fake of [ProfileRepository] for widget tests. [verifyAltPhone]
/// returns [_user]. All other methods throw [UnimplementedError] — tests
/// that need them should use a different fake.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository(this._user);

  final AuthUser _user;

  @override
  Future<AuthUser> fetchProfile() => throw UnimplementedError();

  @override
  Future<AuthUser> updateProfile({
    required int id,
    required String name,
    required String email,
    required String phoneCode,
    required String mobile,
    String? avatarPath,
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> verifyAltPhone({
    required String phoneCode,
    required String mobile,
    required String code,
  }) async =>
      _user;

  @override
  Future<void> deleteAccount() => throw UnimplementedError();
}
