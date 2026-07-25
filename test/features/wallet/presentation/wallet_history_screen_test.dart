import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/theme/app_theme.dart';
import 'package:safaria/features/wallet/domain/entities/wallet.dart';
import 'package:safaria/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:safaria/features/wallet/presentation/wallet_history_screen.dart';
import 'package:safaria/features/wallet/presentation/wallet_routes.dart';
import 'package:safaria/l10n/app_localizations.dart';

import '../fake_wallet_repository.dart';

void main() {
  Future<void> pumpHistory(
    WidgetTester tester,
    FakeWalletRepository repo,
  ) async {
    final container = ProviderContainer(
      overrides: [walletRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: WalletRoutes.history,
      routes: [
        GoRoute(
          path: WalletRoutes.history,
          builder: (context, state) => const WalletHistoryScreen(),
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

  testWidgets('shows the full transaction list', (tester) async {
    final transactions = List.generate(
      6,
      (i) => WalletTransaction(
        id: i,
        description: 'Transaction $i',
        type: WalletTransactionType.deposit,
        amount: 10,
      ),
    );
    final repo = FakeWalletRepository(
      walletResult: const Wallet(
        id: 1,
        balance: 60,
        currency: 'EGP',
        transactions: [],
      ).copyWith(transactions: transactions),
    );

    await pumpHistory(tester, repo);

    expect(find.text('Transaction history'), findsOneWidget);
    expect(find.text('Wallet top-up'), findsNWidgets(6));
  });
}
