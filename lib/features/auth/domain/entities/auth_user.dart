import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user.freezed.dart';
part 'auth_user.g.dart';

/// The signed-in user.
@freezed
abstract class AuthUser with _$AuthUser {
  const factory AuthUser({
    int? id,
    String? name,
    String? email,
    String? mobile,
    @JsonKey(name: 'phonecode') String? phoneCode,
    @JsonKey(name: 'avatar') String? avatarUrl,
    String? status,
    @JsonKey(name: 'is_profile_completed') bool? isProfileCompleted,
  }) = _AuthUser;

  factory AuthUser.fromJson(Map<String, dynamic> json) =>
      _$AuthUserFromJson(json);
}
