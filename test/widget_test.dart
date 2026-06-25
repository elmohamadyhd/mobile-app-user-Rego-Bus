import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:app_skeleton/app.dart';

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: '.env.example');
  });

  testWidgets('HomeScreen renders', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();
    expect(find.text('Flutter Skeleton'), findsOneWidget);
  });
}
