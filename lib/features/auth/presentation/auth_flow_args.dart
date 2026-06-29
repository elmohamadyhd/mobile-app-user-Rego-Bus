import 'package:rego/features/auth/domain/value/otp_purpose.dart';

/// Arguments handed to the OTP screen via go_router `extra`.
class OtpArgs {
  const OtpArgs({
    required this.phoneCode,
    required this.mobile,
    required this.purpose,
  });

  final String phoneCode;
  final String mobile;
  final OtpPurpose purpose;
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
