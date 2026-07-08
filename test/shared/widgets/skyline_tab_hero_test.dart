import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/shell_tab_scroll_view.dart';
import 'package:rego/shared/widgets/skyline_tab_hero.dart';

void main() {
  Widget wrap(Widget child, {Locale locale = const Locale('en')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );
  }

  testWidgets('SkylineTabHero renders child text', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SkylineTabHero(
          reserveCardOverlap: false,
          child: Text('Hero content'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hero content'), findsOneWidget);
  });

  testWidgets('reserveCardOverlap adds extra height', (tester) async {
    Future<double> heroHeight({required bool reserveCardOverlap}) async {
      await tester.pumpWidget(
        wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkylineTabHero(
                reserveCardOverlap: reserveCardOverlap,
                child: const Text('Overlap'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getSize(find.byType(SkylineTabHero)).height;
    }

    final withOverlap = await heroHeight(reserveCardOverlap: true);
    final withoutOverlap = await heroHeight(reserveCardOverlap: false);

    expect(withOverlap, greaterThan(withoutOverlap));
  });

  testWidgets('SkylineTabGreetingRow renders under RTL locale', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SkylineTabHero(
          reserveCardOverlap: false,
          child: SkylineTabGreetingRow(
            initial: 'A',
            greeting: 'مرحباً',
            headline: 'إلى أين؟',
          ),
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مرحباً'), findsOneWidget);
    expect(find.text('إلى أين؟'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('مرحباً'))),
      TextDirection.rtl,
    );
  });

  testWidgets('ShellTabScrollView renders hero and overlapped child', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ShellTabScrollView(
          hero: SkylineTabHero(
            reserveCardOverlap: true,
            child: Text('Header'),
          ),
          children: [
            Text('Body card'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Header'), findsOneWidget);
    expect(find.text('Body card'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
