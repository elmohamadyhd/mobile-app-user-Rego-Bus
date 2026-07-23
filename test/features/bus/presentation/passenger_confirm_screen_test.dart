import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/domain/entities/bus_search_params.dart';
import 'package:rego/features/bus/presentation/passenger_confirm_screen.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/wallet/domain/entities/wallet.dart';
import 'package:rego/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

import '../../wallet/fake_wallet_repository.dart';
import '../fake_bus_repository.dart';

Future<ProviderContainer> _pumpConfirm(
  WidgetTester tester, {
  FakeBusRepository? busRepo,
  FakeWalletRepository? walletRepo,
  Locale locale = const Locale('en'),
}) async {
  final busRepository = busRepo ?? FakeBusRepository();
  final walletRepository = walletRepo ??
      FakeWalletRepository(
        walletResult: const Wallet(
          id: 1,
          balance: 500,
          currency: 'EGP',
          transactions: [],
        ),
      );

  final container = ProviderContainer(
    overrides: [
      busRepositoryProvider.overrideWithValue(busRepository),
      walletRepositoryProvider.overrideWithValue(walletRepository),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: const PassengerConfirmScreen(),
      ),
    ),
  );

  final notifier = container.read(busBookingProvider.notifier);
  await notifier.searchTrips(
    BusSearchParams(
      cityFromId: 1,
      cityToId: 2,
      date: DateTime(2026, 2, 10),
    ),
  );
  await notifier.selectTrip(FakeBusRepository.sampleTrip);
  notifier.toggleSeat('16');
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('shows the step bar and the full choice recap', (tester) async {
    await _pumpConfirm(tester);

    expect(find.text('Route'), findsOneWidget);
    expect(find.text('Seat'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);

    // Boarding default + terminal drop-off seeded by selectTrip.
    expect(find.text('القللي'), findsOneWidget);
    expect(find.text('ميامي'), findsOneWidget);
    // Selected seat chip.
    expect(find.text('16'), findsOneWidget);
    // Trip date recap.
    expect(find.text('Date'), findsOneWidget);
  });

  testWidgets('wallet tile is selectable and shows balance', (tester) async {
    await _pumpConfirm(tester);

    expect(find.text('500.00 EGP available'), findsOneWidget);

    await tester.ensureVisible(find.text('Wallet'));
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets(
      'allows confirm and shows partial-pay hint when wallet balance is insufficient',
      (tester) async {
    await _pumpConfirm(
      tester,
      walletRepo: FakeWalletRepository(
        walletResult: const Wallet(
          id: 1,
          balance: 25,
          currency: 'EGP',
          transactions: [],
        ),
      ),
    );

    await tester.ensureVisible(find.text('Wallet'));
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();

    expect(
      find.text('25.00 EGP from wallet; pay 150.00 EGP by card'),
      findsOneWidget,
    );
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('175 EGP'), findsNWidgets(2));
    expect(find.text('−25.00 EGP'), findsOneWidget);
    expect(find.text('Pay by card'), findsOneWidget);
    expect(find.text('150.00 EGP'), findsNWidgets(2));
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('card payment hides wallet rows in price breakdown',
      (tester) async {
    await _pumpConfirm(
      tester,
      walletRepo: FakeWalletRepository(
        walletResult: const Wallet(
          id: 1,
          balance: 25,
          currency: 'EGP',
          transactions: [],
        ),
      ),
    );

    expect(find.text('Subtotal'), findsNothing);
    expect(find.text('Pay by card'), findsNothing);
    expect(find.text('−25.00 EGP'), findsNothing);
  });

  testWidgets('shows partial-pay hint in Arabic', (tester) async {
    await _pumpConfirm(
      tester,
      locale: const Locale('ar'),
      walletRepo: FakeWalletRepository(
        walletResult: const Wallet(
          id: 1,
          balance: 25,
          currency: 'EGP',
          transactions: [],
        ),
      ),
    );

    await tester.ensureVisible(find.text('محفظة'));
    await tester.tap(find.text('محفظة'));
    await tester.pumpAndSettle();

    expect(
      find.text('25.00 EGP من المحفظة؛ ادفع 150.00 EGP بالبطاقة'),
      findsOneWidget,
    );
    expect(find.text('المجموع الفرعي'), findsOneWidget);
    expect(find.text('الدفع بالبطاقة'), findsOneWidget);
  });

  testWidgets('shows wallet balance in Arabic', (tester) async {
    await _pumpConfirm(tester, locale: const Locale('ar'));

    expect(find.text('500.00 EGP متاح'), findsOneWidget);
    expect(find.text('محفظة'), findsOneWidget);
  });
}
