import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/wallet/presentation/wallet_payment_webview_screen.dart';

void main() {
  WalletPaymentNavResult classify(String url) =>
      classifyWalletPaymentNav(Uri.parse(url));

  test('the success redirect is classified as success, regardless of locale',
      () {
    expect(
      classify('https://wdenytravel.com/ar/success-payment'),
      WalletPaymentNavResult.success,
    );
    expect(
      classify('https://wdenytravel.com/en/success-payment'),
      WalletPaymentNavResult.success,
    );
  });

  test('the failure redirect is classified as failure', () {
    expect(
      classify('https://wdenytravel.com/ar/failed-payment'),
      WalletPaymentNavResult.failure,
    );
  });

  test('the gateway hosted-checkout page is still pending', () {
    expect(
      classify('https://demo.MyFatoorah.com/KWT/ia/01072695205842-dee51cf8'),
      WalletPaymentNavResult.pending,
    );
  });

  test('unrelated and blank navigations are pending', () {
    expect(classify('https://google.com'), WalletPaymentNavResult.pending);
    expect(classify('about:blank'), WalletPaymentNavResult.pending);
  });
}
