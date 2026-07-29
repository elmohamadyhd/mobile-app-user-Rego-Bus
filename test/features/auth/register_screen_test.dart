import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/storage/secure_storage.dart';
import 'package:safaria/core/theme/app_theme.dart';
import 'package:safaria/features/auth/data/google_sign_in_service.dart';
import 'package:safaria/features/auth/domain/entities/auth_session.dart';
import 'package:safaria/features/auth/domain/entities/auth_user.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/auth/presentation/register_screen.dart';
import 'package:safaria/l10n/app_localizations.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/in_memory_secure_storage.dart';

class _FakeGoogleSignInService extends GoogleSignInService {
  _FakeGoogleSignInService(this._idToken);

  final String? _idToken;

  @override
  Future<String?> signIn() async => _idToken;
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'GOOGLE_WEB_CLIENT_ID=test-client-id');
  });

  testWidgets('Google sign-in for an existing, complete account navigates Home',
      (tester) async {
    const session = AuthSession(
      token: 'g-token',
      user: AuthUser(
        mobile: '1012345678',
        phoneCode: '20',
        isProfileCompleted: true,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(storage: InMemorySecureStorage({})),
        ),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(session)),
        googleSignInServiceProvider.overrideWithValue(
          _FakeGoogleSignInService('a-google-id-token'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(guestModeProvider.future);

    final router = GoRouter(
      initialLocation: AppRoutes.register,
      routes: [
        GoRoute(
          path: AppRoutes.register,
          builder: (context, state) => const RegisterScreen(),
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

    final google = find.byKey(const Key('googleSignInButton'));
    await tester.ensureVisible(google);
    await tester.pumpAndSettle();
    await tester.tap(google);
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
  });
}
