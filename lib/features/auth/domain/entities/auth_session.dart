import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:rego/features/auth/domain/entities/auth_user.dart';

part 'auth_session.freezed.dart';
part 'auth_session.g.dart';

/// An authenticated session: the Sanctum bearer [token] plus the (optional)
/// cached [user]. Persisted in secure storage and used by the router guard.
@freezed
abstract class AuthSession with _$AuthSession {
  const factory AuthSession({
    required String token,
    AuthUser? user,
  }) = _AuthSession;

  factory AuthSession.fromJson(Map<String, dynamic> json) =>
      _$AuthSessionFromJson(json);
}
