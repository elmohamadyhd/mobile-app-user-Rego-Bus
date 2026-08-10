import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/providers/locale_controller.dart';
import 'package:safaria/core/storage/secure_storage.dart';
import 'package:safaria/core/theme/app_theme.dart';
import 'package:safaria/features/profile/presentation/settings_screen.dart';
import 'package:safaria/l10n/app_localizations.dart';

void main() {
  Future<ProviderContainer> pumpSettings(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(memoryLocaleStore: {}),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
          locale: locale,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  testWidgets('shows Settings title, Language row, and English trailing value',
      (tester) async {
    final container = await pumpSettings(tester);
    container
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('en'));
    await tester.pump();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.translate), findsOneWidget);
  });

  testWidgets('shows العربية trailing value when locale is Arabic',
      (tester) async {
    final container = await pumpSettings(
      tester,
      locale: const Locale('ar'),
    );
    container
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('ar'));
    await tester.pump();

    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('اللغة'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
  });

  testWidgets('tapping Language opens the language picker sheet',
      (tester) async {
    final container = await pumpSettings(tester);
    container
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('en'));
    await tester.pump();

    await tester.tap(find.text('Language'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('العربية'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.check), findsOneWidget);
  });

  testWidgets('picking Arabic updates the trailing value on Settings',
      (tester) async {
    final container = await pumpSettings(tester);
    container
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('en'));
    await tester.pump();
    expect(container.read(localeControllerProvider).languageCode, 'en');

    await tester.tap(find.text('Language'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('العربية'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(localeControllerProvider).languageCode, 'ar');
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
  });
}
