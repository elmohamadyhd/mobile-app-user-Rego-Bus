import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/presentation/payment_webview_screen.dart';

void main() {
  const backendHost = 'portal.wdenytravel.com';

  PaymentNavPhase classify(String url) => classifyPaymentNav(
        Uri.parse(url),
        gatewayHostPart: 'myfatoorah',
        backendHost: backendHost,
      );

  test('the gateway invoice page is classified as atGateway', () {
    expect(
      classify('https://demo.MyFatoorah.com/KWT/ia/abc123'),
      PaymentNavPhase.atGateway,
    );
    expect(
      classify('https://sa.myfatoorah.com/pay/xyz'),
      PaymentNavPhase.atGateway,
    );
  });

  test('a return to the backend host is classified as returnedToBackend', () {
    expect(
      classify('https://portal.wdenytravel.com/api/v1/buses/orders/1454/pay'),
      PaymentNavPhase.returnedToBackend,
    );
  });

  test('an unrelated host is classified as other', () {
    expect(classify('https://google.com'), PaymentNavPhase.other);
    expect(classify('about:blank'), PaymentNavPhase.other);
  });
}
