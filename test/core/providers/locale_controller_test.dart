import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/providers/locale_controller.dart';
import 'package:rego/core/storage/secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer createContainer({
    required Map<String, String> memoryLocaleStore,
    Locale deviceLocale = const Locale('en'),
  }) {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.localeTestValue = deviceLocale;

    return ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(memoryLocaleStore: memoryLocaleStore),
        ),
      ],
    );
  }

  Future<void> pumpMicrotasks() => Future<void>.delayed(Duration.zero);

  test('no saved override follows resolved device locale', () async {
    final container = createContainer(memoryLocaleStore: {});
    addTearDown(container.dispose);

    expect(container.read(localeControllerProvider).languageCode, 'en');

    await pumpMicrotasks();
    expect(container.read(localeControllerProvider).languageCode, 'en');
  });

  test('saved ar override sticks when device is English', () async {
    final container = createContainer(
      memoryLocaleStore: {'locale_override': 'ar'},
      deviceLocale: const Locale('en'),
    );
    addTearDown(container.dispose);

    expect(container.read(localeControllerProvider).languageCode, 'en');

    await pumpMicrotasks();
    expect(container.read(localeControllerProvider).languageCode, 'ar');
  });

  test('setLocale persists override and updates state', () async {
    final memory = <String, String>{};
    final container = createContainer(memoryLocaleStore: memory);
    addTearDown(container.dispose);

    container
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('ar'));

    expect(container.read(localeControllerProvider).languageCode, 'ar');
    expect(memory['locale_override'], 'ar');
  });

  test('useSystemLocale clears override and follows device again', () async {
    final memory = <String, String>{'locale_override': 'ar'};
    final container = createContainer(
      memoryLocaleStore: memory,
      deviceLocale: const Locale('en'),
    );
    addTearDown(container.dispose);

    expect(container.read(localeControllerProvider).languageCode, 'en');

    await pumpMicrotasks();
    expect(container.read(localeControllerProvider).languageCode, 'ar');

    container.read(localeControllerProvider.notifier).useSystemLocale();

    expect(memory.containsKey('locale_override'), isFalse);
    expect(container.read(localeControllerProvider).languageCode, 'en');
  });
}
