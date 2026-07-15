import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/features/bus/domain/entities/bus_search_params.dart';
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/bus/presentation/eticket_screen.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../fake_bus_repository.dart';

BusTicket _confirmedTicket() {
  final trip = FakeBusRepository.sampleTrip;
  return BusTicket(
    bookingRef: '000001457',
    orderId: '42',
    trip: trip,
    fromStop: trip.defaultBoardingStop.copyWith(
      name: 'Sekka Club',
      arrivalAt: DateTime(2026, 7, 15, 5, 45),
    ),
    toStop: trip.defaultDropoffStop.copyWith(name: 'Moharam Bek'),
    seats: const ['23'],
    ticketLines: const [],
    total: 'EGP 148',
    currency: 'EGP',
    invoiceUrl: 'https://example.com/ticket.pdf',
    statusCode: 'confirmed',
    issuedAt: DateTime(2026, 7, 15),
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  final container = ProviderContainer(
    overrides: [
      busRepositoryProvider.overrideWithValue(
        FakeBusRepository(ticketResult: _confirmedTicket()),
      ),
    ],
  );
  addTearDown(container.dispose);

  final notifier = container.read(busBookingProvider.notifier);
  await notifier.searchTrips(
    BusSearchParams(cityFromId: 1, cityToId: 2, date: DateTime(2026, 7, 15)),
  );
  await notifier.selectTrip(FakeBusRepository.sampleTrip);
  notifier.toggleSeat('23');
  await notifier.confirmBooking();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: const BusTicketScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('shows operator, route, date, seats, and booking ref', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Booking confirmed!'), findsOneWidget);
    expect(find.text('Boarding pass'), findsOneWidget);
    expect(find.text('النورس للنقل البري'), findsWidgets);
    expect(find.text('Sekka Club'), findsOneWidget);
    expect(find.text('Moharam Bek'), findsOneWidget);
    expect(find.text('05:45'), findsOneWidget);
    expect(find.text('23'), findsOneWidget);
    expect(find.text('000001457'), findsWidgets);
    expect(find.text('EGP 148'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Back to home'), findsOneWidget);
  });

  testWidgets('renders in Arabic (RTL)', (tester) async {
    await _pump(tester, locale: const Locale('ar'));

    expect(find.text('تم تأكيد الحجز!'), findsOneWidget);
    expect(find.text('تذكرة صعود'), findsOneWidget);
    expect(find.text('العودة للرئيسية'), findsOneWidget);
  });

  testWidgets('back to home navigates home and clears booking state', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        busRepositoryProvider.overrideWithValue(
          FakeBusRepository(ticketResult: _confirmedTicket()),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(busBookingProvider.notifier);
    await notifier.searchTrips(
      BusSearchParams(cityFromId: 1, cityToId: 2, date: DateTime(2026, 7, 15)),
    );
    await notifier.selectTrip(FakeBusRepository.sampleTrip);
    notifier.toggleSeat('23');
    await notifier.confirmBooking();

    final router = GoRouter(
      initialLocation: BusRoutes.ticket,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const Scaffold(body: Text('HOME')),
        ),
        GoRoute(
          path: BusRoutes.ticket,
          builder: (context, state) => const BusTicketScreen(),
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

    expect(find.text('Booking confirmed!'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Back to home'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Back to home'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(container.read(busBookingProvider).ticket, isNull);
  });

  testWidgets(
    'hardware back from the ticket screen goes home, not to confirm underneath',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          busRepositoryProvider.overrideWithValue(
            FakeBusRepository(ticketResult: _confirmedTicket()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(busBookingProvider.notifier);
      await notifier.searchTrips(
        BusSearchParams(
          cityFromId: 1,
          cityToId: 2,
          date: DateTime(2026, 7, 15),
        ),
      );
      await notifier.selectTrip(FakeBusRepository.sampleTrip);
      notifier.toggleSeat('23');
      await notifier.confirmBooking();

      final router = GoRouter(
        initialLocation: AppRoutes.home,
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const Scaffold(body: Text('HOME')),
          ),
          GoRoute(
            path: '/confirm',
            builder: (context, state) => const Scaffold(body: Text('CONFIRM')),
          ),
          GoRoute(
            path: '/pay',
            builder: (context, state) => const Scaffold(body: Text('PAY')),
          ),
          GoRoute(
            path: BusRoutes.ticket,
            builder: (context, state) => const BusTicketScreen(),
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

      await router.push('/confirm');
      await tester.pumpAndSettle();
      await router.push('/pay');
      await tester.pumpAndSettle();
      await router.pushReplacement(BusRoutes.ticket);
      await tester.pumpAndSettle();

      expect(find.text('Booking confirmed!'), findsOneWidget);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('CONFIRM'), findsNothing);
      expect(container.read(busBookingProvider).ticket, isNull);
    },
  );
}
