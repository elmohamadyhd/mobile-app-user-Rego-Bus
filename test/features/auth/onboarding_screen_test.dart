import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/features/auth/presentation/onboarding_screen.dart';
import 'package:rego/l10n/app_localizations.dart';

void main() {
  Future<ProviderContainer> pumpOnboarding(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(memoryLocaleStore: {}, memoryGuestModeStore: {}),
        ),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: AppRoutes.onboarding,
      routes: [
        GoRoute(
          path: AppRoutes.onboarding,
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const Text('LOGIN'),
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
    return container;
  }

  testWidgets('language button opens the language picker sheet',
      (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.byIcon(AppIcons.language));
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
  });
}
