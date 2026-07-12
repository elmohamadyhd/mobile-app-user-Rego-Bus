import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/providers/locale_controller.dart';
import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/language_picker_sheet.dart';

void main() {
  Future<ProviderContainer> pumpSheetHarness(WidgetTester tester) async {
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
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showLanguagePickerSheet(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('shows both languages with a check mark on the active one',
      (tester) async {
    await pumpSheetHarness(tester);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('العربية'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.byIcon(AppIcons.check), findsOneWidget);
  });

  testWidgets('tapping a language updates the locale and closes the sheet',
      (tester) async {
    final container = await pumpSheetHarness(tester);
    expect(container.read(localeControllerProvider).languageCode, 'en');

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    expect(find.text('العربية'), findsNothing);
    expect(container.read(localeControllerProvider).languageCode, 'ar');
  });
}
