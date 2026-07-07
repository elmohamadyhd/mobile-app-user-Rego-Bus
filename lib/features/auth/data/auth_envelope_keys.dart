/// JSON keys on Wadeny auth API envelopes.
abstract final class AuthEnvelopeKeys {
  /// Login response flag when credentials are valid but the account is
  /// unverified.
  ///
  /// **Backend typo — do not "fix".** The API field is spelled
  /// `need_verfication` (missing the second "i" in verification). Renaming
  /// this to `need_verification` in client code breaks the auth cycle.
  static const needVerfication = 'need_verfication';
}
