# Continue as a Guest — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user enter the REGO app as a guest from the login screen, browse everything freely, and hit a bottom-sheet sign-in wall only at the confirm-&-pay step; resume the same booking after they authenticate.

**Architecture:** Guest mode is a second, independently-persisted boolean (`guestModeProvider`, mirroring the existing `sessionControllerProvider`), not a change to `AuthSession`. The router guard and splash screen treat "logged in OR guest" as "allowed in the app." A reusable bottom-sheet helper (`showGuestGate`) gates the pay button and threads a `returnTo` route through login/register/OTP so a successful sign-in lands back on the in-progress booking, which survives because `bookingFlowProvider` is never disposed.

**Tech Stack:** Flutter, Riverpod (`AsyncNotifier`), go_router, `flutter_secure_storage` (via the existing `SecureStorage` wrapper), ARB localization (ar/en).

**Spec:** [docs/superpowers/specs/2026-07-06-continue-as-guest-design.md](../specs/2026-07-06-continue-as-guest-design.md)

---

## Before you start

Run these once, from the repo root, to confirm the baseline is green:

```bash
flutter pub get
flutter analyze
flutter test
```

All three must succeed before Task 1. If `flutter analyze` or `flutter test` fail on a clean checkout, stop and report — don't build on a broken baseline.

---

### Task 1: `SecureStorage` — persist the guest-mode flag

**Files:**
- Modify: `lib/core/storage/secure_storage.dart`
- Test: `test/core/storage/secure_storage_test.dart`

- [ ] **Step 1: Write the failing tests**

Append to `test/core/storage/secure_storage_test.dart` (inside `main()`, after the existing `readOrCreateDeviceToken` tests, before the closing `}`):

```dart
  group('guest mode', () {
    test('isGuestMode is false when nothing is stored', () async {
      final storage = SecureStorage(memoryGuestModeStore: {});
      expect(await storage.isGuestMode(), isFalse);
    });

    test('setGuestMode persists true and isGuestMode reads it back',
        () async {
      final memoryStore = <String, String>{};
      final storage = SecureStorage(memoryGuestModeStore: memoryStore);

      await storage.setGuestMode();

      expect(await storage.isGuestMode(), isTrue);
      expect(memoryStore['guest_mode'], 'true');
    });

    test('clearGuestMode removes the flag', () async {
      final memoryStore = <String, String>{'guest_mode': 'true'};
      final storage = SecureStorage(memoryGuestModeStore: memoryStore);

      await storage.clearGuestMode();

      expect(await storage.isGuestMode(), isFalse);
      expect(memoryStore.containsKey('guest_mode'), isFalse);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/storage/secure_storage_test.dart`
Expected: FAIL — `memoryGuestModeStore` is not a named parameter of `SecureStorage`, and `isGuestMode`/`setGuestMode`/`clearGuestMode` are undefined.

- [ ] **Step 3: Implement in `SecureStorage`**

In `lib/core/storage/secure_storage.dart`, update the constructor and fields (replace lines 11–25):

```dart
class SecureStorage {
  SecureStorage({
    FlutterSecureStorage? storage,
    Map<String, String>? memoryLocaleStore,
    Map<String, String>? memoryDeviceTokenStore,
    Map<String, String>? memoryGuestModeStore,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _memoryLocaleStore = memoryLocaleStore,
        _memoryDeviceTokenStore = memoryDeviceTokenStore,
        _memoryGuestModeStore = memoryGuestModeStore;

  final FlutterSecureStorage _storage;
  final Map<String, String>? _memoryLocaleStore;
  final Map<String, String>? _memoryDeviceTokenStore;
  final Map<String, String>? _memoryGuestModeStore;

  static const _kToken = 'auth_token';
  static const _kUser = 'auth_user';
  static const _kOnboardingSeen = 'onboarding_seen';
  static const _kLocaleOverride = 'locale_override';
  static const _kDeviceToken = 'device_token';
  static const _kGuestMode = 'guest_mode';
```

Add these methods at the end of the class, right before the closing `}` of `SecureStorage` (after `readOrCreateDeviceToken`):

```dart

  /// Whether the current install is browsing without an account.
  Future<bool> isGuestMode() async {
    if (_memoryGuestModeStore != null) {
      return _memoryGuestModeStore[_kGuestMode] == 'true';
    }
    return (await _storage.read(key: _kGuestMode)) == 'true';
  }

  Future<void> setGuestMode() async {
    if (_memoryGuestModeStore != null) {
      _memoryGuestModeStore[_kGuestMode] = 'true';
      return;
    }
    await _storage.write(key: _kGuestMode, value: 'true');
  }

  Future<void> clearGuestMode() async {
    if (_memoryGuestModeStore != null) {
      _memoryGuestModeStore.remove(_kGuestMode);
      return;
    }
    await _storage.delete(key: _kGuestMode);
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/storage/secure_storage_test.dart`
Expected: PASS (all tests in the file, including the 3 new ones)

- [ ] **Step 5: Commit**

```bash
git add lib/core/storage/secure_storage.dart test/core/storage/secure_storage_test.dart
git commit -m "feat(storage): persist a guest-mode flag"
```

---

### Task 2: `GuestController` + `guestModeProvider`

**Files:**
- Modify: `lib/features/auth/presentation/providers/auth_providers.dart`
- Test: `test/features/auth/providers/guest_controller_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `test/features/auth/providers/guest_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';

void main() {
  ProviderContainer makeContainer(Map<String, String> memoryGuestModeStore) {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(memoryGuestModeStore: memoryGuestModeStore),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('build restores false when no guest flag is stored', () async {
    final container = makeContainer({});
    expect(await container.read(guestModeProvider.future), isFalse);
  });

  test('build restores true when a guest flag is already persisted',
      () async {
    final container = makeContainer({'guest_mode': 'true'});
    expect(await container.read(guestModeProvider.future), isTrue);
  });

  test('enable persists true and flips state', () async {
    final memory = <String, String>{};
    final container = makeContainer(memory);
    await container.read(guestModeProvider.future);

    await container.read(guestModeProvider.notifier).enable();

    expect(container.read(guestModeProvider).value, isTrue);
    expect(memory['guest_mode'], 'true');
  });

  test('disable clears the persisted flag and flips state', () async {
    final memory = <String, String>{'guest_mode': 'true'};
    final container = makeContainer(memory);
    await container.read(guestModeProvider.future);

    await container.read(guestModeProvider.notifier).disable();

    expect(container.read(guestModeProvider).value, isFalse);
    expect(memory.containsKey('guest_mode'), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/providers/guest_controller_test.dart`
Expected: FAIL — `guestModeProvider` is undefined.

- [ ] **Step 3: Implement `GuestController` and `guestModeProvider`**

In `lib/features/auth/presentation/providers/auth_providers.dart`, add after the closing `}` of `SessionController` and before the `sessionControllerProvider` declaration (i.e. insert between the current lines 57 and 59):

```dart

/// Tracks whether the current install is browsing without an account.
/// Independent of [SessionController] — a token always means a real
/// authenticated session; this is a separate, best-effort persisted flag.
class GuestController extends AsyncNotifier<bool> {
  SecureStorage get _storage => ref.read(secureStorageProvider);

  @override
  Future<bool> build() => _storage.isGuestMode();

  Future<void> enable() async {
    await _storage.setGuestMode();
    state = const AsyncData(true);
  }

  Future<void> disable() async {
    await _storage.clearGuestMode();
    state = const AsyncData(false);
  }
}

final guestModeProvider = AsyncNotifierProvider<GuestController, bool>(
  GuestController.new,
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/providers/guest_controller_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/presentation/providers/auth_providers.dart test/features/auth/providers/guest_controller_test.dart
git commit -m "feat(auth): add GuestController for persisted guest-mode state"
```

---

### Task 3: `SessionController.logout()` also clears guest mode

**Files:**
- Modify: `lib/features/auth/presentation/providers/auth_providers.dart`
- Test: `test/features/auth/providers/guest_controller_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `test/features/auth/providers/guest_controller_test.dart` (before the closing `}`):

```dart

test('SessionController.logout also clears guest mode', () async {
  final memory = <String, String>{};
  final container = makeContainer(memory);

  await container.read(guestModeProvider.future);
  await container.read(guestModeProvider.notifier).enable();
  expect(container.read(guestModeProvider).value, isTrue);

  await container.read(sessionControllerProvider.future);
  await container.read(sessionControllerProvider.notifier).logout();

  expect(container.read(guestModeProvider).value, isFalse);
  expect(memory.containsKey('guest_mode'), isFalse);
});
```

No new import is needed — `sessionControllerProvider` is already exposed by the unqualified `auth_providers.dart` import added in Task 2.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/providers/guest_controller_test.dart`
Expected: FAIL — guest mode is still `true` after `logout()`.

- [ ] **Step 3: Implement**

In `lib/features/auth/presentation/providers/auth_providers.dart`, update `SessionController.logout()`:

```dart
  Future<void> logout() async {
    await _storage.clearSession();
    await ref.read(guestModeProvider.notifier).disable();
    state = const AsyncData(null);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/providers/guest_controller_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/presentation/providers/auth_providers.dart test/features/auth/providers/guest_controller_test.dart
git commit -m "feat(auth): clear guest mode on logout"
```

---

### Task 4: `PrimaryButton` — add a `ghost` variant

**Files:**
- Modify: `lib/shared/widgets/primary_button.dart`
- Test: `test/shared/widgets/primary_button_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `test/shared/widgets/primary_button_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/shared/widgets/primary_button.dart';

void main() {
  Future<void> pump(WidgetTester tester, PrimaryButtonVariant variant) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Continue as a guest',
            variant: variant,
            onPressed: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('ghost variant is transparent, bordered, and primary-colored text',
      (tester) async {
    await pump(tester, PrimaryButtonVariant.ghost);

    final material = tester.widget<Material>(find.byType(Material));
    expect(material.color, Colors.transparent);

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(InkWell),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.border, isNotNull);

    final text = tester.widget<Text>(find.text('Continue as a guest'));
    expect(text.style?.color, AppColors.primary);
  });

  testWidgets('primary variant keeps the solid filled style', (tester) async {
    await pump(tester, PrimaryButtonVariant.primary);

    final material = tester.widget<Material>(find.byType(Material));
    expect(material.color, AppColors.primary);

    final text = tester.widget<Text>(find.text('Continue as a guest'));
    expect(text.style?.color, AppColors.onPrimary);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/primary_button_test.dart`
Expected: FAIL — `PrimaryButtonVariant.ghost` doesn't exist.

- [ ] **Step 3: Implement the `ghost` variant**

Replace the full contents of `lib/shared/widgets/primary_button.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';

enum PrimaryButtonVariant { primary, amber, ghost }

/// Skyline primary action button: solid fill, soft colored glow, and a
/// built-in loading state. Disabled when [onPressed] is null or [loading].
///
/// [PrimaryButtonVariant.ghost] renders the same size and shape as an
/// outlined secondary action (e.g. "Continue as a guest") — transparent
/// fill, primary-colored border and label, no glow.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.variant = PrimaryButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final PrimaryButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final isGhost = variant == PrimaryButtonVariant.ghost;
    final bg = isGhost
        ? Colors.transparent
        : variant == PrimaryButtonVariant.amber
            ? AppColors.secondary
            : AppColors.primary;
    final fg = isGhost
        ? AppColors.primary
        : variant == PrimaryButtonVariant.amber
            ? AppColors.onSecondary
            : AppColors.onPrimary;
    final radius = BorderRadius.circular(AppRadius.input);

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: isGhost
              ? null
              : [
                  BoxShadow(
                    color: bg.withValues(alpha: 0.45),
                    blurRadius: 26,
                    spreadRadius: -10,
                    offset: const Offset(0, 14),
                  ),
                ],
        ),
        child: Material(
          color: bg,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            child: Container(
              height: 54,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: isGhost
                  ? BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    )
                  : null,
              child: loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(fg),
                      ),
                    )
                  : Text(
                      label,
                      style: AppTypography.title.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/primary_button_test.dart`
Expected: PASS

- [ ] **Step 5: Regression-check existing button usages**

Run: `flutter test test/features/profile/profile_screen_test.dart test/widget_test.dart`
Expected: PASS (both screens use `PrimaryButtonVariant.primary`, the default — behavior must be unchanged)

- [ ] **Step 6: Commit**

```bash
git add lib/shared/widgets/primary_button.dart test/shared/widgets/primary_button_test.dart
git commit -m "feat(ui): add ghost variant to PrimaryButton"
```

---

### Task 5: Localization — new ARB keys (ar + en)

**Files:**
- Modify: `lib/l10n/app_ar.arb`
- Modify: `lib/l10n/app_en.arb`

No test — these are data files consumed by codegen; correctness is verified by the screens that use the generated getters in later tasks.

- [ ] **Step 1: Add keys to `lib/l10n/app_ar.arb`**

Insert after line 22 (`"loginSignUp": "أنشئ حساباً",`) and before the blank line at 23:

```json
  "authContinueGuest": "المتابعة كضيف",
```

Insert a new top-level group anywhere after the existing `profileMenuLogout` key (find it with a search — do not guess its line number, ARB keys must stay valid JSON with correct trailing commas):

```json
  "guestGateTitle": "خطوة أخيرة قبل الدفع",
  "guestGateBody": "سجّل الدخول أو أنشئ حساباً لتأكيد حجزك وإتمام الدفع بأمان.",
  "guestGateSignIn": "تسجيل الدخول",
  "guestGateCreate": "أنشئ حساباً",
  "guestGateReassure": "حجزك محفوظ — لن تفقد مقاعدك",
  "profileGuestSignInCta": "سجّل الدخول أو أنشئ حساباً",
```

- [ ] **Step 2: Add the matching keys to `lib/l10n/app_en.arb`**

Insert after the `"loginSignUp": "Sign up",` line:

```json
  "authContinueGuest": "Continue as a guest",
```

Insert alongside the other keys (again, anywhere valid — find `profileMenuLogout` as the anchor):

```json
  "guestGateTitle": "One step before payment",
  "guestGateBody": "Sign in or create an account to confirm your booking and pay securely.",
  "guestGateSignIn": "Sign in",
  "guestGateCreate": "Create account",
  "guestGateReassure": "Your booking is saved — you won't lose your seats",
  "profileGuestSignInCta": "Sign in or create an account",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: exits 0, regenerates `lib/l10n/app_localizations*.dart` with the 6 new getters (`authContinueGuest`, `guestGateTitle`, `guestGateBody`, `guestGateSignIn`, `guestGateCreate`, `guestGateReassure`, `profileGuestSignInCta` — 7 total).

- [ ] **Step 4: Verify with a quick analyze**

Run: `flutter analyze lib/l10n`
Expected: no issues (confirms both ARB files are still valid JSON with matching key sets).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_ar.arb lib/l10n/app_en.arb
git commit -m "feat(l10n): add guest-mode copy (ar + en)"
```

---

### Task 6: `AuthGateArgs` + `OtpArgs.returnTo`

**Files:**
- Modify: `lib/features/auth/presentation/auth_flow_args.dart`

No standalone test — these are plain data classes exercised end-to-end by Tasks 9–11.

- [ ] **Step 1: Implement**

Replace the full contents of `lib/features/auth/presentation/auth_flow_args.dart`:

```dart
import 'package:rego/features/auth/domain/value/otp_purpose.dart';

/// Arguments handed to the OTP screen via go_router `extra`.
class OtpArgs {
  const OtpArgs({
    required this.phoneCode,
    required this.mobile,
    required this.purpose,
    this.returnTo,
  });

  final String phoneCode;
  final String mobile;
  final OtpPurpose purpose;

  /// Where to navigate after a successful registration OTP verify, when this
  /// flow was entered through the guest sign-in gate. Null for the normal
  /// (non-guest) registration flow, which lands on Home as before.
  final String? returnTo;
}

/// Arguments handed to the New-password screen via go_router `extra`.
class ResetArgs {
  const ResetArgs({
    required this.phoneCode,
    required this.mobile,
    required this.code,
  });

  final String phoneCode;
  final String mobile;
  final String code;
}

/// Arguments handed to the Login/Register screens via go_router `extra` when
/// they're entered through the guest sign-in gate (see `guest_gate_sheet.dart`).
/// [returnTo] is the route to land on after a successful sign-in/registration
/// instead of the default Home — typically the screen the guest was gated
/// from (e.g. the booking confirm screen).
class AuthGateArgs {
  const AuthGateArgs({required this.returnTo});

  final String returnTo;
}
```

- [ ] **Step 2: Run a full analyze to confirm nothing broke**

Run: `flutter analyze`
Expected: no new issues (existing `OtpArgs` call sites all use named args and don't need `returnTo`, which is optional).

- [ ] **Step 3: Commit**

```bash
git add lib/features/auth/presentation/auth_flow_args.dart
git commit -m "feat(auth): add AuthGateArgs and OtpArgs.returnTo for guest resume"
```

---

### Task 7: Router — guest-aware guard + gateArgs wiring for login/register

**Files:**
- Modify: `lib/core/router/app_router.dart`
- Test: `test/core/router/app_router_test.dart` (new)

- [ ] **Step 1: Write the failing tests**

Create `test/core/router/app_router_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/app.dart';
import 'package:rego/core/storage/secure_storage.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: File('.env.example').readAsStringSync());
  });

  testWidgets('signed-out, non-guest user is routed to Login', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(
            SecureStorage(memoryLocaleStore: {}, memoryGuestModeStore: {}),
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

    expect(find.text('Welcome to REGO'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify the guest one fails**

Run: `flutter test test/core/router/app_router_test.dart`
Expected: the first test (signed-out → Login) PASSes already (current behavior). The second (guest → Home) FAILs — a guest with no session is still bounced to Login today.

- [ ] **Step 3: Implement the guest-aware guard and route wiring**

In `lib/core/router/app_router.dart`, update the `login` and `register` route definitions (replace lines 65–72):

```dart
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) {
          final args = state.extra;
          return LoginScreen(
            gateArgs: args is AuthGateArgs ? args : null,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) {
          final args = state.extra;
          return RegisterScreen(
            gateArgs: args is AuthGateArgs ? args : null,
          );
        },
      ),
```

Update `_RouterNotifier` (replace lines 177–212, the whole class):

```dart
/// Bridges the session state to go_router: notifies on auth changes (so the
/// guard re-runs) and decides redirects based on whether a session exists
/// or the user is browsing as a guest.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(sessionControllerProvider, (_, __) => notifyListeners());
    _ref.listen(guestModeProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  static const _authRoutes = <String>{
    AppRoutes.splash,
    AppRoutes.onboarding,
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.otp,
    AppRoutes.forgotPassword,
    AppRoutes.newPassword,
  };

  String? redirect(BuildContext context, GoRouterState state) {
    final session = _ref.read(sessionControllerProvider);
    final guestMode = _ref.read(guestModeProvider);
    if (!session.hasValue || !guestMode.hasValue) {
      return null; // still resolving — splash waits.
    }

    final loggedIn = session.value != null;
    final isGuest = guestMode.value ?? false;
    final allowedInApp = loggedIn || isGuest;
    final at = state.matchedLocation;
    final atAuthRoute = _authRoutes.contains(at);

    // Splash always decides its own destination (home/login/onboarding),
    // so leave it alone even once the session has resolved.
    if (allowedInApp && atAuthRoute && at != AppRoutes.splash) {
      return AppRoutes.home;
    }
    if (!allowedInApp && !atAuthRoute) {
      return AppRoutes.login;
    }
    return null;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/router/app_router_test.dart`
Expected: PASS (both tests)

- [ ] **Step 5: Run the full existing widget test suite for regressions**

Run: `flutter test`
Expected: PASS. (`LoginScreen`/`RegisterScreen` now require a `gateArgs` constructor param from the router builders above — the next task adds that param. If this step fails to compile because `LoginScreen`/`RegisterScreen` don't yet accept `gateArgs`, that's expected; proceed to Task 8/9/10 which add it, then return here. In practice, do Tasks 7–10 as a contiguous block before running the full suite.)

- [ ] **Step 6: Commit**

```bash
git add lib/core/router/app_router.dart test/core/router/app_router_test.dart
git commit -m "feat(router): make the auth guard guest-aware"
```

---

### Task 8: `LoginScreen`/`RegisterScreen` — accept `gateArgs`

**Files:**
- Modify: `lib/features/auth/presentation/login_screen.dart`
- Modify: `lib/features/auth/presentation/register_screen.dart`

This task exists purely to make Task 7's router changes compile — it adds the constructor parameter without yet wiring up its behavior (that's Tasks 9–11). Keeping it separate keeps each task's diff honest.

- [ ] **Step 1: Add `gateArgs` to `LoginScreen`**

In `lib/features/auth/presentation/login_screen.dart`, add the import and constructor param (replace lines 26–31):

```dart
import 'package:rego/features/auth/presentation/auth_flow_args.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.gateArgs});

  final AuthGateArgs? gateArgs;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}
```

(`auth_flow_args.dart` is already imported for `OtpArgs` at line 14 — just add `AuthGateArgs` to that same import's usage; do not duplicate the import line.)

- [ ] **Step 2: Add `gateArgs` to `RegisterScreen`**

In `lib/features/auth/presentation/register_screen.dart`, replace lines 26–31:

```dart
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.gateArgs});

  final AuthGateArgs? gateArgs;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}
```

(`auth_flow_args.dart` is already imported at line 14 for `OtpArgs`.)

- [ ] **Step 3: Run analyze to confirm it compiles**

Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 4: Run the full test suite**

Run: `flutter test`
Expected: PASS — this confirms Task 7's router wiring now compiles end-to-end.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/presentation/login_screen.dart lib/features/auth/presentation/register_screen.dart
git commit -m "feat(auth): accept gateArgs on Login/Register screens"
```

---

### Task 9: Splash — guest-aware routing

**Files:**
- Modify: `lib/features/auth/presentation/splash_screen.dart`

The two `app_router_test.dart` tests from Task 7 already exercise this path end-to-end (splash is what actually performs the guest→Home / signed-out→Login navigation). This task has no new test of its own — it makes the two existing router tests reflect real routing logic instead of only the guard's redirect fallback.

- [ ] **Step 1: Update `SplashScreen` to also resolve guest mode**

Replace `lib/features/auth/presentation/splash_screen.dart` lines 1–63 (through the end of the `build` method's `ref.listen`/`ref.watch` setup — i.e. everything from the imports through the start of the `AnnotatedRegion` return) with:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/auth/domain/entities/auth_session.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/l10n/app_localizations.dart';

/// Minimum time the brand splash stays visible so users can see it.
const kMinSplashDuration = Duration(seconds: 2);

/// Brand splash that also bootstraps the session: once the stored session
/// and guest-mode flag resolve, it routes to Home (signed in or guest),
/// Onboarding (first run), or Login.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;
  late final DateTime _splashStartedAt = DateTime.now();

  Future<void> _route(
    AsyncValue<AuthSession?> session,
    AsyncValue<bool> guestMode,
  ) async {
    if (_navigated) return;
    if (!session.hasValue || !guestMode.hasValue) return;

    _navigated = true;
    final value = session.requireValue;
    final isGuest = guestMode.requireValue;

    final elapsed = DateTime.now().difference(_splashStartedAt);
    final remaining = kMinSplashDuration - elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);

    if (!mounted) return;

    if (value != null || isGuest) {
      context.go(AppRoutes.home);
      return;
    }
    final seen = await ref.read(secureStorageProvider).onboardingSeen();
    if (!mounted) return;
    context.go(seen ? AppRoutes.login : AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.listen(
      sessionControllerProvider,
      (_, next) => _route(next, ref.read(guestModeProvider)),
    );
    ref.listen(
      guestModeProvider,
      (_, next) => _route(ref.read(sessionControllerProvider), next),
    );

    final session = ref.watch(sessionControllerProvider);
    final guestMode = ref.watch(guestModeProvider);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _route(session, guestMode));
```

Everything from the existing `return AnnotatedRegion<SystemUiOverlayStyle>(` line through the end of the file stays exactly as-is (the visual tree and `_LoadingDots` are untouched).

- [ ] **Step 2: Run the router tests to verify they pass**

Run: `flutter test test/core/router/app_router_test.dart`
Expected: PASS (both tests, now exercising the real splash routing logic).

- [ ] **Step 3: Run the full suite for regressions**

Run: `flutter test`
Expected: PASS, including `test/widget_test.dart`.

- [ ] **Step 4: Commit**

```bash
git add lib/features/auth/presentation/splash_screen.dart
git commit -m "feat(auth): route guests straight to Home from splash"
```

---

### Task 10: Guest gate bottom sheet

**Files:**
- Create: `lib/features/auth/presentation/widgets/guest_gate_sheet.dart`
- Test: `test/features/auth/guest_gate_sheet_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `test/features/auth/guest_gate_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/features/auth/presentation/auth_flow_args.dart';
import 'package:rego/features/auth/presentation/widgets/guest_gate_sheet.dart';
import 'package:rego/l10n/app_localizations.dart';

void main() {
  Future<GoRouter> pumpWithGate(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.tripConfirm,
      routes: [
        GoRoute(
          path: AppRoutes.tripConfirm,
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    showGuestGate(context, returnTo: AppRoutes.tripConfirm),
                child: const Text('Confirm & pay'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) {
            final args = state.extra;
            return Scaffold(
              body: Text(
                args is AuthGateArgs
                    ? 'LOGIN returnTo=${args.returnTo}'
                    : 'LOGIN no gate args',
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (context, state) {
            final args = state.extra;
            return Scaffold(
              body: Text(
                args is AuthGateArgs
                    ? 'REGISTER returnTo=${args.returnTo}'
                    : 'REGISTER no gate args',
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('shows title, body, and reassurance copy', (tester) async {
    await pumpWithGate(tester);

    await tester.tap(find.text('Confirm & pay'));
    await tester.pumpAndSettle();

    expect(find.text('One step before payment'), findsOneWidget);
    expect(
      find.text(
        'Sign in or create an account to confirm your booking and pay securely.',
      ),
      findsOneWidget,
    );
    expect(
      find.text("Your booking is saved — you won't lose your seats"),
      findsOneWidget,
    );
  });

  testWidgets('Sign in pushes login with AuthGateArgs(returnTo)',
      (tester) async {
    await pumpWithGate(tester);

    await tester.tap(find.text('Confirm & pay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN returnTo=${AppRoutes.tripConfirm}'), findsOneWidget);
  });

  testWidgets('Create account pushes register with AuthGateArgs(returnTo)',
      (tester) async {
    await pumpWithGate(tester);

    await tester.tap(find.text('Confirm & pay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(
      find.text('REGISTER returnTo=${AppRoutes.tripConfirm}'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/guest_gate_sheet_test.dart`
Expected: FAIL — `guest_gate_sheet.dart` doesn't exist yet.

- [ ] **Step 3: Implement**

Create `lib/features/auth/presentation/widgets/guest_gate_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/auth/presentation/auth_flow_args.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

/// Shows the guest sign-in gate as a bottom sheet over whatever screen
/// [context] belongs to. [returnTo] is the route to land on after a
/// successful sign-in or registration (typically the screen the guest was
/// gated from, e.g. the booking confirm screen).
Future<void> showGuestGate(BuildContext context, {required String returnTo}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _GuestGateSheet(returnTo: returnTo),
  );
}

class _GuestGateSheet extends StatelessWidget {
  const _GuestGateSheet({required this.returnTo});

  final String returnTo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.secondaryTint,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              alignment: Alignment.center,
              child: const Icon(
                AppIcons.lock,
                color: AppColors.secondary,
                size: 26,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.guestGateTitle,
              textAlign: TextAlign.center,
              style: AppTypography.h2.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.guestGateBody,
              textAlign: TextAlign.center,
              style:
                  AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: l10n.guestGateSignIn,
              onPressed: () {
                Navigator.of(context).pop();
                context.push(
                  AppRoutes.login,
                  extra: AuthGateArgs(returnTo: returnTo),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: l10n.guestGateCreate,
              variant: PrimaryButtonVariant.ghost,
              onPressed: () {
                Navigator.of(context).pop();
                context.push(
                  AppRoutes.register,
                  extra: AuthGateArgs(returnTo: returnTo),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  AppIcons.checkCircle,
                  size: 16,
                  color: AppColors.success,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  l10n.guestGateReassure,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/guest_gate_sheet_test.dart`
Expected: PASS (all 3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/presentation/widgets/guest_gate_sheet.dart test/features/auth/guest_gate_sheet_test.dart
git commit -m "feat(auth): add the guest sign-in gate bottom sheet"
```

---

### Task 11: Login screen — guest entry button

**Files:**
- Modify: `lib/features/auth/presentation/login_screen.dart`
- Test: `test/features/auth/login_screen_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `test/features/auth/login_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/features/auth/presentation/login_screen.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/l10n/app_localizations.dart';

void main() {
  Future<ProviderContainer> pumpLogin(
    WidgetTester tester, {
    required Map<String, String> guestModeMemory,
  }) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(memoryGuestModeStore: guestModeMemory),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(guestModeProvider.future);

    final router = GoRouter(
      initialLocation: AppRoutes.login,
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const Text('HOME'),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('renders a "Continue as a guest" button below Sign in',
      (tester) async {
    await pumpLogin(tester, guestModeMemory: {});

    expect(find.text('Continue as a guest'), findsOneWidget);
  });

  testWidgets('tapping the guest button enables guest mode and goes Home',
      (tester) async {
    final memory = <String, String>{};
    final container = await pumpLogin(tester, guestModeMemory: memory);

    await tester.tap(find.text('Continue as a guest'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(container.read(guestModeProvider).value, isTrue);
    expect(memory['guest_mode'], 'true');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/login_screen_test.dart`
Expected: FAIL — no "Continue as a guest" text on screen.

- [ ] **Step 3: Add the button**

In `lib/features/auth/presentation/login_screen.dart`, add a method on `_LoginScreenState` (place it right after `_pickCountry`, before `_submit`):

```dart
  Future<void> _continueAsGuest() async {
    await ref.read(guestModeProvider.notifier).enable();
    if (mounted) context.go(AppRoutes.home);
  }
```

Then, in `build`'s `bottom` column, find this block (note: Task 8's edit shifted this a couple of lines down from where it was in the original file — locate it by content, not line number):

```dart
            PrimaryButton(
              label: l10n.loginButton,
              loading: _submitting,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.lg),
```

and replace it with:

```dart
            PrimaryButton(
              label: l10n.loginButton,
              loading: _submitting,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: l10n.authContinueGuest,
              variant: PrimaryButtonVariant.ghost,
              onPressed: _submitting ? null : _continueAsGuest,
            ),
            const SizedBox(height: AppSpacing.lg),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/login_screen_test.dart`
Expected: PASS (both tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/presentation/login_screen.dart test/features/auth/login_screen_test.dart
git commit -m "feat(auth): add Continue as a guest button to the login screen"
```

---

### Task 12: Login screen — resume via `gateArgs`, clear guest mode, forward to Register

**Files:**
- Modify: `lib/features/auth/presentation/login_screen.dart`
- Test: `test/features/auth/login_screen_test.dart`

- [ ] **Step 1: Write the failing tests**

Append to `test/features/auth/login_screen_test.dart` (before the closing `}` of `main()`), and add the extra imports at the top of the file:

```dart
import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/auth/domain/entities/auth_session.dart';
import 'package:rego/features/auth/domain/entities/auth_user.dart';
import 'package:rego/features/auth/domain/repositories/auth_repository.dart';
import 'package:rego/features/auth/presentation/auth_flow_args.dart';
```

```dart

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._session);
  final AuthSession _session;

  @override
  Future<AuthSession> login({
    required String phoneCode,
    required String mobile,
    required String password,
  }) async =>
      _session;

  @override
  Future<void> register({
    required String name,
    required String email,
    required String phoneCode,
    required String mobile,
    required String password,
    required String passwordConfirmation,
    String firebaseToken = '',
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> verifyOtp({
    required String phoneCode,
    required String mobile,
    required String code,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> sendOtp({required String phoneCode, required String mobile}) =>
      throw UnimplementedError();

  @override
  Future<void> resendOtp({
    required String phoneCode,
    required String mobile,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> validateOtp({
    required String phoneCode,
    required String mobile,
    required String code,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> forgetPassword({
    required String phoneCode,
    required String mobile,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> resetPassword({
    required String phoneCode,
    required String mobile,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) =>
      throw UnimplementedError();
}

void main() {
  // ... existing pumpLogin + earlier tests stay as-is above this point ...

  testWidgets(
      'successful login with gateArgs navigates to returnTo and clears guest mode',
      (tester) async {
    const session = AuthSession(
      token: 't',
      user: AuthUser(mobile: '1012345678', phoneCode: '20'),
    );
    final memory = <String, String>{'guest_mode': 'true'};
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(memoryGuestModeStore: memory),
        ),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository(session)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(guestModeProvider.future);

    final router = GoRouter(
      initialLocation: AppRoutes.login,
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) {
            final args = state.extra;
            return LoginScreen(gateArgs: args is AuthGateArgs ? args : null);
          },
        ),
        GoRoute(
          path: AppRoutes.tripConfirm,
          builder: (context, state) => const Text('CONFIRM'),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const Text('HOME'),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    router.go(
      AppRoutes.login,
      extra: const AuthGateArgs(returnTo: AppRoutes.tripConfirm),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '1012345678');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('CONFIRM'), findsOneWidget);
    expect(container.read(guestModeProvider).value, isFalse);
    expect(memory.containsKey('guest_mode'), isFalse);
  });

  testWidgets('Sign up link forwards gateArgs to the register screen',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(memoryGuestModeStore: {'guest_mode': 'true'}),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(guestModeProvider.future);

    final router = GoRouter(
      initialLocation: AppRoutes.login,
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) {
            final args = state.extra;
            return LoginScreen(gateArgs: args is AuthGateArgs ? args : null);
          },
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (context, state) {
            final args = state.extra;
            return Text(
              args is AuthGateArgs
                  ? 'REGISTER returnTo=${args.returnTo}'
                  : 'REGISTER no gate args',
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    router.go(
      AppRoutes.login,
      extra: const AuthGateArgs(returnTo: AppRoutes.tripConfirm),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    expect(
      find.text('REGISTER returnTo=${AppRoutes.tripConfirm}'),
      findsOneWidget,
    );
  });
}
```

(Replace the file's existing single `void main() { ... }` wrapper with this extended one — i.e. the `_FakeAuthRepository` class goes at top level after the imports, and the two new tests join the two from Task 11 inside the same `main()`.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/auth/login_screen_test.dart`
Expected: FAIL — login still always `go(AppRoutes.home)`, and the "Sign up" tap doesn't forward `extra`.

- [ ] **Step 3: Implement**

In `lib/features/auth/presentation/login_screen.dart`, in `_submit()`'s success path, find:

```dart
      await ref.read(sessionControllerProvider.notifier).setSession(session);
      if (mounted) context.go(AppRoutes.home);
```

and replace it with:

```dart
      await ref.read(sessionControllerProvider.notifier).setSession(session);
      await ref.read(guestModeProvider.notifier).disable();
      if (mounted) context.go(widget.gateArgs?.returnTo ?? AppRoutes.home);
```

Then find the "Sign up" `GestureDetector`'s `onTap`:

```dart
                  onTap: () => context.push(AppRoutes.register),
```

and replace it with:

```dart
                  onTap: () =>
                      context.push(AppRoutes.register, extra: widget.gateArgs),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/auth/login_screen_test.dart`
Expected: PASS (all 4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/presentation/login_screen.dart test/features/auth/login_screen_test.dart
git commit -m "feat(auth): resume to returnTo after guest sign-in"
```

---

### Task 13: Register + OTP screens — thread `gateArgs` through to verify success

**Files:**
- Modify: `lib/features/auth/presentation/register_screen.dart`
- Modify: `lib/features/auth/presentation/otp_verify_screen.dart`
- Test: `test/features/auth/otp_verify_screen_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `test/features/auth/otp_verify_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/features/auth/domain/entities/auth_session.dart';
import 'package:rego/features/auth/domain/entities/auth_user.dart';
import 'package:rego/features/auth/domain/repositories/auth_repository.dart';
import 'package:rego/features/auth/domain/value/otp_purpose.dart';
import 'package:rego/features/auth/presentation/auth_flow_args.dart';
import 'package:rego/features/auth/presentation/otp_verify_screen.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/l10n/app_localizations.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._session);
  final AuthSession _session;

  @override
  Future<AuthSession> login({
    required String phoneCode,
    required String mobile,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> register({
    required String name,
    required String email,
    required String phoneCode,
    required String mobile,
    required String password,
    required String passwordConfirmation,
    String firebaseToken = '',
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> verifyOtp({
    required String phoneCode,
    required String mobile,
    required String code,
  }) async =>
      _session;

  @override
  Future<void> sendOtp({required String phoneCode, required String mobile}) =>
      throw UnimplementedError();

  @override
  Future<void> resendOtp({
    required String phoneCode,
    required String mobile,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> validateOtp({
    required String phoneCode,
    required String mobile,
    required String code,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> forgetPassword({
    required String phoneCode,
    required String mobile,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> resetPassword({
    required String phoneCode,
    required String mobile,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) =>
      throw UnimplementedError();
}

void main() {
  testWidgets(
      'verifying registration OTP with a returnTo navigates there and clears guest mode',
      (tester) async {
    const session = AuthSession(
      token: 't',
      user: AuthUser(mobile: '1012345678', phoneCode: '20'),
    );
    final memory = <String, String>{'guest_mode': 'true'};
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(memoryGuestModeStore: memory),
        ),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository(session)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(guestModeProvider.future);

    final router = GoRouter(
      initialLocation: AppRoutes.otp,
      routes: [
        GoRoute(
          path: AppRoutes.otp,
          builder: (context, state) => OtpVerifyScreen(
            args: const OtpArgs(
              phoneCode: '20',
              mobile: '1012345678',
              purpose: OtpPurpose.registration,
              returnTo: AppRoutes.tripConfirm,
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.tripConfirm,
          builder: (context, state) => const Text('CONFIRM'),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const Text('HOME'),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '1234');
    await tester.pumpAndSettle();

    expect(find.text('CONFIRM'), findsOneWidget);
    expect(container.read(guestModeProvider).value, isFalse);
    expect(memory.containsKey('guest_mode'), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/otp_verify_screen_test.dart`
Expected: FAIL — `OtpArgs` has no `returnTo`... actually it does (Task 6), but `OtpVerifyScreen` still always `go(AppRoutes.home)` and never disables guest mode, so the test lands on `'HOME'` not `'CONFIRM'`.

- [ ] **Step 3: Implement in `OtpVerifyScreen`**

In `lib/features/auth/presentation/otp_verify_screen.dart`, update the registration branch of `_confirm()` (replace lines 78–84):

```dart
      if (widget.args.purpose == OtpPurpose.registration) {
        final session = await repo.verifyOtp(
          phoneCode: widget.args.phoneCode,
          mobile: widget.args.mobile,
          code: _code,
        );
        await ref.read(sessionControllerProvider.notifier).setSession(session);
        await ref.read(guestModeProvider.notifier).disable();
        if (mounted) {
          context.go(widget.args.returnTo ?? AppRoutes.home);
        }
```

- [ ] **Step 4: Thread `gateArgs.returnTo` from `RegisterScreen` into the OTP push**

In `lib/features/auth/presentation/register_screen.dart`, in `_submit()`'s success path, find:

```dart
      await context.push(
        AppRoutes.otp,
        extra: OtpArgs(
          phoneCode: _country.dial,
          mobile: mobile,
          purpose: OtpPurpose.registration,
        ),
      );
```

and replace it with:

```dart
      await context.push(
        AppRoutes.otp,
        extra: OtpArgs(
          phoneCode: _country.dial,
          mobile: mobile,
          purpose: OtpPurpose.registration,
          returnTo: widget.gateArgs?.returnTo,
        ),
      );
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/auth/otp_verify_screen_test.dart`
Expected: PASS

- [ ] **Step 6: Run the full suite for regressions**

Run: `flutter test`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/features/auth/presentation/register_screen.dart lib/features/auth/presentation/otp_verify_screen.dart test/features/auth/otp_verify_screen_test.dart
git commit -m "feat(auth): resume to returnTo after guest registration"
```

---

### Task 14: Passenger confirm screen — gate the pay button for guests

**Files:**
- Modify: `lib/features/booking/presentation/passenger_confirm_screen.dart`
- Test: `test/features/booking/passenger_confirm_screen_test.dart` (new)

- [ ] **Step 1: Write the failing tests**

Create `test/features/booking/passenger_confirm_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/booking/presentation/passenger_confirm_screen.dart';
import 'package:rego/features/booking/presentation/providers/booking_providers.dart';
import 'package:rego/l10n/app_localizations.dart';

class _FakeGuestController extends GuestController {
  _FakeGuestController(this._value);
  final bool _value;

  @override
  Future<bool> build() async => _value;
}

void main() {
  Future<ProviderContainer> pumpConfirm(
    WidgetTester tester, {
    required bool isGuest,
  }) async {
    final container = ProviderContainer(
      overrides: [
        guestModeProvider.overrideWith(() => _FakeGuestController(isGuest)),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: AppRoutes.tripConfirm,
      routes: [
        GoRoute(
          path: AppRoutes.tripConfirm,
          builder: (context, state) => const PassengerConfirmScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const Text('LOGIN'),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
      'guest tapping Confirm & pay opens the sign-in gate, not the booking flow',
      (tester) async {
    final container = await pumpConfirm(tester, isGuest: true);

    await tester.tap(find.text('Confirm & pay'));
    await tester.pumpAndSettle();

    expect(find.text('One step before payment'), findsOneWidget);
    expect(
      container.read(bookingFlowProvider).status,
      BookingFlowStatus.idle,
    );
  });

  testWidgets('non-guest tapping Confirm & pay proceeds to book directly',
      (tester) async {
    final container = await pumpConfirm(tester, isGuest: false);

    await tester.tap(find.text('Confirm & pay'));
    await tester.pumpAndSettle();

    expect(find.text('One step before payment'), findsNothing);
    expect(
      container.read(bookingFlowProvider).status,
      BookingFlowStatus.confirmed,
    );
  });
}
```

- [ ] **Step 2: Run tests to verify the guest one fails**

Run: `flutter test test/features/booking/passenger_confirm_screen_test.dart`
Expected: the non-guest test PASSes already (current behavior calls `confirmBooking()` unconditionally). The guest test FAILs — today it also calls `confirmBooking()` and reaches `confirmed`, and the gate never appears.

- [ ] **Step 3: Implement**

In `lib/features/booking/presentation/passenger_confirm_screen.dart`, add imports (alongside the existing ones, after line 14):

```dart
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/auth/presentation/widgets/guest_gate_sheet.dart';
```

In the `bottomNavigationBar`'s `PrimaryButton`, find:

```dart
            onPressed: isLoading
                ? null
                : () => ref.read(bookingFlowProvider.notifier).confirmBooking(),
```

and replace it with:

```dart
            onPressed: isLoading
                ? null
                : () {
                    final isGuest = ref.read(guestModeProvider).value ?? false;
                    if (isGuest) {
                      showGuestGate(context, returnTo: AppRoutes.tripConfirm);
                    } else {
                      ref.read(bookingFlowProvider.notifier).confirmBooking();
                    }
                  },
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/booking/passenger_confirm_screen_test.dart`
Expected: PASS (both tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/booking/presentation/passenger_confirm_screen.dart test/features/booking/passenger_confirm_screen_test.dart
git commit -m "feat(booking): gate guest checkout behind sign-in at confirm-&-pay"
```

---

### Task 15: Profile screen — sign-in CTA replaces Log out for guests

**Files:**
- Modify: `lib/features/profile/presentation/profile_screen.dart`
- Test: `test/features/profile/profile_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `test/features/profile/profile_screen_test.dart` (before the closing `}` of `main()`), and add these imports at the top of the file:

```dart
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/features/auth/presentation/auth_flow_args.dart';
```

```dart

class _FakeGuestController extends GuestController {
  _FakeGuestController(this._value);
  final bool _value;

  @override
  Future<bool> build() async => _value;
}

testWidgets(
    'guest sees a sign-in CTA instead of Log out, and it opens Login with returnTo',
    (tester) async {
  final container = ProviderContainer(
    overrides: [
      sessionControllerProvider.overrideWith(
        () => _FakeSessionController(null),
      ),
      guestModeProvider.overrideWith(() => _FakeGuestController(true)),
    ],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.profile,
    routes: [
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) {
          final args = state.extra;
          return Text(
            args is AuthGateArgs
                ? 'LOGIN returnTo=${args.returnTo}'
                : 'LOGIN no gate args',
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Log out'), findsNothing);
  final ctaLabel = find.text('Sign in or create an account');
  expect(ctaLabel, findsOneWidget);

  await tester.ensureVisible(ctaLabel);
  await tester.pumpAndSettle();
  await tester.tap(ctaLabel);
  await tester.pumpAndSettle();

  expect(find.text('LOGIN returnTo=${AppRoutes.profile}'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/profile/profile_screen_test.dart`
Expected: FAIL — Profile always shows the Log out card today, regardless of guest mode.

- [ ] **Step 3: Implement**

In `lib/features/profile/presentation/profile_screen.dart`, add imports (after line 12):

```dart
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/features/auth/presentation/auth_flow_args.dart';
```

In `build`, find these two lines (the method signature `Widget build(BuildContext context, WidgetRef ref) {` right above them, and the blank line right below, both stay untouched):

```dart
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(sessionControllerProvider).value?.user;
```

and replace them with:

```dart
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(sessionControllerProvider).value?.user;
    final isGuest = ref.watch(guestModeProvider).value ?? false;
```

Further down, find the `_ProfileLogoutCard` usage:

```dart
                  _ProfileLogoutCard(
                    label: l10n.profileMenuLogout,
                    onTap: () => _confirmLogout(context, ref),
                  ),
```

and replace it with a guest-aware switch:

```dart
                  isGuest
                      ? _ProfileSignInCard(
                          label: l10n.profileGuestSignInCta,
                          onTap: () => context.push(
                            AppRoutes.login,
                            extra:
                                const AuthGateArgs(returnTo: AppRoutes.profile),
                          ),
                        )
                      : _ProfileLogoutCard(
                          label: l10n.profileMenuLogout,
                          onTap: () => _confirmLogout(context, ref),
                        ),
```

Add the new `_ProfileSignInCard` widget right after `_ProfileLogoutCard`'s class (after its closing `}`, i.e. after line 385):

```dart

class _ProfileSignInCard extends StatelessWidget {
  const _ProfileSignInCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: -12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _ProfileMenuTile(
        icon: AppIcons.user,
        label: label,
        onTap: onTap,
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/profile/profile_screen_test.dart`
Expected: PASS (all tests in the file, old and new)

- [ ] **Step 5: Commit**

```bash
git add lib/features/profile/presentation/profile_screen.dart test/features/profile/profile_screen_test.dart
git commit -m "feat(profile): show a sign-in CTA instead of Log out for guests"
```

---

### Task 16: Full regression pass

**Files:** none (verification only)

- [ ] **Step 1: Static analysis**

Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: all tests PASS, including every file touched in Tasks 1–15 and every pre-existing test (`test/widget_test.dart`, `test/features/shell/*`, `test/features/booking/booking_notifier_test.dart`, `test/features/auth/data/*`, `test/core/*`).

- [ ] **Step 3: Manual smoke test (per CLAUDE.md's `/run` and `/verify` guidance)**

Launch the app (`flutter run` or the project's preview tooling) and walk the golden path once:

1. Fresh install (or clear storage) → Login screen shows "Continue as a guest" beneath "Sign in".
2. Tap it → lands on Home with the bottom nav visible; Search/Trips/Wallet are reachable without being bounced to Login.
3. Search a trip → pick seats → reach Passenger confirm → tap "Confirm & pay" → the bottom sheet appears over the summary (booking selection still visible behind the scrim).
4. Tap "Sign in" in the sheet → complete login with a real/test account → confirm you land back on the Passenger confirm screen (not Home) with the same trip/seats still selected.
5. Tap "Confirm & pay" again → this time it books directly (no gate) and reaches the e-ticket screen.
6. Go to Profile as a guest (before signing in, in a second run) → confirm "Sign in or create an account" appears instead of "Log out", and tapping it opens Login.

If any step diverges from the spec, stop and report before considering the feature done — do not mark this task complete on the strength of passing automated tests alone.

- [ ] **Step 4: Final commit (if the manual smoke test surfaced fixups)**

```bash
git add -A
git commit -m "fix: address issues found in guest-mode manual smoke test"
```

(Skip this step if Step 3 found nothing to fix.)

---

## Summary of files touched

| File | Change |
|---|---|
| `lib/core/storage/secure_storage.dart` | `guest_mode` key + accessors |
| `lib/features/auth/presentation/providers/auth_providers.dart` | `GuestController`, `guestModeProvider`, `logout()` clears guest |
| `lib/shared/widgets/primary_button.dart` | `PrimaryButtonVariant.ghost` |
| `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb` | 7 new keys |
| `lib/features/auth/presentation/auth_flow_args.dart` | `AuthGateArgs`, `OtpArgs.returnTo` |
| `lib/core/router/app_router.dart` | guest-aware guard, login/register route `gateArgs` wiring |
| `lib/features/auth/presentation/login_screen.dart` | guest button, `gateArgs` param, resume, forwards to Register |
| `lib/features/auth/presentation/register_screen.dart` | `gateArgs` param, forwards `returnTo` to OTP |
| `lib/features/auth/presentation/otp_verify_screen.dart` | resume to `returnTo`, clears guest mode |
| `lib/features/auth/presentation/splash_screen.dart` | guest-aware routing |
| `lib/features/auth/presentation/widgets/guest_gate_sheet.dart` | new — the bottom sheet |
| `lib/features/booking/presentation/passenger_confirm_screen.dart` | gates guest checkout |
| `lib/features/profile/presentation/profile_screen.dart` | guest sign-in CTA replaces Log out |

New test files: `test/core/storage/secure_storage_test.dart` (extended), `test/features/auth/providers/guest_controller_test.dart`, `test/shared/widgets/primary_button_test.dart`, `test/core/router/app_router_test.dart`, `test/features/auth/guest_gate_sheet_test.dart`, `test/features/auth/login_screen_test.dart`, `test/features/auth/otp_verify_screen_test.dart`, `test/features/booking/passenger_confirm_screen_test.dart`, `test/features/profile/profile_screen_test.dart` (extended).
