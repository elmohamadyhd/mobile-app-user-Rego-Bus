import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/core/utils/device_token.dart';

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
}
