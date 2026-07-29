import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/storage/secure_storage.dart';

/// Source of the device push token sent as `firebase_token`.
///
/// v1 uses the install UUID from [SecureStorage] (same as register). Swap the
/// provider override when Firebase Messaging is configured.
abstract interface class PushTokenProvider {
  Future<String> getToken();
}

final class DevicePushTokenProvider implements PushTokenProvider {
  DevicePushTokenProvider(this._storage);

  final SecureStorage _storage;

  @override
  Future<String> getToken() => _storage.readOrCreateDeviceToken();
}

final pushTokenProvider = Provider<PushTokenProvider>(
  (ref) => DevicePushTokenProvider(ref.watch(secureStorageProvider)),
);
