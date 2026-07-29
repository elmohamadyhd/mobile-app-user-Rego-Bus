import 'package:google_sign_in/google_sign_in.dart';

import 'package:safaria/core/config/app_config.dart';

/// Thrown by [GoogleSignInService.signIn] when Google Sign-In fails for a
/// reason other than the user cancelling (cancellation is reported as a
/// `null` return instead of an exception).
class GoogleSignInFailure implements Exception {
  const GoogleSignInFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin wrapper over the `google_sign_in` package so the repository/UI
/// layers never depend on the third-party SDK directly.
class GoogleSignInService {
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleWebClientId,
    );
    _initialized = true;
  }

  /// Runs the interactive Google sign-in flow and returns the ID token to
  /// send to the backend. Returns `null` if the user cancelled — callers
  /// should treat that as a silent no-op, not an error.
  Future<String?> signIn() async {
    await _ensureInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      return mapCancellation(e);
    }
  }

  Future<void> signOut() => GoogleSignIn.instance.signOut();

  /// Maps a [GoogleSignInException] to `null` when it represents user
  /// cancellation, or rethrows it as a [GoogleSignInFailure] otherwise.
  /// Extracted as a pure static function so it's testable without a real
  /// platform channel.
  static String? mapCancellation(GoogleSignInException e) {
    if (e.code == GoogleSignInExceptionCode.canceled) return null;
    throw GoogleSignInFailure(e.description ?? e.code.name);
  }
}
