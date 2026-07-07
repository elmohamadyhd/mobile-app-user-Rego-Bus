import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/auth/presentation/widgets/country_picker.dart';
import 'package:rego/features/auth/presentation/widgets/phone_field.dart';
import 'package:rego/l10n/app_localizations.dart';

void main() {
  testWidgets('keeps phone input LTR under Arabic locale', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: PhoneField(
              controller: controller,
              country: kDefaultCountry,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.textDirection, TextDirection.ltr);
    expect(textField.textAlign, TextAlign.start);

    final directionality = tester.widget<Directionality>(
      find.descendant(
        of: find.byType(PhoneField),
        matching: find.byType(Directionality),
      ),
    );
    expect(directionality.textDirection, TextDirection.ltr);

    addTearDown(controller.dispose);
  });
}
