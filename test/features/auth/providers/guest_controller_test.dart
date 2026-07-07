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

  test('build always starts false and clears any legacy persisted flag',
      () async {
    final memory = <String, String>{'guest_mode': 'true'};
    final container = makeContainer(memory);

    expect(await container.read(guestModeProvider.future), isFalse);
    expect(memory.containsKey('guest_mode'), isFalse);
  });

  test('enable flips state without persisting', () async {
    final memory = <String, String>{};
    final container = makeContainer(memory);
    await container.read(guestModeProvider.future);

    await container.read(guestModeProvider.notifier).enable();

    expect(container.read(guestModeProvider).value, isTrue);
    expect(memory.containsKey('guest_mode'), isFalse);
  });

  test('disable flips state to false', () async {
    final container = makeContainer({});
    await container.read(guestModeProvider.future);
    await container.read(guestModeProvider.notifier).enable();

    await container.read(guestModeProvider.notifier).disable();

    expect(container.read(guestModeProvider).value, isFalse);
  });

  test('SessionController.logout also clears guest mode', () async {
    final container = makeContainer({});

    await container.read(guestModeProvider.future);
    await container.read(guestModeProvider.notifier).enable();
    expect(container.read(guestModeProvider).value, isTrue);

    final sessionController =
        container.read(sessionControllerProvider.notifier);
    await sessionController.logout();

    expect(container.read(guestModeProvider).value, isFalse);
  });
}
