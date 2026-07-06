import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/core/network/dio_client.dart';
import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/features/auth/data/auth_api.dart';
import 'package:rego/features/auth/data/auth_repository_impl.dart';
import 'package:rego/features/auth/domain/entities/auth_session.dart';
import 'package:rego/features/auth/domain/entities/auth_user.dart';
import 'package:rego/features/auth/domain/repositories/auth_repository.dart';

final authApiProvider =
    Provider<AuthApi>((ref) => AuthApi(ref.watch(dioProvider)));

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authApiProvider)),
);

/// Owns the authenticated session. `null` data ⇒ signed out.
///
/// [build] restores any persisted session from secure storage on launch, so
/// the router guard can decide where to land before the first frame settles.
class SessionController extends AsyncNotifier<AuthSession?> {
  SecureStorage get _storage => ref.read(secureStorageProvider);

  @override
  Future<AuthSession?> build() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) return null;

    AuthUser? user;
    final userJson = await _storage.readUser();
    if (userJson != null && userJson.isNotEmpty) {
      try {
        user = AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      } catch (_) {
        // Corrupt cache — keep the token, drop the stale user.
      }
    }
    return AuthSession(token: token, user: user);
  }

  /// Persists [session] and flips the app to "signed in".
  Future<void> setSession(AuthSession session) async {
    await _storage.writeToken(session.token);
    if (session.user != null) {
      await _storage.writeUser(jsonEncode(session.user!.toJson()));
    }
    state = AsyncData(session);
  }

  Future<void> logout() async {
    await _storage.clearSession();
    await ref.read(guestModeProvider.notifier).disable();
    state = const AsyncData(null);
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, AuthSession?>(
  SessionController.new,
);

/// Tracks whether the current install is browsing without an account.
/// Independent of [SessionController] — a token always means a real
/// authenticated session; this is a separate, best-effort persisted flag.
class GuestController extends AsyncNotifier<bool> {
  SecureStorage get _storage => ref.read(secureStorageProvider);

  @override
  Future<bool> build() => _storage.isGuestMode();

  Future<void> enable() async {
    await _storage.setGuestMode();
    state = const AsyncData(true);
  }

  Future<void> disable() async {
    await _storage.clearGuestMode();
    state = const AsyncData(false);
  }
}

final guestModeProvider = AsyncNotifierProvider<GuestController, bool>(
  GuestController.new,
);
