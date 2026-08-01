import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/features/car/presentation/widgets/car_trip_ticket_card.dart';
import 'package:safaria/l10n/app_localizations.dart';

import '../../fake_car_repository.dart';

void main() {
  testWidgets('shows company, locations, seats chip, fare, and Select',
      (tester) async {
    const quote = FakeCarRepository.sampleQuote;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: CarTripTicketCard(
            quote: quote,
            rounded: false,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Sky Travel'), findsOneWidget);
    expect(find.text('Cairo'), findsOneWidget);
    expect(find.text('Alexandria'), findsOneWidget);
    expect(find.textContaining('69.87'), findsOneWidget);
    expect(find.text('Refundable'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.users), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.briefcase), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.steeringWheel), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.caretRight), findsOneWidget);
  });

  testWidgets('tapping Select invokes onTap', (tester) async {
    var taps = 0;
    const quote = FakeCarRepository.sampleQuote;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: CarTripTicketCard(
            quote: quote,
            rounded: false,
            onTap: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Select'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('renders under Arabic locale', (tester) async {
    const quote = FakeCarRepository.sampleQuote;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        home: Scaffold(
          body: CarTripTicketCard(
            quote: quote,
            rounded: false,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Sky Travel'), findsOneWidget);
    expect(find.text('قابل للاسترداد'), findsOneWidget);
    expect(find.text('اختر'), findsOneWidget);
  });
}
