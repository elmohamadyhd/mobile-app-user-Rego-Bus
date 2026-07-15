import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/features/wallet/domain/entities/wallet.dart';
import 'package:rego/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:rego/features/wallet/presentation/wallet_routes.dart';
import 'package:rego/features/wallet/presentation/wallet_screen.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../fake_wallet_repository.dart';

void main() {
  Future<void> pumpWallet(
    WidgetTester tester,
    FakeWalletRepository repo,
  ) async {
    final container = ProviderContainer(
      overrides: [walletRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: WalletRoutes.wallet,
      routes: [
        GoRoute(
          path: WalletRoutes.wallet,
          builder: (context, state) => const WalletScreen(),
        ),
        GoRoute(
          path: WalletRoutes.topUp,
          builder: (context, state) => const Text('TOPUP'),
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

  testWidgets('shows the balance and transaction list', (tester) async {
    await pumpWallet(tester, FakeWalletRepository());

    expect(find.text('25.00 EGP'), findsOneWidget);
    expect(find.text('Welcome bonus'), findsOneWidget);
    expect(find.text('+25.00'), findsOneWidget);
  });

  testWidgets('tapping Top up navigates to the top-up screen', (tester) async {
    await pumpWallet(tester, FakeWalletRepository());

    await tester.tap(find.text('Top up'));
    await tester.pumpAndSettle();

    expect(find.text('TOPUP'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no transactions',
      (tester) async {
    final repo = FakeWalletRepository(
      walletResult: const Wallet(
        id: 1,
        balance: 0,
        currency: 'EGP',
        transactions: [],
      ),
    );
    await pumpWallet(tester, repo);

    expect(find.text('No activity yet'), findsOneWidget);
  });

  testWidgets('shows an error state with retry on load failure',
      (tester) async {
    final repo = FakeWalletRepository()..getWalletShouldThrow = true;
    await pumpWallet(tester, repo);

    expect(find.text("Couldn't load your wallet"), findsOneWidget);

    repo.getWalletShouldThrow = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('25.00 EGP'), findsOneWidget);
  });
}
