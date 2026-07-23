import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to environment variables. All values have safe defaults so
/// the app can run in local-only mode without a backend.
abstract final class AppConfig {
  /// Wadeny backend base URL. Future environments only swap this value
  /// (via `.env`); call-sites never hardcode hosts.
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://demo.safaria.travel/api/v1';

  /// Optional static API key (unused by the auth flow, which authenticates
  /// per-user via Sanctum bearer tokens). Kept for non-auth integrations.
  static String get apiKey => dotenv.env['API_KEY'] ?? '';

  static bool get isBackendConfigured => apiBaseUrl.isNotEmpty;

  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  static bool get isGoogleMapsConfigured => googleMapsApiKey.isNotEmpty;
}
