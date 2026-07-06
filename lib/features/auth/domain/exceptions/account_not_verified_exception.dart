import 'package:rego/features/auth/domain/repositories/auth_repository.dart';

/// Thrown by [AuthRepository.login] when the backend reports
/// `need_verification: true`: credentials were correct but the account
/// still needs phone verification. The backend has already dispatched a
/// fresh OTP, so callers should navigate straight to OTP verification
/// rather than treating this as a login error.
class AccountNotVerifiedException implements Exception {
  const AccountNotVerifiedException([
    this.message = 'Account verification required',
  ]);

  final String message;

  @override
  String toString() => message;
}
