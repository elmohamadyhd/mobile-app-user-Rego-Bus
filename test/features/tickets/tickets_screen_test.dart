import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/features/auth/domain/entities/auth_session.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/widgets/bus_order_card.dart';
import 'package:rego/features/tickets/presentation/tickets_screen.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../bus/fake_bus_repository.dart';

class _FakeSessionController extends SessionController {
  _FakeSessionController(this._initial);
  final AuthSession? _initial;
  @override
  Future<AuthSession?> build() async => _initial;
}

class _FakeGuestController extends GuestController {
  _FakeGuestController(this._value);
  final bool _value;
  @override
  Future<bool> build() async => _value;
}

BusOrder _pendingOrder() => const BusOrder(
      orderId: '1475',
      bookingNumber: '000001475',
      operatorName: 'SuperJet',
      category: 'Five stars',
      statusText: 'Pending',
      statusKind: BusOrderStatusKind.pending,
      dateTimeLabel: '2026-07-30 08:45 AM',
      seats: ['1'],
      total: 'EGP 219.35',
      canCancel: true,
      gatewayCheckoutUrl: 'https://demo.MyFatoorah.com/pay',
      invoiceUrl: 'https://portal.wdenytravel.com/orders/1475/invoice',
    );

Future<void> _pumpTickets(
  WidgetTester tester, {
  required bool isGuest,
  FakeBusRepository? repo,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(
          () => _FakeSessionController(
            isGuest ? null : const AuthSession(token: 't'),
          ),
        ),
        guestModeProvider.overrideWith(() => _FakeGuestController(isGuest)),
        busRepositoryProvider.overrideWithValue(repo ?? FakeBusRepository()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        locale: const Locale('en'),
        home: const TicketsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('guest sees sign-in CTA and no order cards', (tester) async {
    await _pumpTickets(tester, isGuest: true);

    expect(find.text('Sign in or create an account'), findsOneWidget);
    expect(find.byType(BusOrderCard), findsNothing);
  });

  testWidgets('signed-in rider sees their orders and a count in the hero',
      (tester) async {
    await _pumpTickets(
      tester,
      isGuest: false,
      repo: FakeBusRepository(ordersResult: [_pendingOrder()]),
    );

    expect(find.text('SuperJet'), findsOneWidget);
    expect(find.text('1 tickets'), findsOneWidget);
  });

  testWidgets('empty list shows the empty state with a Book a trip CTA',
      (tester) async {
    await _pumpTickets(
      tester,
      isGuest: false,
      repo: FakeBusRepository(ordersResult: const []),
    );

    expect(find.text('No tickets yet'), findsOneWidget);
    expect(find.text('Book a trip'), findsOneWidget);
  });
}
