import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/shared/widgets/primary_button.dart';

void main() {
  Future<void> pump(WidgetTester tester, PrimaryButtonVariant variant) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Continue as a guest',
            variant: variant,
            onPressed: () {},
          ),
        ),
      ),
    );
  }

  testWidgets(
      'ghost variant is transparent, bordered, and primary-colored text',
      (tester) async {
    await pump(tester, PrimaryButtonVariant.ghost);

    // Find the Material widget inside PrimaryButton (not Scaffold's Material)
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(PrimaryButton),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, Colors.transparent);

    // Find the Container inside InkWell
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(InkWell),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.border, isNotNull);

    final text = tester.widget<Text>(find.text('Continue as a guest'));
    expect(text.style?.color, AppColors.primary);
  });

  testWidgets('primary variant keeps the solid filled style', (tester) async {
    await pump(tester, PrimaryButtonVariant.primary);

    // Find the Material widget inside PrimaryButton (not Scaffold's Material)
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(PrimaryButton),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, AppColors.primary);

    final text = tester.widget<Text>(find.text('Continue as a guest'));
    expect(text.style?.color, AppColors.onPrimary);
  });
}
