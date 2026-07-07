import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/double_back_to_exit.dart';

void main() {
  Future<void> pumpDoubleBack(
    WidgetTester tester, {
    VoidCallback? onSingleBack,
  }) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => DoubleBackToExit(
            onSingleBack: onSingleBack,
            child: const Scaffold(body: Text('ROOT')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('first back shows exit snackbar', (tester) async {
    await pumpDoubleBack(tester);

    final handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue);
    await tester.pumpAndSettle();

    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(find.text('ROOT'), findsOneWidget);
  });

  testWidgets('second back within window requests app exit', (tester) async {
    await pumpDoubleBack(tester);

    Object? popMessage;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') {
        popMessage = call.method;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Press back again to exit'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(popMessage, 'SystemNavigator.pop');
  });

  testWidgets('onSingleBack runs instead of exit snackbar', (tester) async {
    var singleBackCount = 0;
    await pumpDoubleBack(
      tester,
      onSingleBack: () => singleBackCount++,
    );

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(singleBackCount, 1);
    expect(find.text('Press back again to exit'), findsNothing);
  });

  testWidgets('alwaysIntercept blocks router pop and shows exit snackbar',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('UNDER')),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => DoubleBackToExit(
            alwaysIntercept: true,
            child: const Scaffold(body: Text('LOGIN')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.light(),
      ),
    );
    await tester.pumpAndSettle();

    router.push('/login');
    await tester.pumpAndSettle();
    expect(find.text('LOGIN'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('UNDER'), findsNothing);
  });
}
