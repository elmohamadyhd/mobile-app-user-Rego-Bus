import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/core/utils/device_token.dart';

import '../../support/in_memory_secure_storage.dart';

void main() {
  final uuidV4Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('readOrCreateDeviceToken generates and persists a UUID v4 token',
      () async {
    final memoryStore = <String, String>{};
    final storage = SecureStorage(memoryDeviceTokenStore: memoryStore);

    final first = await storage.readOrCreateDeviceToken();
    expect(first, matches(uuidV4Pattern));
    expect(memoryStore['device_token'], first);

    final second = await storage.readOrCreateDeviceToken();
    expect(second, first);
  });

  test('readOrCreateDeviceToken reuses an existing stored token', () async {
    const existing = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
    final memoryStore = <String, String>{'device_token': existing};
    final storage = SecureStorage(memoryDeviceTokenStore: memoryStore);

    final token = await storage.readOrCreateDeviceToken();
    expect(token, existing);
    expect(generateDeviceToken(), isNot(equals(existing)));
  });

  group('guest mode', () {
    test('isGuestMode is false when nothing is stored', () async {
      final storage = SecureStorage(memoryGuestModeStore: {});
      expect(await storage.isGuestMode(), isFalse);
    });

    test('setGuestMode persists true and isGuestMode reads it back', () async {
      final memoryStore = <String, String>{};
      final storage = SecureStorage(memoryGuestModeStore: memoryStore);

      await storage.setGuestMode();

      expect(await storage.isGuestMode(), isTrue);
      expect(memoryStore['guest_mode'], 'true');
    });

    test('clearGuestMode removes the flag', () async {
      final memoryStore = <String, String>{'guest_mode': 'true'};
      final storage = SecureStorage(memoryGuestModeStore: memoryStore);

      await storage.clearGuestMode();

      expect(await storage.isGuestMode(), isFalse);
      expect(memoryStore.containsKey('guest_mode'), isFalse);
    });
  });

  group('trip details coach', () {
    test('tripDetailsCoachSeen is false when nothing is stored', () async {
      final storage = SecureStorage(
        storage: InMemorySecureStorage({}),
      );
      expect(await storage.tripDetailsCoachSeen(), isFalse);
    });

    test('setTripDetailsCoachSeen persists true', () async {
      final memoryStore = <String, String>{};
      final storage =
          SecureStorage(storage: InMemorySecureStorage(memoryStore));

      await storage.setTripDetailsCoachSeen();

      expect(await storage.tripDetailsCoachSeen(), isTrue);
      expect(memoryStore['trip_details_coach_seen'], 'true');
    });
  });
}
