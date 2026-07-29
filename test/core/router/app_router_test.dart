import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/app.dart';
import 'package:safaria/core/storage/secure_storage.dart';

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
    // Taller than the default 800×600 so the Login guest CTA is on-screen,
    // without shrinking width (phone widths overflow the login footer Row).
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    // Cover intro (1s) + min splash duration (2s). A second concurrent
    // `_route` (session listen + post-frame) can leave a stray delay timer —
    // advance past that too before asserting.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> continueAsGuest(WidgetTester tester) async {
    final guest = find.text('Continue as a guest');
    await tester.ensureVisible(guest);
    await tester.pumpAndSettle();
    await tester.tap(guest);
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

  testWidgets('guest can browse Home during the current session',
      (tester) async {
    await pumpApp(tester, testStorage());
    expect(find.text('Welcome back'), findsOneWidget);

    await continueAsGuest(tester);

    expect(find.text('Where to today?'), findsOneWidget);
  });

  testWidgets(
    'guest can open the Tickets tab and sees a sign-in CTA, not a crash',
    (tester) async {
      await pumpApp(tester, testStorage());
      await continueAsGuest(tester);

      await tester.tap(find.text('Tickets'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in or create an account'), findsOneWidget);
    },
  );

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

  testWidgets(
    'signed-in user with an incomplete profile is routed to Complete profile, not Home',
    (tester) async {
      final storage = testStorage();
      await storage.writeToken('a-token');
      await storage.writeUser(jsonEncode({
        'id': 1,
        'name': 'Abdallah',
        'email': 'abdallah@gmail.com',
        'mobile': null,
        'phonecode': null,
        'status': 'Active',
        'avatar': '',
        'is_profile_completed': false,
      }));

      await pumpApp(tester, storage);

      expect(find.text('Complete your profile'), findsOneWidget);
      expect(find.text('Where to today?'), findsNothing);
    },
  );
}
