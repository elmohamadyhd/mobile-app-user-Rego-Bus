import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/car/presentation/widgets/car_ticket_shell.dart';

void main() {
  testWidgets('CarTicketBorder paints as Material shape without throw',
      (tester) async {
    await tester.pumpWidget(
    const MaterialApp(
        home: Scaffold(
          body: Material(
            color: Colors.white,
            shape:  CarTicketBorder(
              radius: 20,
              notchRadius: 10,
              notchOffsetFromBottom: 60,
            ),
            clipBehavior: Clip.antiAlias,
            child:  SizedBox(height: 160, width: 320),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
