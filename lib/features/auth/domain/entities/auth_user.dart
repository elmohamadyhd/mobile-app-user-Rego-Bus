import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user.freezed.dart';
part 'auth_user.g.dart';

/// The signed-in user.
///
/// Fields are intentionally nullable and tolerant: the backend's exact user
/// payload isn't finalized yet. Tighten this up when the response DTO lands.
@freezed
abstract class AuthUser with _$AuthUser {
  const factory AuthUser({
    int? id,
    String? name,
    String? email,
    String? mobile,
    @JsonKey(name: 'phonecode') String? phoneCode,
    @JsonKey(name: 'avatar') String? avatarUrl,
  }) = _AuthUser;

  factory AuthUser.fromJson(Map<String, dynamic> json) =>
      _$AuthUserFromJson(json);
}
