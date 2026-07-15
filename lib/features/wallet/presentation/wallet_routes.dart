import 'package:go_router/go_router.dart';

import 'package:rego/features/wallet/presentation/wallet_payment_webview_screen.dart';
import 'package:rego/features/wallet/presentation/wallet_screen.dart';
import 'package:rego/features/wallet/presentation/wallet_topup_screen.dart';

abstract final class WalletRoutes {
  static const wallet = '/profile/wallet';
  static const topUp = '/profile/wallet/top-up';
  static const pay = '/profile/wallet/pay';
}

List<RouteBase> walletRoutes() => [
      GoRoute(
        path: WalletRoutes.wallet,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: WalletRoutes.topUp,
        builder: (context, state) => const WalletTopUpScreen(),
      ),
      GoRoute(
        path: WalletRoutes.pay,
        builder: (context, state) {
          final url = state.extra;
          return WalletPaymentWebViewScreen(
            checkoutUrl: url is String ? url : '',
          );
        },
      ),
    ];
