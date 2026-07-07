import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/features/auth/presentation/login_screen.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/l10n/app_localizations.dart';

void main() {
  Future<ProviderContainer> pumpLogin(
    WidgetTester tester, {
    required Map<String, String> guestModeMemory,
  }) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(memoryGuestModeStore: guestModeMemory),
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

  testWidgets('renders a "Continue as a guest" button below Sign in',
      (tester) async {
    await pumpLogin(tester, guestModeMemory: {});

    expect(find.text('Continue as a guest'), findsOneWidget);
  });

  testWidgets('tapping the guest button enables guest mode and goes Home',
      (tester) async {
    final memory = <String, String>{};
    final container = await pumpLogin(tester, guestModeMemory: memory);

    await tester.tap(find.text('Continue as a guest'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(container.read(guestModeProvider).value, isTrue);
    expect(memory['guest_mode'], 'true');
  });
}
