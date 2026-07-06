import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/features/auth/domain/entities/auth_session.dart';
import 'package:rego/features/auth/domain/entities/auth_user.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/profile/presentation/profile_screen.dart';
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
}
