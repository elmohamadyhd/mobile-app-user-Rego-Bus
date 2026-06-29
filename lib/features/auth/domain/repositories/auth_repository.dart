import 'package:rego/features/auth/domain/entities/auth_session.dart';

/// Contract for the auth backend (`/auth/*`). The implementation lives in the
/// data layer; presentation talks only to this interface.
///
/// Phone is the identity throughout: every call is keyed by [phoneCode] +
/// [mobile] (the API has no email-based login).
abstract interface class AuthRepository {
  /// Signs in with phone + password and returns the session.
  Future<AuthSession> login({
    required String phoneCode,
    required String mobile,
    required String password,
  });

  /// Creates the account. The backend sends a verification OTP; the caller
  /// then collects it and calls [verifyOtp].
  Future<void> register({
    required String name,
    required String email,
    required String phoneCode,
    required String mobile,
    required String password,
    required String passwordConfirmation,
    String firebaseToken = '',
  });

  /// Verifies the registration OTP and returns the authenticated session.
  Future<AuthSession> verifyOtp({
    required String phoneCode,
    required String mobile,
    required String code,
  });

  /// Sends an OTP to the given phone.
  Future<void> sendOtp({required String phoneCode, required String mobile});

  /// Re-sends the OTP to the given phone.
  Future<void> resendOtp({required String phoneCode, required String mobile});

  /// Validates a reset OTP without consuming it (password-reset flow).
  Future<void> validateOtp({
    required String phoneCode,
    required String mobile,
    required String code,
  });

  /// Starts password recovery: sends a reset code to the phone.
  Future<void> forgetPassword({
    required String phoneCode,
    required String mobile,
  });

  /// Completes password recovery with the reset code and the new password.
  Future<void> resetPassword({
    required String phoneCode,
    required String mobile,
    required String code,
    required String password,
    required String passwordConfirmation,
  });
}
