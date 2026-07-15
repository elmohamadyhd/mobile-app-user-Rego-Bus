import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/core/network/dio_client.dart';
import 'package:rego/features/wallet/data/wallet_api.dart';
import 'package:rego/features/wallet/data/wallet_repository_impl.dart';
import 'package:rego/features/wallet/domain/entities/wallet.dart';
import 'package:rego/features/wallet/domain/repositories/wallet_repository.dart';

final walletApiProvider =
    Provider<WalletApi>((ref) => WalletApi(ref.watch(dioProvider)));

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => WalletRepositoryImpl(ref.watch(walletApiProvider)),
);

/// Owns the signed-in rider's wallet (balance + transactions). Plain
/// (non-autoDispose) `AsyncNotifier`, matching `busOrdersProvider` — state
/// survives switching bottom-nav tabs and navigating to/from the wallet.
class WalletNotifier extends AsyncNotifier<Wallet> {
  @override
  Future<Wallet> build() {
    return ref.read(walletRepositoryProvider).getWallet();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(walletRepositoryProvider).getWallet(),
    );
  }
}

final walletProvider =
    AsyncNotifierProvider<WalletNotifier, Wallet>(WalletNotifier.new);
