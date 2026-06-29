import 'package:rego/features/auth/domain/entities/auth_session.dart';
import 'package:rego/features/auth/domain/entities/auth_user.dart';

/// Tolerant extractor for the auth response envelope.
///
/// The backend's exact response shape isn't documented yet (Sanctum tokens
/// look like `1|abc...`), so we probe the common Laravel layouts:
///   • token under `token` / `access_token`, optionally nested in `data`
///   • user under `user` / `data.user`, or `data` itself
///
/// TODO(dto): replace this with the exact mapping once the response DTO is
/// provided. It's isolated here precisely so that swap is a one-file change.
abstract final class AuthResponseParser {
  static AuthSession parseSession(dynamic body) {
    final root = _asMap(body) ?? const {};
    final data = _asMap(root['data']) ?? root;

    final token = _firstString(root, const ['token', 'access_token']) ??
        _firstString(data, const ['token', 'access_token']);
    if (token == null || token.isEmpty) {
      throw const FormatException('No auth token found in response');
    }

    final userJson = _asMap(root['user']) ??
        _asMap(data['user']) ??
        // `data` may itself be the user object (sibling token at the root).
        (data.containsKey('token') || data.containsKey('access_token')
            ? null
            : (data.isEmpty ? null : data));

    return AuthSession(
      token: token,
      user: userJson == null ? null : AuthUser.fromJson(userJson),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  static String? _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }
}
