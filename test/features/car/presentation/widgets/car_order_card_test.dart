import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/car/presentation/widgets/car_order_card.dart';
import 'package:safaria/l10n/app_localizations.dart';

import '../../fake_car_repository.dart';

void main() {
  testWidgets('pending order shows company, route, and Pay', (tester) async {
    const order = FakeCarRepository.samplePendingOrder;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CarOrderCard(
              order: order,
              onPay: () {},
              onOpenVoucher: () {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sky Travel'), findsOneWidget);
    expect(find.text('Cairo → Alexandria'), findsOneWidget);
    expect(find.textContaining('1000.00'), findsOneWidget);
    expect(find.text('Complete payment'), findsOneWidget);
  });

  testWidgets('confirmed order shows View booking action', (tester) async {
    const order = FakeCarRepository.sampleConfirmedOrder;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CarOrderCard(
              order: order,
              onPay: () {},
              onOpenVoucher: () {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sky Travel'), findsOneWidget);
    expect(find.text('Complete payment'), findsNothing);
    expect(find.text('View booking'), findsOneWidget);
  });
}
