import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal mock of FlutterSecureStorage that uses an in-memory map.
///
/// Useful for testing code that needs to read/write to secure storage without
/// triggering platform-channel calls that fail in plain `flutter test` environments.
class InMemorySecureStorage extends FlutterSecureStorage {
  InMemorySecureStorage(this._data);
  final Map<String, String> _data;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
  }) async => _data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
  }) async => _data.remove(key);

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
  }) async => Map.from(_data);

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
  }) async => _data.clear();

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
  }) async => _data.containsKey(key);

  // Stub out remaining properties/methods
  @override
  AndroidOptions get aOptions => const AndroidOptions(
    encryptedSharedPreferences: true,
  );

  @override
  IOSOptions get iOptions => const IOSOptions();

  @override
  LinuxOptions get lOptions => const LinuxOptions();

  @override
  MacOsOptions get mOptions => const MacOsOptions();

  @override
  WindowsOptions get wOptions => const WindowsOptions();

  @override
  WebOptions get webOptions => const WebOptions();

  @override
  Stream<bool>? get onCupertinoProtectedDataAvailabilityChanged => null;

  @override
  Future<bool?> isCupertinoProtectedDataAvailable() async => null;

  @override
  void registerListener({
    required String key,
    required Function(String)? listener,
  }) {}

  @override
  void unregisterListener({
    required String key,
    required Function(String)? listener,
  }) {}

  @override
  void unregisterAllListeners() {}

  @override
  void unregisterAllListenersForKey({required String key}) {}
}
