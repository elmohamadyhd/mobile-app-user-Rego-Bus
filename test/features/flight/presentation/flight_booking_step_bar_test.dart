import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/features/flight/domain/entities/flight_wizard_step.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_booking_step_bar.dart';
import 'package:safaria/l10n/app_localizations.dart';

Future<void> _pump(
  WidgetTester tester, {
  required FlightWizardStep current,
  bool haveBundles = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: FlightBookingStepBar(
          current: current,
          haveBundles: haveBundles,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('review step shows icons for review, passengers, and pay',
      (tester) async {
    await _pump(tester, current: FlightWizardStep.review);

    expect(find.byIcon(PhosphorIconsLight.clipboardText), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.users), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.creditCard), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.package), findsNothing);
  });

  testWidgets('completed review step swaps to a check', (tester) async {
    await _pump(tester, current: FlightWizardStep.passengers);

    expect(find.byIcon(PhosphorIconsLight.check), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.clipboardText), findsNothing);
    expect(find.byIcon(PhosphorIconsLight.users), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.creditCard), findsOneWidget);
  });
}
