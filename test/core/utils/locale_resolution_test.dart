import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/utils/locale_resolution.dart';

void main() {
  test('resolveAppLocale maps Arabic device locale to ar', () {
    expect(
      resolveAppLocale(const Locale('ar')).languageCode,
      'ar',
    );
  });

  test('resolveAppLocale maps English device locale to en', () {
    expect(
      resolveAppLocale(const Locale('en')).languageCode,
      'en',
    );
  });

  test('resolveAppLocale falls back to en for unsupported device locale', () {
    expect(
      resolveAppLocale(const Locale('fr')).languageCode,
      'en',
    );
  });
}
