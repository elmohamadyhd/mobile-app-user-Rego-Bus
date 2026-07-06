import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';

/// Minimal mock of FlutterSecureStorage that uses an in-memory map.
class _InMemorySecureStorage extends FlutterSecureStorage {
  _InMemorySecureStorage(this._data);
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

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  ProviderContainer makeContainer(Map<String, String> memoryGuestModeStore) {
    final sessionData = <String, String>{};
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(
            storage: _InMemorySecureStorage(sessionData),
            memoryGuestModeStore: memoryGuestModeStore,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('build restores false when no guest flag is stored', () async {
    final container = makeContainer({});
    expect(await container.read(guestModeProvider.future), isFalse);
  });

  test('build restores true when a guest flag is already persisted',
      () async {
    final container = makeContainer({'guest_mode': 'true'});
    expect(await container.read(guestModeProvider.future), isTrue);
  });

  test('enable persists true and flips state', () async {
    final memory = <String, String>{};
    final container = makeContainer(memory);
    await container.read(guestModeProvider.future);

    await container.read(guestModeProvider.notifier).enable();

    expect(container.read(guestModeProvider).value, isTrue);
    expect(memory['guest_mode'], 'true');
  });

  test('disable clears the persisted flag and flips state', () async {
    final memory = <String, String>{'guest_mode': 'true'};
    final container = makeContainer(memory);
    await container.read(guestModeProvider.future);

    await container.read(guestModeProvider.notifier).disable();

    expect(container.read(guestModeProvider).value, isFalse);
    expect(memory.containsKey('guest_mode'), isFalse);
  });

  test('SessionController.logout also clears guest mode', () async {
    final memory = <String, String>{};
    final container = makeContainer(memory);

    await container.read(guestModeProvider.future);
    await container.read(guestModeProvider.notifier).enable();
    expect(container.read(guestModeProvider).value, isTrue);

    // Calling logout on the controller should clear guest mode
    final sessionController =
        container.read(sessionControllerProvider.notifier);
    await sessionController.logout();

    expect(container.read(guestModeProvider).value, isFalse);
    expect(memory.containsKey('guest_mode'), isFalse);
  });
}
