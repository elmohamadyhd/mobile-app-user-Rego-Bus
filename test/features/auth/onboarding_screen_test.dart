import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/providers/locale_controller.dart';
import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/storage/secure_storage.dart';
import 'package:safaria/features/auth/presentation/onboarding_screen.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

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
        child: Consumer(
          builder: (context, ref, _) {
            final locale = ref.watch(localeControllerProvider);
            return MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: locale,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('language button opens the language picker sheet',
      (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.byIcon(PhosphorIconsLight.translate));
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
  });

  testWidgets(
      'next caret uses locale language and ignores ambient RTL mirroring',
      (tester) async {
    final container = await pumpOnboarding(tester);

    expect(find.byIcon(PhosphorIconsLight.caretRight), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.caretLeft), findsNothing);

    container
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('ar'));
    await tester.pumpAndSettle();

    expect(find.byIcon(PhosphorIconsLight.caretLeft), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.caretRight), findsNothing);
    // LtrIcon keeps Phosphor's matchTextDirection from cancelling the swap.
    expect(
      Directionality.of(
        tester.element(find.byIcon(PhosphorIconsLight.caretLeft)),
      ),
      TextDirection.ltr,
    );
  });
}
