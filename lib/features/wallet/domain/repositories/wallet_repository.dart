import 'package:rego/features/wallet/domain/entities/wallet.dart';

abstract interface class WalletRepository {
  /// Fetches the signed-in rider's wallet balance and transaction history.
  Future<Wallet> getWallet();

  /// Starts a top-up charge for a whole-currency-unit [amount] — the amount
  /// is a URL path segment on the backend, so fractional values aren't
  /// accepted (enforced client-side in `WalletTopUpScreen`). Returns the
  /// hosted checkout URL to load in the payment WebView.
  Future<String> charge(int amount);
}
