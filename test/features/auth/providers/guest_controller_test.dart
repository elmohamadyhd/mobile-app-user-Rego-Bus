import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import '../../../support/in_memory_secure_storage.dart';

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
            storage: InMemorySecureStorage(sessionData),
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

  test('build restores true when a guest flag is already persisted', () async {
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
