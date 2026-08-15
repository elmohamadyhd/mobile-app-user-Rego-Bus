import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/bus/presentation/widgets/new_trips_pill.dart';
import 'package:safaria/l10n/app_localizations.dart';

Future<void> _pumpPill(
  WidgetTester tester,
  int count, {
  VoidCallback? onTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: NewTripsPill(count: count, onTap: onTap ?? () {}),
      ),
    ),
  );
}

void main() {
  testWidgets('pluralises the count', (tester) async {
    await _pumpPill(tester, 1);
    expect(find.text('1 new trip'), findsOneWidget);

    await _pumpPill(tester, 3);
    expect(find.text('3 new trips'), findsOneWidget);
  });

  testWidgets('a zero count renders nothing', (tester) async {
    await _pumpPill(tester, 0);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('tapping fires the callback', (tester) async {
    var taps = 0;
    await _pumpPill(tester, 2, onTap: () => taps++);

    await tester.tap(find.text('2 new trips'));
    await tester.pump();

    expect(taps, 1);
  });
}
