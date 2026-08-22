import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/features/auth/domain/entities/auth_session.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/flight/domain/entities/flight_order.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_orders_section.dart';
import 'package:safaria/l10n/app_localizations.dart';

import '../fake_flight_repository.dart';

class _FakeSessionController extends SessionController {
  @override
  Future<AuthSession?> build() async => const AuthSession(token: 't');
}

class _FakeGuestController extends GuestController {
  @override
  Future<bool> build() async => false;
}

void main() {
  testWidgets('ticket card shows airport names, date chip, and fare',
      (tester) async {
    final repo = FakeFlightRepository();
    repo.ordersResult = [
      FlightOrder(
          id: '76',
          status: 'pending',
          orderStatus: 'PendingPayment',
          paymentStatus: 'pending',
          totalAmount: 37259,
          currency: 'EGP',
          checkoutUrl: 'https://pay.example/1',
          segments: [
            FlightOrderSegment(
              id: '1',
              origin: 'CAI',
              destination: 'RUH',
              departureDateTime: DateTime(2026, 8, 24, 15, 10),
              arrivalDateTime: DateTime(2026, 8, 24, 18, 5),
              marketingCarrierCode: 'XY',
              marketingFlightNumber: '264',
            ),
          ],
        ),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(_FakeSessionController.new),
          guestModeProvider.overrideWith(_FakeGuestController.new),
          flightRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: FlightOrdersSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cairo Intl Airport'), findsOneWidget);
    expect(find.text('King Khalid Intl Airport'), findsOneWidget);
    expect(find.text('CAI'), findsNothing);
    expect(find.text('RUH'), findsNothing);
    expect(find.byIcon(PhosphorIconsLight.calendarBlank), findsOneWidget);
    expect(find.textContaining('Aug 24'), findsOneWidget);
    expect(find.textContaining('15:10'), findsOneWidget);
    expect(find.textContaining('XY264'), findsOneWidget);
    expect(find.text('37259 EGP'), findsOneWidget);
  });
}
