import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/shared/widgets/ltr_icon.dart';

void main() {
  testWidgets('keeps check unmirrored under Arabic RTL shell', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: LtrIcon(PhosphorIconsLight.check),
          ),
        ),
      ),
    );

    expect(
      Directionality.of(
        tester.element(find.byIcon(PhosphorIconsLight.check)),
      ),
      TextDirection.ltr,
    );
  });
}
