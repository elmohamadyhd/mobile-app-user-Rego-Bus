import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_fare_row.dart';

void main() {
  testWidgets('formats the amount with the currency', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FlightFareRow(
            label: 'Taxes & fees',
            amount: 19205,
            currency: 'EGP',
          ),
        ),
      ),
    );

    expect(find.text('Taxes & fees'), findsOneWidget);
    expect(find.text('19205 EGP'), findsOneWidget);
    final amount = tester.widget<Text>(find.text('19205 EGP'));
    expect(amount.style?.color, AppColors.textPrimary);
  });
}
