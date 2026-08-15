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

  /// OAuth 2.0 "Web application" client ID used to request a verifiable
  /// Google ID token. Required for `GoogleSignIn.initialize`.
  static String get googleWebClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';

  static bool get isGoogleSignInConfigured => googleWebClientId.isNotEmpty;

  /// When false, login/register hide the Google sign-in row.
  static const bool showSocialLogin = false;

  /// When false, Home and Tickets hide the Flight tab and flight routes
  /// are not registered. Flip to true to ship the flight booking flow.
  static const bool showFlights = true;
}
