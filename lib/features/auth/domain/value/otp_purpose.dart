/// What an OTP screen is verifying. Controls which endpoints the OTP screen
/// calls and where it routes on success.
enum OtpPurpose {
  /// After Register: verifies the phone via `/auth/verify-otp`, which returns
  /// the authenticated session.
  registration,

  /// Inside the forgot-password flow: validates the reset code via
  /// `/auth/validate-otp`, then continues to the New-password screen.
  passwordReset,
}
