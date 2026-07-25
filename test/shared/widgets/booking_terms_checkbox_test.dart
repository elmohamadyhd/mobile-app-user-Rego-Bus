import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/booking_terms_checkbox.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('toggles value via onChanged', (tester) async {
    var value = false;

    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return BookingTermsCheckbox(
              value: value,
              onChanged: (v) => setState(() => value = v),
              onOpenTerms: () {},
            );
          },
        ),
      ),
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(value, isTrue);
  });

  testWidgets('tapping terms link calls onOpenTerms', (tester) async {
    var opened = false;

    await tester.pumpWidget(
      _wrap(
        BookingTermsCheckbox(
          value: false,
          onChanged: (_) {},
          onOpenTerms: () => opened = true,
        ),
      ),
    );

    await tester.tap(find.text('Terms and Conditions'));
    await tester.pump();

    expect(opened, isTrue);
  });
}
