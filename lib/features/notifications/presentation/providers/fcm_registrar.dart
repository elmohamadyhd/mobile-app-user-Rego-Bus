import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:safaria/features/notifications/presentation/providers/push_token_provider.dart';

/// Registers the device push token with the backend when the user is signed in.
///
/// Watch from the app root. Failures are logged and never surface to the UI.
final fcmRegistrarProvider = Provider<void>((ref) {
  final guest = ref.watch(guestModeProvider).value;
  final session = ref.watch(sessionControllerProvider).value;
  if (guest != false || session == null) return;

  Future<void>(() async {
    try {
      final token = await ref.read(pushTokenProvider).getToken();
      await ref
          .read(notificationsRepositoryProvider)
          .updateFirebaseToken(token);
    } catch (e, st) {
      developer.log(
        'Failed to sync push token',
        name: 'fcmRegistrar',
        error: e,
        stackTrace: st,
      );
    }
  });
});
