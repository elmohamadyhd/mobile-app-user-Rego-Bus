import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/shared/widgets/route_arrow_label.dart';

void main() {
  testWidgets('keeps from before to with a mirroring caret', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: RouteArrowLabel(from: 'Cairo', to: 'Alexandria'),
          ),
        ),
      ),
    );

    expect(find.text('Cairo'), findsOneWidget);
    expect(find.text('Alexandria'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.caretRight), findsOneWidget);

    final fromX = tester.getTopLeft(find.text('Cairo')).dx;
    final toX = tester.getTopLeft(find.text('Alexandria')).dx;
    expect(fromX, lessThan(toX));
  });

  testWidgets('places from at start (right) in RTL', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(
              child: RouteArrowLabel(from: 'القاهره', to: 'الاسكندريه'),
            ),
          ),
        ),
      ),
    );

    final fromX = tester.getTopLeft(find.text('القاهره')).dx;
    final toX = tester.getTopLeft(find.text('الاسكندريه')).dx;
    // In RTL the first child (from) is on the right.
    expect(fromX, greaterThan(toX));
    expect(find.byIcon(PhosphorIconsLight.caretRight), findsOneWidget);
  });
}
