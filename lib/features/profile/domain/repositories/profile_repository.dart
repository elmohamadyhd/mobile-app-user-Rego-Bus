import 'package:safaria/features/auth/domain/entities/auth_user.dart';

/// Contract for `/profile` show + update. The user shape matches [AuthUser].
abstract interface class ProfileRepository {
  Future<AuthUser> fetchProfile();

  Future<AuthUser> updateProfile({
    required int id,
    required String name,
    required String email,
    required String phoneCode,
    required String mobile,
    String? avatarPath,
  });

  /// Verifies [code] and attaches [mobile]/[phoneCode] to the signed-in
  /// account via `/profile/verify-alt-phone`. Used to complete a Google
  /// sign-up that has no phone on file yet.
  Future<AuthUser> verifyAltPhone({
    required String phoneCode,
    required String mobile,
    required String code,
  });
}
