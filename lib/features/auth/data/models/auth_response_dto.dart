import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:rego/features/auth/domain/entities/auth_session.dart';
import 'package:rego/features/auth/domain/entities/auth_user.dart';

part 'auth_response_dto.freezed.dart';
part 'auth_response_dto.g.dart';

int? _intFromJson(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _stringFromJson(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

/// The `data` object returned by `/auth/login` and `/auth/verify-otp`.
@freezed
abstract class AuthResponseDto with _$AuthResponseDto {
  const factory AuthResponseDto({
    @JsonKey(fromJson: _intFromJson) int? id,
    @JsonKey(fromJson: _stringFromJson) String? name,
    @JsonKey(fromJson: _stringFromJson) String? email,
    @JsonKey(fromJson: _stringFromJson) String? mobile,
    @JsonKey(name: 'phonecode', fromJson: _stringFromJson) String? phoneCode,
    @JsonKey(fromJson: _stringFromJson) String? status,
    @JsonKey(name: 'avatar', fromJson: _stringFromJson) String? avatarUrl,
    @JsonKey(name: 'api_token') required String apiToken,
    @JsonKey(name: 'is_profile_completed') bool? isProfileCompleted,
  }) = _AuthResponseDto;

  factory AuthResponseDto.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseDtoFromJson(json);
}

extension AuthResponseDtoMapper on AuthResponseDto {
  AuthSession toEntity() => AuthSession(
        token: apiToken,
        user: AuthUser(
          id: id,
          name: name,
          email: email,
          mobile: mobile,
          phoneCode: phoneCode,
          status: status,
          avatarUrl: avatarUrl,
          isProfileCompleted: isProfileCompleted,
        ),
      );
}
