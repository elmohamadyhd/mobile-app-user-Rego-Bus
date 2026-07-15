import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/wallet/presentation/wallet_payment_webview_screen.dart';
import 'package:rego/l10n/app_localizations.dart';

Widget _harness({
  required Locale locale,
  required ValueChanged<bool> onResult,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () async {
          final leave = await confirmLeaveWalletPayment(context);
          onResult(leave);
        },
        child: const Text('trigger'),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the leave-payment prompt with Stay and Leave',
      (tester) async {
    await tester.pumpWidget(
      _harness(locale: const Locale('en'), onResult: (_) {}),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.text('Leave payment?'), findsOneWidget);
    expect(find.text('Stay'), findsOneWidget);
    expect(find.text('Leave'), findsOneWidget);
  });

  testWidgets('Stay dismisses and reports the rider did not leave',
      (tester) async {
    bool? result;
    await tester.pumpWidget(
      _harness(locale: const Locale('en'), onResult: (v) => result = v),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('Leave reports the rider chose to leave', (tester) async {
    bool? result;
    await tester.pumpWidget(
      _harness(locale: const Locale('en'), onResult: (v) => result = v),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });
}
