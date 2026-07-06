import 'package:rego/features/auth/domain/value/otp_purpose.dart';

/// Arguments handed to the OTP screen via go_router `extra`.
class OtpArgs {
  const OtpArgs({
    required this.phoneCode,
    required this.mobile,
    required this.purpose,
    this.returnTo,
  });

  final String phoneCode;
  final String mobile;
  final OtpPurpose purpose;

  /// Where to navigate after a successful registration OTP verify, when this
  /// flow was entered through the guest sign-in gate. Null for the normal
  /// (non-guest) registration flow, which lands on Home as before.
  final String? returnTo;
}

/// Arguments handed to the New-password screen via go_router `extra`.
class ResetArgs {
  const ResetArgs({
    required this.phoneCode,
    required this.mobile,
    required this.code,
  });

  final String phoneCode;
  final String mobile;
  final String code;
}

/// Arguments handed to the Login/Register screens via go_router `extra` when
/// they're entered through the guest sign-in gate (see `guest_gate_sheet.dart`).
/// [returnTo] is the route to land on after a successful sign-in/registration
/// instead of the default Home — typically the screen the guest was gated
/// from (e.g. the booking confirm screen).
class AuthGateArgs {
  const AuthGateArgs({required this.returnTo});

  final String returnTo;
}
