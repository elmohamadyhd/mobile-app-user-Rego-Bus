import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/features/bus/domain/entities/bus_search_params.dart';
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/bus/presentation/payment_pending_screen.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../fake_bus_repository.dart';

BusTicket _pendingTicket() {
  final trip = FakeBusRepository.sampleTrip;
  return BusTicket(
    bookingRef: '000123',
    orderId: '42',
    trip: trip,
    fromStop: trip.defaultBoardingStop,
    toStop: trip.defaultDropoffStop,
    seats: const ['16'],
    ticketLines: const [],
    total: 'EGP 100',
    currency: 'EGP',
    paymentUrl: 'https://pay.example/1',
    statusCode: 'pending',
    issuedAt: DateTime(2026, 7, 10),
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  final container = ProviderContainer(
    overrides: [
      busRepositoryProvider.overrideWithValue(
        FakeBusRepository(ticketResult: _pendingTicket()),
      ),
    ],
  );
  addTearDown(container.dispose);

  // Drive the notifier so the pending order (with its ticket) is in state.
  final notifier = container.read(busBookingProvider.notifier);
  await notifier.searchTrips(
    BusSearchParams(cityFromId: 1, cityToId: 2, date: DateTime(2026, 7, 10)),
  );
  await notifier.selectTrip(FakeBusRepository.sampleTrip);
  notifier.toggleSeat('16');
  await notifier.confirmBooking();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: const PaymentPendingScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('shows the 15-minute hold message and both CTAs', (tester) async {
    await _pump(tester);

    expect(find.text('Pending payment'), findsOneWidget);
    expect(find.text('Payment pending'), findsOneWidget);
    expect(find.textContaining('15 minutes'), findsOneWidget);
    expect(find.text('Complete payment'), findsOneWidget);
    expect(find.text('Back to home'), findsOneWidget);
  });

  testWidgets('shows the booking reference from the pending order',
      (tester) async {
    await _pump(tester);

    expect(find.text('000123'), findsOneWidget);
  });

  testWidgets('renders in Arabic (RTL)', (tester) async {
    await _pump(tester, locale: const Locale('ar'));

    expect(find.text('بانتظار الدفع'), findsOneWidget);
    expect(find.text('في انتظار الدفع'), findsOneWidget);
    expect(find.text('أكمل الدفع'), findsOneWidget);
  });

  testWidgets(
      'hardware back from the pending screen goes home, not to the route underneath',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        busRepositoryProvider.overrideWithValue(
          FakeBusRepository(ticketResult: _pendingTicket()),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(busBookingProvider.notifier);
    await notifier.searchTrips(
      BusSearchParams(cityFromId: 1, cityToId: 2, date: DateTime(2026, 7, 10)),
    );
    await notifier.selectTrip(FakeBusRepository.sampleTrip);
    notifier.toggleSeat('16');
    await notifier.confirmBooking();

    final router = GoRouter(
      initialLocation: BusRoutes.pending,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const Scaffold(body: Text('HOME')),
        ),
        GoRoute(
          path: BusRoutes.confirm,
          builder: (context, state) => const Scaffold(body: Text('CONFIRM')),
        ),
        GoRoute(
          path: BusRoutes.pending,
          builder: (context, state) => const PaymentPendingScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pending payment'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    await tester.pump();

    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('CONFIRM'), findsNothing);
    expect(router.state.uri.path, AppRoutes.home);
    expect(container.read(busBookingProvider).ticket, isNull);
  });
}
