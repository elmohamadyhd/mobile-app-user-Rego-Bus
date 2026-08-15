import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/order_rated_badge.dart';

void main() {
  testWidgets('shows rated label with rating', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: OrderRatedBadge(rating: 4)),
      ),
    );
    expect(find.textContaining('4'), findsOneWidget);
  });
}
