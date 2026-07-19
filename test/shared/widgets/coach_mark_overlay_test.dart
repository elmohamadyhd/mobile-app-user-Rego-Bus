import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/shared/widgets/coach_mark_overlay.dart';

void main() {
  testWidgets('CoachMarkOverlay shows title and advances steps',
      (tester) async {
    final target1 = GlobalKey();
    final target2 = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: 80,
                left: 40,
                child: SizedBox(
                  key: target1,
                  width: 120,
                  height: 48,
                  child: const ColoredBox(color: AppColors.primary),
                ),
              ),
              Positioned(
                top: 200,
                left: 40,
                child: SizedBox(
                  key: target2,
                  width: 120,
                  height: 48,
                  child: const ColoredBox(color: AppColors.secondary),
                ),
              ),
              Positioned.fill(
                child: CoachMarkOverlay(
                  steps: [
                    CoachMarkStep(
                      targetKey: target1,
                      title: 'Step one',
                      body: 'First body',
                    ),
                    CoachMarkStep(
                      targetKey: target2,
                      title: 'Step two',
                      body: 'Second body',
                    ),
                  ],
                  skipLabel: 'Skip',
                  nextLabel: 'Next',
                  doneLabel: 'Done',
                  onComplete: () {},
                  onSkip: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Step one'), findsOneWidget);
    expect(find.text('First body'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Step two'), findsOneWidget);
    expect(find.text('Second body'), findsOneWidget);
  });
}
