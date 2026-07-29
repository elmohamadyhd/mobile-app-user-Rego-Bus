import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/core/theme/app_theme.dart';
import 'package:safaria/features/auth/presentation/widgets/auth_text_link.dart';
import 'package:safaria/l10n/app_localizations.dart';

void main() {
  testWidgets('AuthTextLink has at least 48px tap height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: AuthTextLink(label: 'Sign up', onTap: () {}),
        ),
      ),
    );

    final size = tester.getSize(find.byType(AuthTextLink));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('AuthTextLink invokes onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: AuthTextLink(
            label: 'Sign up',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Sign up'));
    expect(tapped, isTrue);
  });
}
