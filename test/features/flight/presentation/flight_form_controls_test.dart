import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_form_controls.dart';

void main() {
  testWidgets('picker shows the hint until a value is chosen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.bgBase,
          body: FlightFormPicker(
            label: 'Nationality',
            hintText: 'Select',
            icon: PhosphorIconsLight.globe,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Nationality'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.globe), findsOneWidget);
  });

  testWidgets('picker shows the chosen value in primary text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlightFormPicker(
            label: 'Nationality',
            valueText: 'Egypt',
            hintText: 'Select',
            icon: PhosphorIconsLight.globe,
            onTap: () {},
          ),
        ),
      ),
    );

    final value = tester.widget<Text>(find.text('Egypt'));
    expect(value.style?.color, AppColors.textPrimary);
    expect(find.text('Select'), findsNothing);
  });
}
