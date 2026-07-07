import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/shared/widgets/ltr_text.dart';

void main() {
  testWidgets('renders text with LTR direction under Arabic RTL shell',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: LtrText('+20 101 234 5678'),
          ),
        ),
      ),
    );

    final directionality = tester.widget<Directionality>(
      find.descendant(
        of: find.byType(LtrText),
        matching: find.byType(Directionality),
      ),
    );
    expect(directionality.textDirection, TextDirection.ltr);
    expect(find.text('+20 101 234 5678'), findsOneWidget);
  });
}
