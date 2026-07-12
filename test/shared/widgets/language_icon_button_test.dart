import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/language_icon_button.dart';

void main() {
  testWidgets('tapping the button opens the language picker sheet',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(body: LanguageIconButton()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(LanguageIconButton));
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
  });
}
