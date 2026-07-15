import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:rego/features/wallet/presentation/wallet_routes.dart';
import 'package:rego/features/wallet/presentation/wallet_topup_screen.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

import '../fake_wallet_repository.dart';

void main() {
  Future<void> pumpTopUp(
    WidgetTester tester,
    FakeWalletRepository repo,
  ) async {
    final container = ProviderContainer(
      overrides: [walletRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: WalletRoutes.topUp,
      routes: [
        GoRoute(
          path: WalletRoutes.topUp,
          builder: (context, state) => const WalletTopUpScreen(),
        ),
        GoRoute(
          path: WalletRoutes.pay,
          builder: (context, state) => const Text('PAY'),
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
  }

  testWidgets('submit is disabled until an amount is entered', (tester) async {
    await pumpTopUp(tester, FakeWalletRepository());

    final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('tapping a quick-pick chip fills the amount and enables submit',
      (tester) async {
    await pumpTopUp(tester, FakeWalletRepository());

    await tester.tap(find.text('200 EGP'));
    await tester.pumpAndSettle();

    final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(button.onPressed, isNotNull);
    expect(find.text('Top up 200 EGP'), findsOneWidget);
  });

  testWidgets('submitting charges the repository and pushes the pay route',
      (tester) async {
    final repo = FakeWalletRepository()
      ..chargeResult = 'https://demo.MyFatoorah.com/pay/xyz';
    await pumpTopUp(tester, repo);

    await tester.tap(find.text('200 EGP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top up 200 EGP'));
    await tester.pumpAndSettle();

    expect(repo.chargeCalls, [200]);
    expect(find.text('PAY'), findsOneWidget);
  });

  testWidgets('a charge failure shows an inline error and keeps the amount',
      (tester) async {
    final repo = FakeWalletRepository()..chargeShouldThrow = true;
    await pumpTopUp(tester, repo);

    await tester.tap(find.text('200 EGP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top up 200 EGP'));
    await tester.pumpAndSettle();

    expect(find.text('Charge failed'), findsOneWidget);
    expect(find.text('Top up 200 EGP'), findsOneWidget);
  });

  testWidgets('only digits can be typed into the amount field',
      (tester) async {
    await pumpTopUp(tester, FakeWalletRepository());

    await tester.enterText(find.byType(TextField), 'abc123.45xyz');
    await tester.pumpAndSettle();

    expect(find.text('Top up 12345 EGP'), findsOneWidget);
  });
}
