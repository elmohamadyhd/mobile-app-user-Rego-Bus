import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/transport_mode_tab_bar.dart';

void main() {
  testWidgets('selected tab uses primary icon color', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: TransportModeTabBar(
            selectedIndex: TransportModeTabBar.privateTabIndex,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final privateTab = find.ancestor(
      of: find.text('Private'),
      matching: find.byType(InkWell),
    );
    final privateIcon = tester.widget<Icon>(
      find.descendant(
        of: privateTab,
        matching: find.byType(Icon),
      ),
    );
    expect(privateIcon.color, AppColors.primary);
  });
}
