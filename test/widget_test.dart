import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:rego/app.dart';

void main() {
  setUpAll(() {
    // Load env from the checked-in example via the filesystem, so we don't
    // have to bundle .env.example as an app asset.
    dotenv.testLoad(fileInput: File('.env.example').readAsStringSync());
  });

  testWidgets('HomeScreen renders the brand title', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();
    expect(find.text('REGO'), findsOneWidget);
  });
}
