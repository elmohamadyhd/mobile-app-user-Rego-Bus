import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/features/auth/presentation/auth_flow_args.dart';
import 'package:rego/features/auth/presentation/widgets/guest_gate_sheet.dart';
import 'package:rego/l10n/app_localizations.dart';

void main() {
  Future<GoRouter> pumpWithGate(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.tripConfirm,
      routes: [
        GoRoute(
          path: AppRoutes.tripConfirm,
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    showGuestGate(context, returnTo: AppRoutes.tripConfirm),
                child: const Text('Confirm & pay'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) {
            final args = state.extra;
            return Scaffold(
              body: Text(
                args is AuthGateArgs
                    ? 'LOGIN returnTo=${args.returnTo}'
                    : 'LOGIN no gate args',
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (context, state) {
            final args = state.extra;
            return Scaffold(
              body: Text(
                args is AuthGateArgs
                    ? 'REGISTER returnTo=${args.returnTo}'
                    : 'REGISTER no gate args',
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('shows title, body, and reassurance copy', (tester) async {
    await pumpWithGate(tester);

    await tester.tap(find.text('Confirm & pay'));
    await tester.pumpAndSettle();

    expect(find.text('One step before payment'), findsOneWidget);
    expect(
      find.text(
        'Sign in or create an account to confirm your booking and pay securely.',
      ),
      findsOneWidget,
    );
    expect(
      find.text("Your booking is saved — you won't lose your seats"),
      findsOneWidget,
    );
  });

  testWidgets('Sign in pushes login with AuthGateArgs(returnTo)',
      (tester) async {
    await pumpWithGate(tester);

    await tester.tap(find.text('Confirm & pay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(
        find.text('LOGIN returnTo=${AppRoutes.tripConfirm}'), findsOneWidget);
  });

  testWidgets('Create account pushes register with AuthGateArgs(returnTo)',
      (tester) async {
    await pumpWithGate(tester);

    await tester.tap(find.text('Confirm & pay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(
      find.text('REGISTER returnTo=${AppRoutes.tripConfirm}'),
      findsOneWidget,
    );
  });
}
