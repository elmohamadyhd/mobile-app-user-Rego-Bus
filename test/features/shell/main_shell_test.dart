import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/features/shell/presentation/main_shell.dart';
import 'package:rego/l10n/app_localizations.dart';

void main() {
  GoRouter buildRouter() {
    GoRoute branch(String path) => GoRoute(
          path: path,
          builder: (_, __) => const SizedBox.shrink(),
        );

    return GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(routes: [branch('/')]),
            StatefulShellBranch(routes: [branch('/tickets')]),
            StatefulShellBranch(routes: [branch('/wallet')]),
            StatefulShellBranch(routes: [branch('/profile')]),
          ],
        ),
      ],
    );
  }

  Future<void> pumpShell(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
      ),
    );
    await tester.pumpAndSettle();
  }

  String currentLocation(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  testWidgets('starts on the home branch', (tester) async {
    final router = buildRouter();
    await pumpShell(tester, router);

    expect(currentLocation(router), '/');
  });

  testWidgets('tapping a tab switches to its branch', (tester) async {
    final router = buildRouter();
    await pumpShell(tester, router);

    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    expect(currentLocation(router), '/wallet');

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(currentLocation(router), '/profile');

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(currentLocation(router), '/');
  });

  testWidgets('back on a non-home tab switches to Home', (tester) async {
    final router = buildRouter();
    await pumpShell(tester, router);

    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    expect(currentLocation(router), '/wallet');

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(currentLocation(router), '/');
  });

  testWidgets('double back on Home shows exit snackbar', (tester) async {
    final router = buildRouter();
    await pumpShell(tester, router);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(currentLocation(router), '/');
  });
}
