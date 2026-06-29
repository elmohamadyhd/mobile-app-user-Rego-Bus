import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The active app locale. Arabic-first; switchable later from Settings.
///
/// Drives both `MaterialApp.locale` and the `Accept-Language` header attached
/// by the Dio auth interceptor.
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => const Locale('ar');

  void setLocale(Locale locale) => state = locale;

  void toggle() => state =
      state.languageCode == 'ar' ? const Locale('en') : const Locale('ar');
}

final localeControllerProvider =
    NotifierProvider<LocaleController, Locale>(LocaleController.new);
