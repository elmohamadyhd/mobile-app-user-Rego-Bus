import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/wallet/domain/entities/wallet.dart';
import 'package:rego/features/wallet/domain/repositories/wallet_repository.dart';

/// In-memory repository for widget/notifier tests.
class FakeWalletRepository implements WalletRepository {
  FakeWalletRepository({this.walletResult});

  Wallet? walletResult;
  bool getWalletShouldThrow = false;
  int getWalletCallCount = 0;

  List<int> chargeCalls = [];
  String chargeResult = 'https://demo.MyFatoorah.com/pay';
  bool chargeShouldThrow = false;

  static const sampleWallet = Wallet(
    id: 79,
    balance: 25.0,
    currency: 'EGP',
    transactions: [
      WalletTransaction(
        id: 86,
        description: 'Welcome bonus',
        type: WalletTransactionType.deposit,
        amount: 25.0,
      ),
    ],
  );

  @override
  Future<Wallet> getWallet() async {
    getWalletCallCount++;
    if (getWalletShouldThrow) {
      throw const ApiException('Failed to load wallet', statusCode: 500);
    }
    return walletResult ?? sampleWallet;
  }

  @override
  Future<String> charge(int amount) async {
    chargeCalls.add(amount);
    if (chargeShouldThrow) {
      throw const ApiException('Charge failed', statusCode: 422);
    }
    return chargeResult;
  }
}
