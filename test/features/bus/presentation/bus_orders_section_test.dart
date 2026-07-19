import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/features/auth/domain/entities/auth_session.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/widgets/bus_order_card.dart';
import 'package:rego/features/bus/presentation/widgets/bus_orders_section.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/providers/ticket_pdf_providers.dart';

import '../fake_bus_repository.dart';

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

BusOrder _order() => const BusOrder(
      orderId: '1475',
      bookingNumber: '000001475',
      operatorName: 'SuperJet',
      category: 'Five stars',
      statusText: 'Pending',
      statusKind: BusOrderStatusKind.pending,
      dateTimeLabel: '2026-07-30 08:45 AM',
      ticketLines: [BusTicketLine(id: 2076, seatNumber: '1', price: '205.00')],
      total: 'EGP 219.35',
      canCancel: true,
      cancelUrl: 'https://demo.safaria.travel/api/v1/buses/orders/1475/cancel',
      gatewayCheckoutUrl: 'https://demo.MyFatoorah.com/pay',
      invoiceUrl: 'https://portal.wdenytravel.com/orders/1475/invoice',
      fare: BusOrderFare(
        originalTicketsTotal: 'EGP 205.00',
        discount: 'EGP 0.00',
        walletDiscount: 'EGP 0.00',
        ticketsTotalAfterDiscount: 'EGP 205.00',
        paymentFees: 'EGP 14.35',
        total: 'EGP 219.35',
        currency: 'EGP',
      ),
    );

Future<void> _pumpSection(
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
        home: const Scaffold(body: BusOrdersSection()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('guest sees the sign-in card and no orders fetch',
      (tester) async {
    final repo = FakeBusRepository();
    await _pumpSection(tester, isGuest: true, repo: repo);

    expect(find.text('Sign in or create an account'), findsOneWidget);
    expect(repo.listOrdersCallCount, 0);
  });

  testWidgets('signed-in with orders renders a card per order',
      (tester) async {
    await _pumpSection(
      tester,
      isGuest: false,
      repo: FakeBusRepository(ordersResult: [_order()]),
    );

    expect(find.byType(BusOrderCard), findsOneWidget);
    expect(find.text('SuperJet'), findsOneWidget);
  });

  testWidgets('empty orders shows the empty state', (tester) async {
    await _pumpSection(
      tester,
      isGuest: false,
      repo: FakeBusRepository(ordersResult: const []),
    );

    expect(find.text('No tickets yet'), findsOneWidget);
    expect(find.text('Book a trip'), findsOneWidget);
  });

  testWidgets('repository failure shows the error state with retry',
      (tester) async {
    await _pumpSection(
      tester,
      isGuest: false,
      repo: FakeBusRepository()..listOrdersShouldThrow = true,
    );

    expect(find.text("Couldn't load your tickets"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('download invokes the in-app PDF downloader', (tester) async {
    var called = false;
    String? capturedUrl;
    String? capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(
            () => _FakeSessionController(const AuthSession(token: 't')),
          ),
          guestModeProvider.overrideWith(() => _FakeGuestController(false)),
          busRepositoryProvider.overrideWithValue(
            FakeBusRepository(ordersResult: [_order()]),
          ),
          ticketPdfDownloadProvider.overrideWith(
            (ref) => ({
              required String invoiceUrl,
              required String bookingRef,
            }) async {
              called = true;
              capturedUrl = invoiceUrl;
              capturedRef = bookingRef;
            },
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
          locale: const Locale('en'),
          home: const Scaffold(body: BusOrdersSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(
      capturedUrl,
      'https://portal.wdenytravel.com/orders/1475/invoice',
    );
    expect(capturedRef, '000001475');
  });
}
