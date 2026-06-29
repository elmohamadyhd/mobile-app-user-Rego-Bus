import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

/// Thin wrapper over [FlutterSecureStorage] for the handful of keys the app
/// persists across launches: the auth token, a cached user blob, the
/// "onboarding seen" flag, and an optional locale override.
class SecureStorage {
  SecureStorage({
    FlutterSecureStorage? storage,
    Map<String, String>? memoryLocaleStore,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _memoryLocaleStore = memoryLocaleStore;

  final FlutterSecureStorage _storage;
  final Map<String, String>? _memoryLocaleStore;

  static const _kToken = 'auth_token';
  static const _kUser = 'auth_user';
  static const _kOnboardingSeen = 'onboarding_seen';
  static const _kLocaleOverride = 'locale_override';

  Future<String?> readToken() => _storage.read(key: _kToken);
  Future<void> writeToken(String token) =>
      _storage.write(key: _kToken, value: token);

  Future<String?> readUser() => _storage.read(key: _kUser);
  Future<void> writeUser(String json) =>
      _storage.write(key: _kUser, value: json);

  Future<void> clearSession() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUser);
  }

  Future<bool> onboardingSeen() async =>
      (await _storage.read(key: _kOnboardingSeen)) == 'true';
  Future<void> setOnboardingSeen() =>
      _storage.write(key: _kOnboardingSeen, value: 'true');

  Future<String?> readLocaleOverride() async {
    if (_memoryLocaleStore != null) {
      return _memoryLocaleStore[_kLocaleOverride];
    }
    return _storage.read(key: _kLocaleOverride);
  }

  Future<void> writeLocaleOverride(String languageCode) async {
    if (_memoryLocaleStore != null) {
      _memoryLocaleStore[_kLocaleOverride] = languageCode;
      return;
    }
    await _storage.write(key: _kLocaleOverride, value: languageCode);
  }

  Future<void> clearLocaleOverride() async {
    if (_memoryLocaleStore != null) {
      _memoryLocaleStore.remove(_kLocaleOverride);
      return;
    }
    await _storage.delete(key: _kLocaleOverride);
  }
}
