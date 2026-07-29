import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/storage/secure_storage.dart';
import 'package:safaria/features/auth/domain/entities/auth_session.dart';
import 'package:safaria/features/auth/presentation/auth_flow_args.dart';
import 'package:safaria/features/auth/presentation/complete_phone_screen.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/in_memory_secure_storage.dart';

void main() {
  testWidgets(
      'submitting a valid phone sends an OTP and pushes the OTP screen with returnTo carried through',
      (tester) async {
    const session = AuthSession(token: 't');
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(storage: InMemorySecureStorage({})),
        ),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(session)),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: AppRoutes.completeProfile,
      routes: [
        GoRoute(
          path: AppRoutes.completeProfile,
          builder: (context, state) {
            final args = state.extra;
            return CompletePhoneScreen(
              args: args is CompleteProfileArgs ? args : null,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.otp,
          builder: (context, state) {
            final args = state.extra;
            if (args is! OtpArgs) return const SizedBox.shrink();
            return Text(
              'OTP purpose=${args.purpose.name} '
              'phone=${args.phoneCode}${args.mobile} '
              'returnTo=${args.returnTo}',
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
      AppRoutes.completeProfile,
      extra: const CompleteProfileArgs(returnTo: '/car/confirm'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1012345678');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'OTP purpose=linkGoogleAccountPhone phone=201012345678 '
        'returnTo=/car/confirm',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'shows a validation error for an invalid phone and does not navigate',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(storage: InMemorySecureStorage({})),
        ),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: AppRoutes.completeProfile,
      routes: [
        GoRoute(
          path: AppRoutes.completeProfile,
          builder: (context, state) => const CompletePhoneScreen(),
        ),
        GoRoute(
          path: AppRoutes.otp,
          builder: (context, state) => const Text('OTP'),
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

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid phone number'), findsOneWidget);
    expect(find.text('OTP'), findsNothing);
  });
}
