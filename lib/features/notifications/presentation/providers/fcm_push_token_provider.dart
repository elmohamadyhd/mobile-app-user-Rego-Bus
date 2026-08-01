import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:safaria/features/notifications/presentation/providers/push_token_provider.dart';

/// Returns the real FCM device token from Firebase Messaging.
final class FcmPushTokenProvider implements PushTokenProvider {
  FcmPushTokenProvider(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<String> getToken() async {
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('FCM token is unavailable');
    }
    return token;
  }
}
