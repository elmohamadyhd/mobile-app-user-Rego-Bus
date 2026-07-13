import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/presentation/widgets/booking_app_bar.dart';

void main() {
  testWidgets('invokes onBack instead of popping when provided',
      (tester) async {
    var backTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: BookingAppBar(
          title: 'Title',
          onBack: () => backTapped = true,
        ),
      ),
    );

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    expect(backTapped, isTrue);
  });
}
