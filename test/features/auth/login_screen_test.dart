import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/storage/secure_storage.dart';
import 'package:safaria/core/theme/app_theme.dart';
import 'package:safaria/features/auth/domain/entities/auth_session.dart';
import 'package:safaria/features/auth/domain/entities/auth_user.dart';
import 'package:safaria/features/auth/presentation/auth_flow_args.dart';
import 'package:safaria/features/auth/presentation/login_screen.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/bus/presentation/bus_routes.dart';
import 'package:safaria/l10n/app_localizations.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/in_memory_secure_storage.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

void main() {
  Future<ProviderContainer> pumpLogin(
    WidgetTester tester, {
    required Map<String, String> guestModeMemory,
  }) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(
            memoryGuestModeStore: guestModeMemory,
            memoryLocaleStore: {},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(guestModeProvider.future);

    final router = GoRouter(
      initialLocation: AppRoutes.login,
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const Text('HOME'),
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
    return container;
  }

  testWidgets('clears field errors when user edits after failed submit',
      (tester) async {
    await pumpLogin(tester, guestModeMemory: {});

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid phone number'), findsOneWidget);
    expect(find.text('This field is required'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '1012345678');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid phone number'), findsNothing);
    expect(find.text('This field is required'), findsNothing);
  });

  testWidgets('renders a "Continue as a guest" button below Sign in',
      (tester) async {
    await pumpLogin(tester, guestModeMemory: {});

    expect(find.text('Continue as a guest'), findsOneWidget);
  });

  testWidgets('Sign in CTA sits under Forgot password in the form card',
      (tester) async {
    await pumpLogin(tester, guestModeMemory: {});

    final forgotY = tester.getTopLeft(find.text('Forgot password?')).dy;
    final signInY = tester.getTopLeft(find.text('Sign in')).dy;
    final guestY = tester.getTopLeft(find.text('Continue as a guest')).dy;

    expect(signInY, greaterThan(forgotY));
    expect(guestY, greaterThan(signInY));
  });

  testWidgets('tapping the guest button enables guest mode and goes Home',
      (tester) async {
    final container = await pumpLogin(tester, guestModeMemory: {});

    final guest = find.text('Continue as a guest');
    await tester.ensureVisible(guest);
    await tester.pumpAndSettle();
    await tester.tap(guest);
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(container.read(guestModeProvider).value, isTrue);
  });

  testWidgets(
      'successful login with gateArgs navigates to returnTo and clears guest mode',
      (tester) async {
    const session = AuthSession(
      token: 't',
      user: AuthUser(mobile: '1012345678', phoneCode: '20'),
    );
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(storage: InMemorySecureStorage({})),
        ),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(session)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(guestModeProvider.future);
    await container.read(guestModeProvider.notifier).enable();

    final router = GoRouter(
      initialLocation: AppRoutes.login,
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) {
            final args = state.extra;
            return LoginScreen(gateArgs: args is AuthGateArgs ? args : null);
          },
        ),
        GoRoute(
          path: BusRoutes.confirm,
          builder: (context, state) => const Text('CONFIRM'),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const Text('HOME'),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    router.go(
      AppRoutes.login,
      extra: const AuthGateArgs(returnTo: BusRoutes.confirm),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '1012345678');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('CONFIRM'), findsOneWidget);
    expect(container.read(guestModeProvider).value, isFalse);
  });

  testWidgets('Sign up link forwards gateArgs to the register screen',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(storage: InMemorySecureStorage({})),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(guestModeProvider.future);

    final router = GoRouter(
      initialLocation: AppRoutes.login,
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) {
            final args = state.extra;
            return LoginScreen(gateArgs: args is AuthGateArgs ? args : null);
          },
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (context, state) {
            final args = state.extra;
            return Text(
              args is AuthGateArgs
                  ? 'REGISTER returnTo=${args.returnTo}'
                  : 'REGISTER no gate args',
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    router.go(
      AppRoutes.login,
      extra: const AuthGateArgs(returnTo: BusRoutes.confirm),
    );
    await tester.pumpAndSettle();

    final signUp = find.text('Sign up');
    await tester.ensureVisible(signUp);
    await tester.pumpAndSettle();
    await tester.tap(signUp);
    await tester.pumpAndSettle();

    expect(
      find.text('REGISTER returnTo=${BusRoutes.confirm}'),
      findsOneWidget,
    );
  });

  testWidgets('language button opens the language picker sheet',
      (tester) async {
    await pumpLogin(tester, guestModeMemory: {});

    await tester.tap(find.byIcon(PhosphorIconsLight.translate));
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
  });
}
