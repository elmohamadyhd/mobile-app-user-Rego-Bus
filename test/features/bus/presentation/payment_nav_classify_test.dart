import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/presentation/payment_webview_screen.dart';

void main() {
  PaymentNavResult classify(String url) => classifyPaymentNav(Uri.parse(url));

  test('the success redirect is classified as success, regardless of locale',
      () {
    expect(
      classify('https://wdenytravel.com/ar/success-payment'),
      PaymentNavResult.success,
    );
    expect(
      classify('https://wdenytravel.com/en/success-payment'),
      PaymentNavResult.success,
    );
  });

  test('the failure redirect is classified as failure', () {
    expect(
      classify('https://wdenytravel.com/ar/failed-payment'),
      PaymentNavResult.failure,
    );
  });

  test('the gateway hosted-checkout page is still pending', () {
    expect(
      classify('https://demo.MyFatoorah.com/KWT/ia/01072695205842-dee51cf8'),
      PaymentNavResult.pending,
    );
    expect(
      classify('https://portal.wdenytravel.com/api/v1/buses/orders/1466/pay'),
      PaymentNavResult.pending,
    );
  });

  test('unrelated and blank navigations are pending', () {
    expect(classify('https://google.com'), PaymentNavResult.pending);
    expect(classify('about:blank'), PaymentNavResult.pending);
  });
}
