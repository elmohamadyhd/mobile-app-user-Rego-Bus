import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/app.dart';
import 'package:rego/core/storage/secure_storage.dart';

import '../../support/in_memory_secure_storage.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: File('.env.example').readAsStringSync());
  });

  testWidgets('signed-out, non-guest user is routed to Login', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(
            SecureStorage(
              storage: InMemorySecureStorage({'onboarding_seen': 'true'}),
              memoryLocaleStore: {},
              memoryGuestModeStore: {},
            ),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('guest-mode user is routed straight to Home', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(
            SecureStorage(
              storage: InMemorySecureStorage({'onboarding_seen': 'true'}),
              memoryLocaleStore: {},
              memoryGuestModeStore: {'guest_mode': 'true'},
            ),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Where to today?'), findsOneWidget);
  });
}
