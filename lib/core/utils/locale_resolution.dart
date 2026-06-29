import 'package:flutter/material.dart';

import 'package:rego/l10n/app_localizations.dart';

/// Maps the device locale to a supported app locale (`ar` / `en`).
///
/// Unsupported device languages fall back to English.
Locale resolveAppLocale(Locale deviceLocale) {
  for (final supported in AppLocalizations.supportedLocales) {
    if (supported.languageCode == deviceLocale.languageCode) {
      return supported;
    }
  }
  return const Locale('en');
}
