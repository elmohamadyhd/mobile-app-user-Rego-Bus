import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/car/domain/entities/car_order.dart';
import 'package:safaria/features/car/presentation/providers/car_booking_providers.dart';
import 'package:safaria/features/car/presentation/widgets/car_order_detail_sheet.dart';
import 'package:safaria/l10n/app_localizations.dart';

import '../../fake_car_repository.dart';

Future<void> _pumpSheet(
  WidgetTester tester, {
  required FakeCarRepository repo,
  CarOrder? seed,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [carRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showCarOrderDetailSheet(
                context,
                seed ?? FakeCarRepository.samplePendingOrder,
              ),
              child: const Text('Open sheet'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open sheet'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('paints company, route, vehicle, and price from seed',
      (tester) async {
    final repo = FakeCarRepository()..getOrderShouldThrow = true;
    await _pumpSheet(tester, repo: repo);

    expect(find.text('Sky Travel'), findsOneWidget);
    expect(find.text('Cairo'), findsOneWidget);
    expect(find.text('Alexandria'), findsOneWidget);
    expect(find.textContaining('Hundai'), findsOneWidget);
    expect(find.text('EGP 1000.00'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('tapping a location opens Maps confirm dialog', (tester) async {
    final repo = FakeCarRepository()..getOrderShouldThrow = true;
    await _pumpSheet(tester, repo: repo);

    await tester.tap(find.text('Cairo'));
    await tester.pumpAndSettle();

    expect(find.text('View Cairo on Google Maps?'), findsOneWidget);
    expect(find.text('Open Google Maps'), findsOneWidget);
  });

  testWidgets('keeps seed when refresh fails', (tester) async {
    final repo = FakeCarRepository()..getOrderShouldThrow = true;
    await _pumpSheet(tester, repo: repo);
    await tester.pumpAndSettle();

    expect(find.text('Sky Travel'), findsOneWidget);
    expect(find.text('EGP 1000.00'), findsOneWidget);
  });
}
