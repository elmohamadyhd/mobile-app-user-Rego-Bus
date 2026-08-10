import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/providers/locale_controller.dart';
import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/storage/secure_storage.dart';
import 'package:safaria/core/theme/app_theme.dart';
import 'package:safaria/features/auth/domain/entities/auth_session.dart';
import 'package:safaria/features/auth/domain/entities/auth_user.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/profile/domain/repositories/profile_repository.dart';
import 'package:safaria/features/profile/presentation/providers/profile_providers.dart';
import 'package:safaria/features/profile/presentation/settings_screen.dart';
import 'package:safaria/l10n/app_localizations.dart';

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

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository();

  var deleteCalls = 0;

  @override
  Future<void> deleteAccount() async {
    deleteCalls += 1;
  }

  @override
  Future<AuthUser> fetchProfile() => throw UnimplementedError();

  @override
  Future<AuthUser> updateProfile({
    required int id,
    required String name,
    required String email,
    required String phoneCode,
    required String mobile,
    String? avatarPath,
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> verifyAltPhone({
    required String phoneCode,
    required String mobile,
    required String code,
  }) =>
      throw UnimplementedError();
}

void main() {
  const signedIn = AuthSession(
    token: 'tok',
    user: AuthUser(
      name: 'Ahmed',
      mobile: '1012345678',
      phoneCode: '20',
    ),
  );

  Future<ProviderContainer> pumpSettings(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    AuthSession? session,
    bool isGuest = false,
    ProfileRepository? profileRepository,
  }) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(memoryLocaleStore: {}),
        ),
        sessionControllerProvider.overrideWith(
          () => _FakeSessionController(session),
        ),
        guestModeProvider.overrideWith(() => _FakeGuestController(isGuest)),
        if (profileRepository != null)
          profileRepositoryProvider.overrideWithValue(profileRepository),
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
          locale: locale,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  testWidgets('shows Settings title, Language row, and English trailing value',
      (tester) async {
    final container = await pumpSettings(tester);
    container
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('en'));
    await tester.pump();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.translate), findsOneWidget);
  });

  testWidgets('shows العربية trailing value when locale is Arabic',
      (tester) async {
    final container = await pumpSettings(
      tester,
      locale: const Locale('ar'),
    );
    container
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('ar'));
    await tester.pump();

    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('اللغة'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
  });

  testWidgets('tapping Language opens the language picker sheet',
      (tester) async {
    final container = await pumpSettings(tester);
    container
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('en'));
    await tester.pump();

    await tester.tap(find.text('Language'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('العربية'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.check), findsOneWidget);
  });

  testWidgets('picking Arabic updates the trailing value on Settings',
      (tester) async {
    final container = await pumpSettings(tester);
    container
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('en'));
    await tester.pump();
    expect(container.read(localeControllerProvider).languageCode, 'en');

    await tester.tap(find.text('Language'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('العربية'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(localeControllerProvider).languageCode, 'ar');
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
  });

  testWidgets('hides Delete account for guests', (tester) async {
    await pumpSettings(tester, isGuest: true, session: null);

    expect(find.text('Delete account'), findsNothing);
  });

  testWidgets('shows Delete account for signed-in users', (tester) async {
    await pumpSettings(tester, session: signedIn);

    expect(find.text('Delete account'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.trash), findsOneWidget);
  });

  testWidgets('Delete stays disabled until confirm word matches',
      (tester) async {
    await pumpSettings(tester, session: signedIn);

    await tester.tap(find.text('Delete account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final deleteAction = find.widgetWithText(TextButton, 'Delete');
    expect(tester.widget<TextButton>(deleteAction).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();

    expect(tester.widget<TextButton>(deleteAction).onPressed, isNotNull);
  });

  testWidgets('successful delete logs out and goes to login', (tester) async {
    final repo = _FakeProfileRepository();
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(memoryLocaleStore: {}),
        ),
        sessionControllerProvider.overrideWith(
          () => _FakeSessionController(signedIn),
        ),
        guestModeProvider.overrideWith(() => _FakeGuestController(false)),
        profileRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/settings-test',
      routes: [
        GoRoute(
          path: '/settings-test',
          builder: (_, __) => const SettingsScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, __) => const Text('LOGIN'),
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Delete account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.deleteCalls, 1);
    expect(container.read(sessionControllerProvider).value, isNull);
    expect(find.text('LOGIN'), findsOneWidget);
  });
}
