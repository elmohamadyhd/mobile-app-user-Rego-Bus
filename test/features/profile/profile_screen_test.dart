import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/features/auth/domain/entities/auth_session.dart';
import 'package:rego/features/auth/domain/entities/auth_user.dart';
import 'package:rego/features/auth/presentation/auth_flow_args.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/profile/presentation/profile_screen.dart';
import 'package:rego/features/wallet/presentation/wallet_routes.dart';
import 'package:rego/l10n/app_localizations.dart';

class _FakeSessionController extends SessionController {
  _FakeSessionController(this._initial);

  final AuthSession? _initial;

  @override
  Future<AuthSession?> build() async => _initial;

  @override
  Future<void> logout() async {
    state = const AsyncData(null);
  }
}

class _FakeGuestController extends GuestController {
  _FakeGuestController(this._value);
  final bool _value;

  @override
  Future<bool> build() async => _value;
}

void main() {
  const session = AuthSession(
    token: 'test-token',
    user: AuthUser(
      name: 'Ahmed',
      mobile: '1012345678',
      phoneCode: '20',
    ),
  );

  Future<ProviderContainer> pumpProfile(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(
          () => _FakeSessionController(session),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
          locale: const Locale('en'),
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('shows user name and phone', (tester) async {
    await pumpProfile(tester);

    expect(find.text('Ahmed'), findsOneWidget);
    expect(find.text('+20 1012345678'), findsOneWidget);
    expect(find.text('My trips'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
  });

  testWidgets('logout shows confirmation dialog then signs out',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = await pumpProfile(tester);

    final logoutTile = find.text('Log out');
    await tester.ensureVisible(logoutTile);
    await tester.pumpAndSettle();

    await tester.tap(logoutTile);
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(container.read(sessionControllerProvider).value, isNull);
  });

  testWidgets(
      'guest sees a sign-in CTA instead of Log out, and it opens Login with returnTo',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(
          () => _FakeSessionController(null),
        ),
        guestModeProvider.overrideWith(() => _FakeGuestController(true)),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: AppRoutes.profile,
      routes: [
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) {
            final args = state.extra;
            return Text(
              args is AuthGateArgs
                  ? 'LOGIN returnTo=${args.returnTo}'
                  : 'LOGIN no gate args',
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log out'), findsNothing);
    final ctaLabel = find.text('Sign in or create an account');
    expect(ctaLabel, findsOneWidget);

    await tester.ensureVisible(ctaLabel);
    await tester.pumpAndSettle();
    await tester.tap(ctaLabel);
    await tester.pumpAndSettle();

    expect(find.text('LOGIN returnTo=${AppRoutes.profile}'), findsOneWidget);
  });

  testWidgets('tapping Language opens the language picker sheet',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpProfile(tester);

    final languageTile = find.text('Language');
    await tester.ensureVisible(languageTile);
    await tester.pumpAndSettle();
    await tester.tap(languageTile);
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
  });

  testWidgets('tapping Wallet pushes the wallet screen for a signed-in user',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(
          () => _FakeSessionController(session),
        ),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: AppRoutes.profile,
      routes: [
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: WalletRoutes.wallet,
          builder: (context, state) => const Text('WALLET'),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final walletTile = find.text('Wallet');
    await tester.ensureVisible(walletTile);
    await tester.pumpAndSettle();
    await tester.tap(walletTile);
    await tester.pumpAndSettle();

    expect(find.text('WALLET'), findsOneWidget);
  });

  testWidgets('tapping Wallet as a guest opens Login with returnTo the wallet',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(
          () => _FakeSessionController(null),
        ),
        guestModeProvider.overrideWith(() => _FakeGuestController(true)),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: AppRoutes.profile,
      routes: [
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) {
            final args = state.extra;
            return Text(
              args is AuthGateArgs
                  ? 'LOGIN returnTo=${args.returnTo}'
                  : 'LOGIN no gate args',
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final walletTile = find.text('Wallet');
    await tester.ensureVisible(walletTile);
    await tester.pumpAndSettle();
    await tester.tap(walletTile);
    await tester.pumpAndSettle();

    expect(
      find.text('LOGIN returnTo=${WalletRoutes.wallet}'),
      findsOneWidget,
    );
  });
}
