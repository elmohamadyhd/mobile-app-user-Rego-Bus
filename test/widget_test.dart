import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:rego/app.dart';
import 'package:rego/core/storage/secure_storage.dart';

void main() {
  setUpAll(() {
    // Load env from the checked-in example via the filesystem, so we don't
    // have to bundle .env.example as an app asset.
    dotenv.testLoad(fileInput: File('.env.example').readAsStringSync());
  });

  testWidgets('HomeScreen renders the brand title', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(
            SecureStorage(memoryLocaleStore: {}),
          ),
        ],
        child: const App(),
      ),
    );
    // Splash loading dots animate forever — one frame is enough to render.
    await tester.pump();
    expect(find.text('All journeys... one platform'), findsOneWidget);
    // Minimum splash duration before navigation.
    await tester.pump(const Duration(seconds: 2));
  });
}
