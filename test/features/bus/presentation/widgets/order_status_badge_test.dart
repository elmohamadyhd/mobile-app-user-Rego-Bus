import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/presentation/widgets/order_status_badge.dart';
import 'package:rego/l10n/app_localizations.dart';

Future<void> _pumpBadge(
  WidgetTester tester,
  BusOrderStatusKind kind, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Scaffold(body: OrderStatusBadge(statusKind: kind)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the localized label for each status kind',
      (tester) async {
    await _pumpBadge(tester, BusOrderStatusKind.pending);
    expect(find.text('Pending'), findsOneWidget);

    await _pumpBadge(tester, BusOrderStatusKind.confirmed);
    expect(find.text('Confirmed'), findsOneWidget);

    await _pumpBadge(tester, BusOrderStatusKind.cancelled);
    expect(find.text('Cancelled'), findsOneWidget);

    await _pumpBadge(tester, BusOrderStatusKind.unknown);
    expect(find.text('Unknown'), findsOneWidget);
  });

  testWidgets('renders in Arabic', (tester) async {
    await _pumpBadge(
      tester,
      BusOrderStatusKind.pending,
      locale: const Locale('ar'),
    );
    expect(find.text('قيد الانتظار'), findsOneWidget);
  });
}
