import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/features/auth/presentation/widgets/otp_input.dart';

void main() {
  testWidgets('keeps digit boxes LTR even when ambient direction is RTL',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: OtpInput(onChanged: _noop),
          ),
        ),
      ),
    );

    final fields = tester.getTopLeft;
    final first = fields(find.byType(TextField).at(0));
    final second = fields(find.byType(TextField).at(1));
    final third = fields(find.byType(TextField).at(2));
    final fourth = fields(find.byType(TextField).at(3));

    expect(first.dx, lessThan(second.dx));
    expect(second.dx, lessThan(third.dx));
    expect(third.dx, lessThan(fourth.dx));
  });

  testWidgets(
      'selects first box visually by default without focusing any field',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OtpInput(onChanged: _noop),
        ),
      ),
    );
    await tester.pump();

    final boxes = tester.widgetList<Container>(find.byType(Container)).where(
          (c) => c.decoration is BoxDecoration,
        );
    final decorations = boxes
        .map((c) => c.decoration! as BoxDecoration)
        .where((d) => d.border is Border)
        .toList();

    expect(decorations, isNotEmpty);
    final firstBorder = decorations.first.border! as Border;
    expect(firstBorder.top.color, AppColors.primary);

    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.focusNode?.hasFocus, isFalse);
    }
  });

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

void _noop(String _) {}
