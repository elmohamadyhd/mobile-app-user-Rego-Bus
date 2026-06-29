/// Pure, locale-agnostic field checks. Screens map a `false` result to a
/// localized message; keeping the rules here avoids duplicating regexes.
abstract final class Validators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isValidEmail(String v) => _email.hasMatch(v.trim());

  /// National number length sanity check (digits only, 6–15).
  static bool isValidPhone(String v) {
    final digits = digitsOnly(v);
    return digits.length >= 6 && digits.length <= 15;
  }

  static String digitsOnly(String v) => v.replaceAll(RegExp(r'\D'), '');

  static bool isStrongEnough(String v) => v.length >= 6;
}
