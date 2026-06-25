import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to environment variables. All values have safe defaults so
/// the app can run in local-only mode without a backend.
abstract final class AppConfig {
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://api.example.com';

  static String get apiKey => dotenv.env['API_KEY'] ?? '';

  static bool get isBackendConfigured => apiKey.isNotEmpty;
}
