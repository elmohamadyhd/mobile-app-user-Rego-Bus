import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/features/home/presentation/home_screen.dart';
import 'package:rego/features/shell/presentation/coming_soon_screen.dart';
import 'package:rego/features/shell/presentation/main_shell.dart';
import 'package:rego/features/shell/presentation/widgets/main_nav_bar.dart';
import 'package:rego/l10n/app_localizations.dart';

void main() {
  testWidgets('home fills the shell and the nav bar sits at the bottom', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532); // ~iPhone, 390x844 @3x
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    GoRoute soon(String path, String Function(AppLocalizations) label,
            IconData icon) =>
        GoRoute(
          path: path,
          builder: (context, _) => ComingSoonScreen(
            title: label(AppLocalizations.of(context)),
            icon: icon,
          ),
        );

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
              ],
            ),
            StatefulShellBranch(
              routes: [soon('/tickets', (l) => l.navTickets, AppIcons.ticket)],
            ),
            StatefulShellBranch(
              routes: [soon('/search', (l) => l.navSearch, AppIcons.search)],
            ),
            StatefulShellBranch(
              routes: [soon('/wallet', (l) => l.navWallet, AppIcons.wallet)],
            ),
            StatefulShellBranch(
              routes: [soon('/profile', (l) => l.navProfile, AppIcons.user)],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final screenH = tester.view.physicalSize.height / tester.view.devicePixelRatio;

    final homeSize = tester.getSize(find.byType(HomeScreen));
    final navTop = tester.getTopLeft(find.byType(MainNavBar)).dy;

    // ignore: avoid_print
    print('screenH=$screenH homeHeight=${homeSize.height} navTop=$navTop');

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(homeSize.height, greaterThan(screenH * 0.5),
        reason: 'home body should fill most of the screen');
    expect(navTop, greaterThan(screenH * 0.7),
        reason: 'nav bar should sit near the bottom');
  });
}
