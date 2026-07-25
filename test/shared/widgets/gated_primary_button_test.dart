import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/shared/widgets/gated_primary_button.dart';

void main() {
  testWidgets('calls onPressed when not gated', (tester) async {
    var pressed = false;
    var blocked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GatedPrimaryButton(
            label: 'Confirm',
            gated: false,
            onPressed: () => pressed = true,
            onGateBlocked: () => blocked = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Confirm'));
    await tester.pump();

    expect(pressed, isTrue);
    expect(blocked, isFalse);
  });

  testWidgets('calls onGateBlocked when gated', (tester) async {
    var pressed = false;
    var blocked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GatedPrimaryButton(
            label: 'Confirm',
            gated: true,
            onPressed: () => pressed = true,
            onGateBlocked: () => blocked = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Confirm'));
    await tester.pump();

    expect(pressed, isFalse);
    expect(blocked, isTrue);
  });

  testWidgets('does not call onGateBlocked while loading', (tester) async {
    var blocked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GatedPrimaryButton(
            label: 'Confirm',
            gated: true,
            loading: true,
            onPressed: () {},
            onGateBlocked: () => blocked = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(GatedPrimaryButton));
    await tester.pump();

    expect(blocked, isFalse);
  });
}
