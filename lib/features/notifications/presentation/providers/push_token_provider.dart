import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/storage/secure_storage.dart';
import 'package:safaria/features/notifications/presentation/providers/fcm_push_token_provider.dart';

/// Source of the device push token sent as `firebase_token`.
abstract interface class PushTokenProvider {
  Future<String> getToken();
}

/// Fallback when Firebase Messaging is unavailable (tests, unsupported platforms).
final class DevicePushTokenProvider implements PushTokenProvider {
  DevicePushTokenProvider(this._storage);

  final SecureStorage _storage;

  @override
  Future<String> getToken() => _storage.readOrCreateDeviceToken();
}

final pushTokenProvider = Provider<PushTokenProvider>(
  (ref) => FcmPushTokenProvider(FirebaseMessaging.instance),
);
