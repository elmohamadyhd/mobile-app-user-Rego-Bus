import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/features/auth/domain/entities/auth_session.dart';
import 'package:rego/features/auth/domain/entities/auth_user.dart';
import 'package:rego/features/auth/domain/value/otp_purpose.dart';
import 'package:rego/features/auth/presentation/auth_flow_args.dart';
import 'package:rego/features/auth/presentation/otp_verify_screen.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/in_memory_secure_storage.dart';

void main() {
  testWidgets(
      'verifying registration OTP with a returnTo navigates there and clears guest mode',
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
      initialLocation: AppRoutes.otp,
      routes: [
        GoRoute(
          path: AppRoutes.otp,
          builder: (context, state) => const OtpVerifyScreen(
            args: OtpArgs(
              phoneCode: '20',
              mobile: '1012345678',
              purpose: OtpPurpose.registration,
              returnTo: BusRoutes.confirm,
            ),
          ),
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

    await tester.enterText(find.byType(TextField).first, '1234');
    await tester.pumpAndSettle();

    expect(find.text('CONFIRM'), findsOneWidget);
    expect(container.read(guestModeProvider).value, isFalse);
  });
}
