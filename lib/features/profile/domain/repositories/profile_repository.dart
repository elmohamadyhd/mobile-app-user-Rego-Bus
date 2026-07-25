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
  });
}
