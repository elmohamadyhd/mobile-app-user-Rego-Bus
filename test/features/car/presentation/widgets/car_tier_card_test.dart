import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/features/car/presentation/widgets/car_tier_card.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../../fake_car_repository.dart';

void main() {
  testWidgets('shows company, price, seats chip, and selection mark',
      (tester) async {
    const quote = FakeCarRepository.sampleQuote;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: CarTierCard(
            quote: quote,
            rounded: false,
            selected: true,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Sky Travel'), findsOneWidget);
    expect(find.textContaining('69.87'), findsOneWidget);
    expect(find.textContaining('5'), findsWidgets);
    expect(find.text('Refundable'), findsOneWidget);
    expect(find.byIcon(AppIcons.check), findsOneWidget);
    expect(find.byIcon(AppIcons.seats), findsOneWidget);
    expect(find.byIcon(AppIcons.luggage), findsOneWidget);
    expect(find.byIcon(AppIcons.gear), findsOneWidget);
  });

  testWidgets('renders under Arabic locale', (tester) async {
    const quote = FakeCarRepository.sampleQuote;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        home: Scaffold(
          body: CarTierCard(
            quote: quote,
            rounded: false,
            selected: false,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Sky Travel'), findsOneWidget);
    expect(find.text('قابل للاسترداد'), findsOneWidget);
  });
}
