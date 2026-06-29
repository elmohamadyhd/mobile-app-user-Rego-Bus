import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/core/utils/locale_resolution.dart';

/// The active app locale. Follows the device language until the user picks one.
///
/// Drives both `MaterialApp.locale` and the `Accept-Language` header attached
/// by the Dio auth interceptor.
class LocaleController extends Notifier<Locale> {
  Locale? _userOverride;
  late Locale _deviceLocale;
  late final _LocaleObserver _observer;

  @override
  Locale build() {
    _deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;

    _observer = _LocaleObserver(_onDeviceLocaleChanged);
    WidgetsBinding.instance.addObserver(_observer);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(_observer);
    });

    Future<void>.microtask(_loadSavedOverride);

    return _effectiveLocale;
  }

  Locale get _effectiveLocale =>
      _userOverride ?? resolveAppLocale(_deviceLocale);

  void _onDeviceLocaleChanged() {
    _deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    if (_userOverride == null) {
      state = _effectiveLocale;
    }
  }

  Future<void> _loadSavedOverride() async {
    final saved = await ref.read(secureStorageProvider).readLocaleOverride();
    if (!ref.mounted) {
      return;
    }
    if (saved == null) {
      return;
    }
    _userOverride = Locale(saved);
    state = _effectiveLocale;
  }

  void setLocale(Locale locale) {
    _userOverride = locale;
    state = _effectiveLocale;
    ref.read(secureStorageProvider).writeLocaleOverride(locale.languageCode);
  }

  void useSystemLocale() {
    _userOverride = null;
    _deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    state = _effectiveLocale;
    ref.read(secureStorageProvider).clearLocaleOverride();
  }

  void toggle() {
    final next = state.languageCode == 'ar'
        ? const Locale('en')
        : const Locale('ar');
    setLocale(next);
  }
}

final localeControllerProvider =
    NotifierProvider<LocaleController, Locale>(LocaleController.new);

class _LocaleObserver with WidgetsBindingObserver {
  _LocaleObserver(this._onLocalesChanged);

  final VoidCallback _onLocalesChanged;

  @override
  void didChangeLocales(List<Locale>? locales) => _onLocalesChanged();
}
