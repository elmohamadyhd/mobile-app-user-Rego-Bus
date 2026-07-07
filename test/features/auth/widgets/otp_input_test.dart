import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/auth/presentation/widgets/otp_input.dart';

void main() {
  testWidgets('backspace on empty box moves to previous and clears it',
      (tester) async {
    var code = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OtpInput(
            onChanged: (v) => code = v,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), '1');
    await tester.enterText(find.byType(TextField).at(1), '2');
    await tester.pump();

    expect(code, '12');

    await tester.tap(find.byType(TextField).at(2));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(code, '1');
    expect(
      (find.byType(TextField).evaluate().elementAt(1).widget as TextField)
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('backspace on filled box moves focus to previous box',
      (tester) async {
    var code = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OtpInput(
            onChanged: (v) => code = v,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), '1');
    await tester.enterText(find.byType(TextField).at(1), '2');
    await tester.pump();

    await tester.tap(find.byType(TextField).at(1));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(code, '1');
  });
}
