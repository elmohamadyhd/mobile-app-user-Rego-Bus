import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/app.dart';
import 'package:rego/core/storage/secure_storage.dart';

import '../../support/in_memory_secure_storage.dart';

// These tests render the full `App()` (splash -> router guard -> screen), so
// `SessionController.build()` runs for real. The real `FlutterSecureStorage`
// backend never resolves its platform-channel `read()` in this `flutter test`
// environment (it hangs rather than throwing), which would leave the splash
// screen's looping dots animation scheduling frames forever and time out
// `pumpAndSettle()`. `InMemorySecureStorage` avoids the platform channel
// entirely. It's seeded with `onboarding_seen: true` because
// `SecureStorage.onboardingSeen()` has no memory-store bypass of its own and
// would otherwise always read `false`, sending splash to Onboarding instead
// of Login/Home regardless of session or guest state.
void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: File('.env.example').readAsStringSync());
  });

  SecureStorage testStorage({Map<String, String>? legacyGuestFlag}) {
    final guestMemory = <String, String>{};
    if (legacyGuestFlag != null) {
      guestMemory.addAll(legacyGuestFlag);
    }
    return SecureStorage(
      storage: InMemorySecureStorage({'onboarding_seen': 'true'}),
      memoryLocaleStore: {},
      memoryGuestModeStore: guestMemory,
    );
  }

  Future<void> pumpApp(WidgetTester tester, SecureStorage storage) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  Future<void> continueAsGuest(WidgetTester tester) async {
    await tester.tap(find.text('Continue as a guest'));
    await tester.pumpAndSettle();
  }

  testWidgets('signed-out, non-guest user is routed to Login', (tester) async {
    await pumpApp(tester, testStorage());

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets(
    'legacy persisted guest flag does not restore guest session on cold start',
    (tester) async {
      await pumpApp(
        tester,
        testStorage(legacyGuestFlag: {'guest_mode': 'true'}),
      );

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Where to today?'), findsNothing);
    },
  );

  testWidgets('guest can browse Home during the current session', (tester) async {
    await pumpApp(tester, testStorage());
    expect(find.text('Welcome back'), findsOneWidget);

    await continueAsGuest(tester);

    expect(find.text('Where to today?'), findsOneWidget);
  });

  testWidgets(
    'guest tapping profile sign-in CTA opens Login instead of bouncing to Home',
    (tester) async {
      await pumpApp(tester, testStorage());
      await continueAsGuest(tester);

      expect(find.text('Where to today?'), findsOneWidget);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      final signInCta = find.text('Sign in or create an account');
      expect(signInCta, findsOneWidget);

      await tester.ensureVisible(signInCta);
      await tester.pumpAndSettle();
      await tester.tap(signInCta);
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Where to today?'), findsNothing);
    },
  );

  testWidgets(
    'guest login opened from profile shows exit snackbar on back, not Profile',
    (tester) async {
      await pumpApp(tester, testStorage());
      await continueAsGuest(tester);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      final signInCta = find.text('Sign in or create an account');
      await tester.ensureVisible(signInCta);
      await tester.pumpAndSettle();
      await tester.tap(signInCta);
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Guest'), findsNothing);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(find.text('Press back again to exit'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Guest'), findsNothing);
      expect(find.text('Where to today?'), findsNothing);
    },
  );
}
