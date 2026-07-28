import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/features/profile/presentation/widgets/profile_circle_avatar.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/skyline_tab_hero.dart';

void main() {
  testWidgets('greeting shows initial when no avatarUrl', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: Scaffold(
          body: SkylineTabGreetingRow(
            initial: 'A',
            greeting: 'Hi, Abdallah',
            headline: 'Where to today?',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProfileCircleAvatar), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('bell badge is at least 10px', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: Scaffold(
          body: ColoredBox(
            color: AppColors.primary,
            child: SkylineTabHeroBellButton(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(SkylineTabHeroBellButton.badgeSize, greaterThanOrEqualTo(10));

    final badge = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color == AppColors.secondary,
    );
    expect(badge, findsOneWidget);
    final size = tester.getSize(badge);
    expect(size.width, greaterThanOrEqualTo(10));
    expect(size.height, greaterThanOrEqualTo(10));
  });
}
