import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/wallet/domain/entities/wallet.dart';
import 'package:rego/features/wallet/presentation/providers/wallet_providers.dart';

import '../fake_wallet_repository.dart';

void main() {
  ProviderContainer makeContainer(FakeWalletRepository repo) {
    final container = ProviderContainer(
      overrides: [walletRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('WalletNotifier', () {
    test('build loads the wallet from the repository', () async {
      final repo = FakeWalletRepository();
      final container = makeContainer(repo);

      final wallet = await container.read(walletProvider.future);

      expect(wallet.id, 79);
      expect(wallet.balance, 25.0);
      expect(repo.getWalletCallCount, 1);
    });

    test('refresh re-fetches and replaces the wallet', () async {
      final repo = FakeWalletRepository();
      final container = makeContainer(repo);
      await container.read(walletProvider.future);

      repo.walletResult = const Wallet(
        id: 79,
        balance: 225.0,
        currency: 'EGP',
        transactions: [],
      );
      await container.read(walletProvider.notifier).refresh();

      final wallet = container.read(walletProvider).value;
      expect(wallet, isNotNull);
      expect(wallet!.balance, 225.0);
    });

    test('a load failure surfaces as an AsyncError', () async {
      final repo = FakeWalletRepository()..getWalletShouldThrow = true;
      final container = makeContainer(repo);

      final sub = container.listen(walletProvider, (_, __) {});
      addTearDown(sub.close);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(walletProvider).hasError, isTrue);
    });
  });
}
