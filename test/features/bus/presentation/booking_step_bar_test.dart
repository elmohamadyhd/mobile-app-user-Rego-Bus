import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/features/bus/presentation/widgets/booking_step_bar.dart';
import 'package:rego/l10n/app_localizations.dart';

Future<GoRouter> _pumpTwoScreenRouter(
  WidgetTester tester,
  BusBookingStep secondScreenStep,
) async {
  final router = GoRouter(
    initialLocation: '/first',
    routes: [
      GoRoute(
        path: '/first',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('first screen'))),
      ),
      GoRoute(
        path: '/second',
        builder: (context, state) => Scaffold(
          body: BookingStepBar(current: secondScreenStep),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
  return router;
}

void main() {
  testWidgets('renders all three step labels', (tester) async {
    final router = await _pumpTwoScreenRouter(tester, BusBookingStep.seat);
    unawaited(router.push('/second'));
    await tester.pumpAndSettle();

    expect(find.text('Route'), findsOneWidget);
    expect(find.text('Seat'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
  });

  testWidgets('tapping a completed step pops back to it', (tester) async {
    final router = await _pumpTwoScreenRouter(tester, BusBookingStep.seat);
    unawaited(router.push('/second'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Route'));
    await tester.pumpAndSettle();

    expect(find.text('first screen'), findsOneWidget);
  });

  testWidgets('upcoming step is not tappable', (tester) async {
    final router = await _pumpTwoScreenRouter(tester, BusBookingStep.route);
    unawaited(router.push('/second'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // Still on the second screen — nothing to pop back to for an upcoming step.
    expect(find.text('first screen'), findsNothing);
    expect(find.text('Confirm'), findsOneWidget);
  });
}
