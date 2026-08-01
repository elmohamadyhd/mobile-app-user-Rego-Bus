import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Initializes Firebase and registers the background message handler.
///
/// Call from [main] before [runApp]. Android reads config from
/// `android/app/google-services.json`.
Future<void> initializeFirebasePush() async {
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
