import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:safaria/features/bus/presentation/widgets/trip_search_status_strip.dart';
import 'package:safaria/l10n/app_localizations.dart';

Future<void> _pumpStrip(
  WidgetTester tester,
  BusSearchPhase phase, {
  VoidCallback? onCheckForMore,
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: TripSearchStatusStrip(
          phase: phase,
          onCheckForMore: onCheckForMore ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('polling shows progress and the searching label', (tester) async {
    await _pumpStrip(tester, BusSearchPhase.polling);

    expect(find.text('Looking for more trips…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('complete collapses to nothing', (tester) async {
    await _pumpStrip(tester, BusSearchPhase.complete);

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('idle collapses to nothing', (tester) async {
    await _pumpStrip(tester, BusSearchPhase.idle);

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('exhausted offers a refresh that fires the callback',
      (tester) async {
    var taps = 0;
    await _pumpStrip(
      tester,
      BusSearchPhase.exhausted,
      onCheckForMore: () => taps++,
    );

    expect(find.text('Some operators are still responding slowly'),
        findsOneWidget);
    await tester.tap(find.text('Check for more'));
    await tester.pump();

    expect(taps, 1);
  });
}
