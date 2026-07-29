# Google Login/Sign-Up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the existing "Continue with Google" button on Login/Register into a real Google Sign-In flow that logs in or creates an account via a new backend endpoint, and blocks new Google accounts on a phone-completion step before they can use the app.

**Architecture:** `GoogleSignInService` (data layer) wraps the `google_sign_in` SDK and returns only an ID token. `AuthRepository.socialLoginWithGoogle` sends that token to the new `POST /auth/social-login` endpoint and returns the same `AuthSession` shape as phone login. A router guard redirects any signed-in session with `isProfileCompleted == false` to a new `CompletePhoneScreen`, which reuses the existing OTP screen (new `OtpPurpose.linkGoogleAccountPhone` branch) and the existing, already-documented `/profile/verify-alt-phone` endpoint.

**Tech Stack:** Flutter, Riverpod, go_router, Dio, `google_sign_in: ^7.2.0`.

**Full design spec:** `docs/superpowers/specs/2026-07-29-google-sign-in-design.md`

## Global Constraints

- Client SDK is `google_sign_in: ^7.2.0` only — no `firebase_core`/`firebase_auth`.
- Android only for this feature (no `ios/` project exists in this repo).
- New backend contract (mobile-defined, backend team implements to match): `POST /auth/social-login`, form-data body `provider`, `id_token`, `firebase_token`; response is the same envelope shape as `/auth/login`/`/auth/register`.
- A session with `user.isProfileCompleted == false` must be blocked on `/complete-profile` (new route) everywhere except `/complete-profile` and `/otp` themselves.
- Phone completion reuses existing endpoints only: `/auth/send-otp` (already wired) and `/profile/verify-alt-phone` (new repository method, endpoint already documented and live).
- No Freezed/`@riverpod`/`json_serializable` schema changes are needed anywhere in this plan (`mobile`/`phonecode`/`email`/`name` are already nullable on `AuthResponseDto`/`AuthUser`) — **no `build_runner` step in this plan**.
- Package imports only (`package:safaria/...`), `dart format` conventions, `EdgeInsetsDirectional`/`AlignmentDirectional` for any new layout, every user-facing string via `AppLocalizations` (added to both `app_en.arb` and `app_ar.arb`).
- After editing `pubspec.yaml`, run `./tool/pub-get.ps1` (Windows) — **never** a bare `flutter pub get` — per `CLAUDE.md`/`tool/README.md`.
- Shell is PowerShell — chain commands with `;` or separate lines, not `&&`.

---

### Task 1: Add the `google_sign_in` dependency and `AppConfig` wiring

**Files:**
- Modify: `pubspec.yaml` (insert after the `flutter_svg` line, ~line 44)
- Modify: `.env.example` (append after the `GOOGLE_MAPS_API_KEY` block)
- Modify: `lib/core/config/app_config.dart`
- Test: `test/core/config/app_config_test.dart` (new file)

**Interfaces:**
- Produces: `AppConfig.googleWebClientId` (`String`), `AppConfig.isGoogleSignInConfigured` (`bool`) — consumed by Task 6 (`GoogleSignInService`) and Task 11 (`handleGoogleSignIn`).

- [ ] **Step 1: Add the dependency to `pubspec.yaml`**

Open `pubspec.yaml` and find:

```yaml
  # SVG rendering (brand marks: Google / Facebook / Apple)
  flutter_svg: ^2.0.17
```

Replace with:

```yaml
  # SVG rendering (brand marks: Google / Facebook / Apple)
  flutter_svg: ^2.0.17

  # Google Sign-In ("Continue with Google" on Login/Register)
  google_sign_in: ^7.2.0
```

- [ ] **Step 2: Fetch packages with the project's patch-aware script**

Run (PowerShell):

```powershell
./tool/pub-get.ps1
```

Expected: completes with `Got dependencies!` (or similar) and no error. This also re-applies the `url_launcher_android` Kotlin patch if it was wiped.

- [ ] **Step 3: Verify `google_sign_in_android` doesn't need a Kotlin patch**

Run:

```powershell
dart run tool/patch_android_plugins.dart --check
```

Expected: exits 0, reporting only the known `url_launcher_android` patch (or "all patched plugins OK"). If it reports a **new** failure for `google_sign_in_android` (a compile error mentioning `kotlin { compilerOptions { ... } }` in that plugin's `android/build.gradle.kts`, per `tool/README.md`), follow the exact procedure in `tool/README.md`'s "When a patched plugin is upgraded" section: copy the pristine cached `android/build.gradle.kts` for that plugin/version into `tool/plugin_patches/google_sign_in_android-<version>.build.gradle.kts`, apply the same explicit-Kotlin-Gradle-Plugin fix already used for `url_launcher_android`, then re-run the check. (As of `google_sign_in_android: ^7.2.15`, this is not expected to be needed — only verify.)

- [ ] **Step 4: Add the env var to `.env.example`**

Open `.env.example` and find:

```
GOOGLE_MAPS_API_KEY=

```

Replace with:

```
GOOGLE_MAPS_API_KEY=

# Google Sign-In ("Continue with Google" on Login/Register).
# Web client ID (OAuth 2.0 "Web application" type) from Google Cloud Console
# / Firebase — required so the backend can verify the ID token server-side.
# Leave empty to keep the button disabled with a friendly error instead of
# crashing the SDK.
GOOGLE_WEB_CLIENT_ID=

```

- [ ] **Step 5: Write the failing test for `AppConfig`**

Create `test/core/config/app_config_test.dart`:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/core/config/app_config.dart';

void main() {
  group('AppConfig.isGoogleSignInConfigured', () {
    test('is false when GOOGLE_WEB_CLIENT_ID is empty', () {
      dotenv.testLoad(fileInput: 'GOOGLE_WEB_CLIENT_ID=');

      expect(AppConfig.googleWebClientId, '');
      expect(AppConfig.isGoogleSignInConfigured, isFalse);
    });

    test('is true when GOOGLE_WEB_CLIENT_ID is set', () {
      dotenv.testLoad(
        fileInput: 'GOOGLE_WEB_CLIENT_ID=abc123.apps.googleusercontent.com',
      );

      expect(
        AppConfig.googleWebClientId,
        'abc123.apps.googleusercontent.com',
      );
      expect(AppConfig.isGoogleSignInConfigured, isTrue);
    });
  });
}
```

- [ ] **Step 6: Run the test to verify it fails**

```powershell
flutter test test/core/config/app_config_test.dart
```

Expected: FAIL — `googleWebClientId`/`isGoogleSignInConfigured` are not defined on `AppConfig`.

- [ ] **Step 7: Implement the `AppConfig` getters**

Open `lib/core/config/app_config.dart`. Current content:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to environment variables. All values have safe defaults so
/// the app can run in local-only mode without a backend.
abstract final class AppConfig {
  /// Wadeny backend base URL. Future environments only swap this value
  /// (via `.env`); call-sites never hardcode hosts.
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://demo.safaria.travel/api/v1';

  /// Optional static API key (unused by the auth flow, which authenticates
  /// per-user via Sanctum bearer tokens). Kept for non-auth integrations.
  static String get apiKey => dotenv.env['API_KEY'] ?? '';

  static bool get isBackendConfigured => apiBaseUrl.isNotEmpty;

  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  static bool get isGoogleMapsConfigured => googleMapsApiKey.isNotEmpty;
}
```

Replace the final line (`}`) so the class reads:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to environment variables. All values have safe defaults so
/// the app can run in local-only mode without a backend.
abstract final class AppConfig {
  /// Wadeny backend base URL. Future environments only swap this value
  /// (via `.env`); call-sites never hardcode hosts.
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://demo.safaria.travel/api/v1';

  /// Optional static API key (unused by the auth flow, which authenticates
  /// per-user via Sanctum bearer tokens). Kept for non-auth integrations.
  static String get apiKey => dotenv.env['API_KEY'] ?? '';

  static bool get isBackendConfigured => apiBaseUrl.isNotEmpty;

  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  static bool get isGoogleMapsConfigured => googleMapsApiKey.isNotEmpty;

  /// OAuth 2.0 "Web application" client ID used to request a verifiable
  /// Google ID token. Required for `GoogleSignIn.initialize`.
  static String get googleWebClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';

  static bool get isGoogleSignInConfigured => googleWebClientId.isNotEmpty;
}
```

- [ ] **Step 8: Run the test to verify it passes**

```powershell
flutter test test/core/config/app_config_test.dart
```

Expected: PASS (2 tests).

- [ ] **Step 9: Commit**

```powershell
git add pubspec.yaml pubspec.lock .env.example lib/core/config/app_config.dart test/core/config/app_config_test.dart
git commit -m "Add google_sign_in dependency and AppConfig wiring"
```

---

### Task 2: Add `CompleteProfileArgs`

**Files:**
- Modify: `lib/features/auth/presentation/auth_flow_args.dart`

**Interfaces:**
- Produces: `CompleteProfileArgs { final String? returnTo; }` — consumed by Task 8 (router), Task 9 (`CompletePhoneScreen`), Task 11 (`handleGoogleSignIn`).

No test needed — this is a plain data holder with no behavior, mirroring `ResetArgs`/`AuthGateArgs` in the same file (which are likewise untested directly; they're exercised through the screens that use them).

- [ ] **Step 1: Add the class**

Open `lib/features/auth/presentation/auth_flow_args.dart`. After the closing brace of `AuthGateArgs` (end of file), add:

```dart

/// Arguments handed to the Complete-profile screen via go_router `extra`,
/// carried through from whichever screen (or router redirect) sent the user
/// there. [returnTo] is where to land after the phone is verified — the
/// same semantics as [AuthGateArgs.returnTo].
class CompleteProfileArgs {
  const CompleteProfileArgs({this.returnTo});

  final String? returnTo;
}
```

- [ ] **Step 2: Commit**

```powershell
git add lib/features/auth/presentation/auth_flow_args.dart
git commit -m "Add CompleteProfileArgs for the Google phone-completion flow"
```

---

### Task 3: `ProfileRepository.verifyAltPhone`

**Files:**
- Modify: `lib/features/profile/domain/repositories/profile_repository.dart`
- Modify: `lib/features/profile/data/profile_api.dart`
- Modify: `lib/features/profile/data/profile_repository_impl.dart`
- Test: `test/features/profile/data/profile_repository_impl_test.dart`

**Interfaces:**
- Consumes: `AuthUser.fromJson` (existing), `ApiException.fromEnvelope` (existing).
- Produces: `ProfileRepository.verifyAltPhone({required String phoneCode, required String mobile, required String code}) → Future<AuthUser>` — consumed by Task 7 (`OtpVerifyScreen`).

- [ ] **Step 1: Write the failing test**

Open `test/features/profile/data/profile_repository_impl_test.dart`. Update the fake API class at the top of the file from:

```dart
class _FakeProfileApi extends ProfileApi {
  _FakeProfileApi({this.fetchBody, this.updateBody, this.onUpdate}) : super(Dio());

  final dynamic fetchBody;
  final dynamic updateBody;
  final void Function(FormData body)? onUpdate;

  @override
  Future<dynamic> fetch() async => fetchBody;

  @override
  Future<dynamic> update(FormData body) async {
    onUpdate?.call(body);
    return updateBody;
  }
}
```

to:

```dart
class _FakeProfileApi extends ProfileApi {
  _FakeProfileApi({
    this.fetchBody,
    this.updateBody,
    this.onUpdate,
    this.verifyAltPhoneBody,
  }) : super(Dio());

  final dynamic fetchBody;
  final dynamic updateBody;
  final dynamic verifyAltPhoneBody;
  final void Function(FormData body)? onUpdate;

  @override
  Future<dynamic> fetch() async => fetchBody;

  @override
  Future<dynamic> update(FormData body) async {
    onUpdate?.call(body);
    return updateBody;
  }

  @override
  Future<dynamic> verifyAltPhone({
    required String phoneCode,
    required String mobile,
    required String code,
  }) async =>
      verifyAltPhoneBody;
}
```

Then add this new test group at the end of `main()`, right before the final closing `});` of the outer `group('ProfileRepositoryImpl', ...)` block (i.e. as a sibling of the existing `test(...)` calls inside it):

```dart

    group('verifyAltPhone', () {
      test('returns the user with the phone now attached', () async {
        const envelope = {
          'status': 200,
          'message': 'User data',
          'errors': <String, dynamic>{},
          'data': {
            'id': 90,
            'name': 'Abdallah',
            'email': 'abdallah@gmail.com',
            'mobile': '1276586027',
            'phonecode': '20',
            'status': 'Active',
            'avatar': '',
            'is_profile_completed': true,
          },
        };

        final repo = ProfileRepositoryImpl(
          _FakeProfileApi(verifyAltPhoneBody: envelope),
        );

        final user = await repo.verifyAltPhone(
          phoneCode: '20',
          mobile: '1276586027',
          code: '1234',
        );

        expect(user.mobile, '1276586027');
        expect(user.isProfileCompleted, isTrue);
      });

      test('throws ApiException on an error envelope', () async {
        const envelope = {
          'status': 400,
          'message': 'Invalid verification code',
          'errors': {
            'code': 'Invalid verification code',
          },
          'data': <String, dynamic>{},
        };

        final repo = ProfileRepositoryImpl(
          _FakeProfileApi(verifyAltPhoneBody: envelope),
        );

        await expectLater(
          repo.verifyAltPhone(
            phoneCode: '20',
            mobile: '1276586027',
            code: '0000',
          ),
          throwsA(isA<ApiException>()),
        );
      });
    });
```

Also add the `ApiException` import at the top of the test file (it isn't imported yet):

```dart
import 'package:safaria/core/network/api_exception.dart';
```

- [ ] **Step 2: Run the test to verify it fails**

```powershell
flutter test test/features/profile/data/profile_repository_impl_test.dart
```

Expected: FAIL to compile — `verifyAltPhone` is not defined on `ProfileApi`/`ProfileRepositoryImpl`.

- [ ] **Step 3: Add `verifyAltPhone` to the domain interface**

Open `lib/features/profile/domain/repositories/profile_repository.dart`. Current content:

```dart
import 'package:safaria/features/auth/domain/entities/auth_user.dart';

/// Contract for `/profile` show + update. The user shape matches [AuthUser].
abstract interface class ProfileRepository {
  Future<AuthUser> fetchProfile();

  Future<AuthUser> updateProfile({
    required int id,
    required String name,
    required String email,
    required String phoneCode,
    required String mobile,
    String? avatarPath,
  });
}
```

Replace with:

```dart
import 'package:safaria/features/auth/domain/entities/auth_user.dart';

/// Contract for `/profile` show + update. The user shape matches [AuthUser].
abstract interface class ProfileRepository {
  Future<AuthUser> fetchProfile();

  Future<AuthUser> updateProfile({
    required int id,
    required String name,
    required String email,
    required String phoneCode,
    required String mobile,
    String? avatarPath,
  });

  /// Verifies [code] and attaches [mobile]/[phoneCode] to the signed-in
  /// account via `/profile/verify-alt-phone`. Used to complete a Google
  /// sign-up that has no phone on file yet.
  Future<AuthUser> verifyAltPhone({
    required String phoneCode,
    required String mobile,
    required String code,
  });
}
```

- [ ] **Step 4: Add the transport method to `ProfileApi`**

Open `lib/features/profile/data/profile_api.dart`. Current content:

```dart
import 'package:dio/dio.dart';

/// Transport layer over `/profile`. Returns raw decoded JSON bodies.
class ProfileApi {
  ProfileApi(this._dio);

  final Dio _dio;

  Future<dynamic> fetch() async {
    final res = await _dio.get('/profile');
    return res.data;
  }

  Future<dynamic> update(FormData body) async {
    final res = await _dio.post('/profile', data: body);
    return res.data;
  }
}
```

Replace with:

```dart
import 'package:dio/dio.dart';

/// Transport layer over `/profile`. Returns raw decoded JSON bodies.
class ProfileApi {
  ProfileApi(this._dio);

  final Dio _dio;

  Future<dynamic> fetch() async {
    final res = await _dio.get('/profile');
    return res.data;
  }

  Future<dynamic> update(FormData body) async {
    final res = await _dio.post('/profile', data: body);
    return res.data;
  }

  Future<dynamic> verifyAltPhone({
    required String phoneCode,
    required String mobile,
    required String code,
  }) async {
    final res = await _dio.post(
      '/profile/verify-alt-phone',
      data: {
        'mobile': int.tryParse(mobile) ?? mobile,
        'phonecode': int.tryParse(phoneCode) ?? phoneCode,
        'code': code,
      },
    );
    return res.data;
  }
}
```

- [ ] **Step 5: Implement in `ProfileRepositoryImpl`**

Open `lib/features/profile/data/profile_repository_impl.dart`. Find:

```dart
  AuthUser _userFromEnvelope(dynamic body) {
```

Insert a new method directly above it (i.e. right after the closing brace of `updateProfile`, before `_userFromEnvelope`):

```dart
  @override
  Future<AuthUser> verifyAltPhone({
    required String phoneCode,
    required String mobile,
    required String code,
  }) =>
      _guard(() async => _userFromEnvelope(
            await _api.verifyAltPhone(
              phoneCode: phoneCode,
              mobile: mobile,
              code: code,
            ),
          ));

  AuthUser _userFromEnvelope(dynamic body) {
```

- [ ] **Step 6: Run the test to verify it passes**

```powershell
flutter test test/features/profile/data/profile_repository_impl_test.dart
```

Expected: PASS (all tests in the file, including the 2 new ones).

- [ ] **Step 7: Commit**

```powershell
git add lib/features/profile/domain/repositories/profile_repository.dart lib/features/profile/data/profile_api.dart lib/features/profile/data/profile_repository_impl.dart test/features/profile/data/profile_repository_impl_test.dart
git commit -m "Add ProfileRepository.verifyAltPhone for the Google phone-completion flow"
```

---

### Task 4: `AuthRepository.socialLoginWithGoogle`

**Files:**
- Modify: `lib/features/auth/domain/repositories/auth_repository.dart`
- Modify: `lib/features/auth/data/auth_api.dart`
- Modify: `lib/features/auth/data/auth_repository_impl.dart`
- Modify: `test/support/fake_auth_repository.dart`
- Test: `test/features/auth/data/auth_repository_impl_test.dart`

**Interfaces:**
- Consumes: `_guard`, `_parseSession` (existing private helpers in `AuthRepositoryImpl`).
- Produces: `AuthRepository.socialLoginWithGoogle({required String idToken, required String firebaseToken}) → Future<AuthSession>` — consumed by Task 11 (`handleGoogleSignIn`).

- [ ] **Step 1: Write the failing test**

Open `test/features/auth/data/auth_repository_impl_test.dart`. Update `_FakeAuthApi` from:

```dart
class _FakeAuthApi extends AuthApi {
  _FakeAuthApi({this.loginBody, this.registerBody}) : super(Dio());

  final dynamic loginBody;
  final dynamic registerBody;

  @override
  Future<dynamic> login({
    required String phoneCode,
    required String mobile,
    required String password,
  }) async =>
      loginBody;

  @override
  Future<dynamic> register({
    required String name,
    required String email,
    required String phoneCode,
    required String mobile,
    required String password,
    required String passwordConfirmation,
    required String firebaseToken,
  }) async =>
      registerBody;
}
```

to:

```dart
class _FakeAuthApi extends AuthApi {
  _FakeAuthApi({this.loginBody, this.registerBody, this.socialLoginBody})
      : super(Dio());

  final dynamic loginBody;
  final dynamic registerBody;
  final dynamic socialLoginBody;

  @override
  Future<dynamic> login({
    required String phoneCode,
    required String mobile,
    required String password,
  }) async =>
      loginBody;

  @override
  Future<dynamic> register({
    required String name,
    required String email,
    required String phoneCode,
    required String mobile,
    required String password,
    required String passwordConfirmation,
    required String firebaseToken,
  }) async =>
      registerBody;

  @override
  Future<dynamic> socialLogin({
    required String provider,
    required String idToken,
    required String firebaseToken,
  }) async =>
      socialLoginBody;
}
```

Then add this new group at the end of `main()`, after the existing `group('AuthRepositoryImpl.register', ...)` block (as a sibling, still inside the outer `void main() { ... }`):

```dart

  group('AuthRepositoryImpl.socialLoginWithGoogle', () {
    test('returns a session with null mobile for a brand-new Google account',
        () async {
      const envelope = {
        'status': 200,
        'message': 'User data',
        'errors': <String, dynamic>{},
        'data': {
          'id': 90,
          'name': 'Abdallah',
          'email': 'abdallah@gmail.com',
          'mobile': null,
          'phonecode': null,
          'status': 'Active',
          'avatar': '',
          'api_token': 'tok123',
          'is_profile_completed': false,
        },
      };

      final repo = AuthRepositoryImpl(_FakeAuthApi(socialLoginBody: envelope));

      final session = await repo.socialLoginWithGoogle(
        idToken: 'google-id-token',
        firebaseToken: 'device-token',
      );

      expect(session.token, 'tok123');
      expect(session.user?.mobile, isNull);
      expect(session.user?.isProfileCompleted, isFalse);
    });

    test('throws ApiException on an error envelope', () async {
      const envelope = {
        'status': 401,
        'message': 'Invalid Google token',
        'errors': <String, dynamic>{},
        'data': <String, dynamic>{},
      };

      final repo = AuthRepositoryImpl(_FakeAuthApi(socialLoginBody: envelope));

      await expectLater(
        repo.socialLoginWithGoogle(
          idToken: 'bad-token',
          firebaseToken: 'device-token',
        ),
        throwsA(isA<ApiException>()),
      );
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

```powershell
flutter test test/features/auth/data/auth_repository_impl_test.dart
```

Expected: FAIL to compile — `socialLogin`/`socialLoginWithGoogle` are not defined.

- [ ] **Step 3: Add `socialLoginWithGoogle` to the domain interface**

Open `lib/features/auth/domain/repositories/auth_repository.dart`. Find the closing brace of the interface (after `resetPassword`'s signature) and insert before it:

```dart
  /// Signs in (or creates an account) via a Google ID token, hitting
  /// `POST /auth/social-login`. Returns the same envelope shape as [login].
  /// New accounts created this way have no phone on file yet — check
  /// `session.user?.isProfileCompleted`; when `false`, route to the
  /// phone-completion flow instead of straight into the app.
  Future<AuthSession> socialLoginWithGoogle({
    required String idToken,
    required String firebaseToken,
  });
```

So the file ends:

```dart
  Future<void> resetPassword({
    required String phoneCode,
    required String mobile,
    required String code,
    required String password,
    required String passwordConfirmation,
  });

  /// Signs in (or creates an account) via a Google ID token, hitting
  /// `POST /auth/social-login`. Returns the same envelope shape as [login].
  /// New accounts created this way have no phone on file yet — check
  /// `session.user?.isProfileCompleted`; when `false`, route to the
  /// phone-completion flow instead of straight into the app.
  Future<AuthSession> socialLoginWithGoogle({
    required String idToken,
    required String firebaseToken,
  });
}
```

- [ ] **Step 4: Add the transport method to `AuthApi`**

Open `lib/features/auth/data/auth_api.dart`. Find the closing brace of the class (after `resetPassword`) and insert before it:

```dart

  Future<dynamic> socialLogin({
    required String provider,
    required String idToken,
    required String firebaseToken,
  }) async {
    final res = await _dio.post(
      '/auth/social-login',
      data: FormData.fromMap({
        'provider': provider,
        'id_token': idToken,
        'firebase_token': firebaseToken,
      }),
    );
    return res.data;
  }
```

- [ ] **Step 5: Implement in `AuthRepositoryImpl`**

Open `lib/features/auth/data/auth_repository_impl.dart`. Find:

```dart
  void _ensureSuccessEnvelope(dynamic body) {
```

Insert a new method directly above it (right after the closing brace of `resetPassword`):

```dart
  @override
  Future<AuthSession> socialLoginWithGoogle({
    required String idToken,
    required String firebaseToken,
  }) {
    return _guard(() async {
      final envelope = await _api.socialLogin(
        provider: 'google',
        idToken: idToken,
        firebaseToken: firebaseToken,
      ) as Map<String, dynamic>;
      return _parseSession(envelope);
    });
  }

  void _ensureSuccessEnvelope(dynamic body) {
```

- [ ] **Step 6: Update `FakeAuthRepository` so all existing tests keep compiling**

Open `test/support/fake_auth_repository.dart`. Find the closing brace of the class (after `resetPassword`) and insert before it:

```dart

  @override
  Future<AuthSession> socialLoginWithGoogle({
    required String idToken,
    required String firebaseToken,
  }) async =>
      _session;
```

Also update the class doc comment from:

```dart
/// Minimal fake of [AuthRepository] for widget tests. Supports [login] and
/// [verifyOtp] (both return [_session]). All other methods throw
/// [UnimplementedError] — tests that need them should use a different fake.
```

to:

```dart
/// Minimal fake of [AuthRepository] for widget tests. Supports [login],
/// [verifyOtp], and [socialLoginWithGoogle] (all return [_session]). All
/// other methods throw [UnimplementedError] — tests that need them should
/// use a different fake.
```

- [ ] **Step 7: Run the test to verify it passes**

```powershell
flutter test test/features/auth/data/auth_repository_impl_test.dart
```

Expected: PASS (all tests, including the 2 new ones).

- [ ] **Step 8: Run the full auth test directory to confirm `FakeAuthRepository` didn't break anything**

```powershell
flutter test test/features/auth
```

Expected: PASS (no regressions from the `FakeAuthRepository`/interface change).

- [ ] **Step 9: Commit**

```powershell
git add lib/features/auth/domain/repositories/auth_repository.dart lib/features/auth/data/auth_api.dart lib/features/auth/data/auth_repository_impl.dart test/support/fake_auth_repository.dart test/features/auth/data/auth_repository_impl_test.dart
git commit -m "Add AuthRepository.socialLoginWithGoogle backend contract"
```

---

### Task 5: `GoogleSignInService`

**Files:**
- Create: `lib/features/auth/data/google_sign_in_service.dart`
- Modify: `lib/features/auth/presentation/providers/auth_providers.dart`
- Test: `test/features/auth/data/google_sign_in_service_test.dart` (new file)

**Interfaces:**
- Consumes: `AppConfig.googleWebClientId` (Task 1).
- Produces: `GoogleSignInService.signIn() → Future<String?>` (null on user cancel), `GoogleSignInService.signOut() → Future<void>`, `GoogleSignInFailure` exception, `googleSignInServiceProvider` — consumed by Task 11 (`handleGoogleSignIn`).

- [ ] **Step 1: Write the failing test**

Create `test/features/auth/data/google_sign_in_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:safaria/features/auth/data/google_sign_in_service.dart';

void main() {
  group('GoogleSignInService.mapCancellation', () {
    test('returns null for a canceled exception', () {
      const exception = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );

      expect(GoogleSignInService.mapCancellation(exception), isNull);
    });

    test('rethrows a GoogleSignInFailure for any other exception code', () {
      const exception = GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
        description: 'missing client id',
      );

      expect(
        () => GoogleSignInService.mapCancellation(exception),
        throwsA(
          isA<GoogleSignInFailure>().having(
            (e) => e.message,
            'message',
            'missing client id',
          ),
        ),
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```powershell
flutter test test/features/auth/data/google_sign_in_service_test.dart
```

Expected: FAIL to compile — `google_sign_in_service.dart` doesn't exist yet.

- [ ] **Step 3: Implement `GoogleSignInService`**

Create `lib/features/auth/data/google_sign_in_service.dart`:

```dart
import 'package:google_sign_in/google_sign_in.dart';

import 'package:safaria/core/config/app_config.dart';

/// Thrown by [GoogleSignInService.signIn] when Google Sign-In fails for a
/// reason other than the user cancelling (cancellation is reported as a
/// `null` return instead of an exception).
class GoogleSignInFailure implements Exception {
  const GoogleSignInFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin wrapper over the `google_sign_in` package so the repository/UI
/// layers never depend on the third-party SDK directly.
class GoogleSignInService {
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleWebClientId,
    );
    _initialized = true;
  }

  /// Runs the interactive Google sign-in flow and returns the ID token to
  /// send to the backend. Returns `null` if the user cancelled — callers
  /// should treat that as a silent no-op, not an error.
  Future<String?> signIn() async {
    await _ensureInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      return mapCancellation(e);
    }
  }

  Future<void> signOut() => GoogleSignIn.instance.signOut();

  /// Maps a [GoogleSignInException] to `null` when it represents user
  /// cancellation, or rethrows it as a [GoogleSignInFailure] otherwise.
  /// Extracted as a pure static function so it's testable without a real
  /// platform channel.
  static String? mapCancellation(GoogleSignInException e) {
    if (e.code == GoogleSignInExceptionCode.canceled) return null;
    throw GoogleSignInFailure(e.description ?? e.code.name);
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```powershell
flutter test test/features/auth/data/google_sign_in_service_test.dart
```

Expected: PASS (2 tests).

- [ ] **Step 5: Register the provider**

Open `lib/features/auth/presentation/providers/auth_providers.dart`. Add the import at the top, alongside the other feature imports:

```dart
import 'package:safaria/features/auth/data/google_sign_in_service.dart';
```

Then, directly below the existing `authRepositoryProvider` declaration:

```dart
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authApiProvider)),
);
```

add:

```dart

final googleSignInServiceProvider =
    Provider<GoogleSignInService>((ref) => GoogleSignInService());
```

- [ ] **Step 6: Commit**

```powershell
git add lib/features/auth/data/google_sign_in_service.dart lib/features/auth/presentation/providers/auth_providers.dart test/features/auth/data/google_sign_in_service_test.dart
git commit -m "Add GoogleSignInService wrapping the google_sign_in SDK"
```

---

### Task 6: `OtpPurpose.linkGoogleAccountPhone` + `OtpVerifyScreen` branch

**Files:**
- Modify: `lib/features/auth/domain/value/otp_purpose.dart`
- Modify: `lib/features/auth/presentation/otp_verify_screen.dart`
- Create: `test/support/fake_profile_repository.dart`
- Modify: `test/features/auth/otp_verify_screen_test.dart`

**Interfaces:**
- Consumes: `ProfileRepository.verifyAltPhone` (Task 3), `SessionController.updateUser` (existing), `profileRepositoryProvider` (existing, `lib/features/profile/presentation/providers/profile_providers.dart`).
- Produces: `OtpPurpose.linkGoogleAccountPhone` — consumed by Task 7 (`CompletePhoneScreen`) and Task 11 tests.

- [ ] **Step 1: Add the new enum value**

Open `lib/features/auth/domain/value/otp_purpose.dart`. Current content:

```dart
/// What an OTP screen is verifying. Controls which endpoints the OTP screen
/// calls and where it routes on success.
enum OtpPurpose {
  /// After Register or login when `need_verfication` is true: verifies the
  /// phone via `/auth/verify-otp`, which returns the authenticated session.
  registration,

  /// Inside the forgot-password flow: validates the reset code via
  /// `/auth/validate-otp`, then continues to the New-password screen.
  passwordReset,
}
```

Replace with:

```dart
/// What an OTP screen is verifying. Controls which endpoints the OTP screen
/// calls and where it routes on success.
enum OtpPurpose {
  /// After Register or login when `need_verfication` is true: verifies the
  /// phone via `/auth/verify-otp`, which returns the authenticated session.
  registration,

  /// Inside the forgot-password flow: validates the reset code via
  /// `/auth/validate-otp`, then continues to the New-password screen.
  passwordReset,

  /// Completing a Google sign-up that has no phone on file yet: verifies
  /// the code via the authenticated `/profile/verify-alt-phone`, attaching
  /// the phone to the already-signed-in account.
  linkGoogleAccountPhone,
}
```

- [ ] **Step 2: Create the `FakeProfileRepository` test double**

Create `test/support/fake_profile_repository.dart`:

```dart
import 'package:safaria/features/auth/domain/entities/auth_user.dart';
import 'package:safaria/features/profile/domain/repositories/profile_repository.dart';

/// Minimal fake of [ProfileRepository] for widget tests. [verifyAltPhone]
/// returns [_user]. All other methods throw [UnimplementedError] — tests
/// that need them should use a different fake.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository(this._user);

  final AuthUser _user;

  @override
  Future<AuthUser> fetchProfile() => throw UnimplementedError();

  @override
  Future<AuthUser> updateProfile({
    required int id,
    required String name,
    required String email,
    required String phoneCode,
    required String mobile,
    String? avatarPath,
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> verifyAltPhone({
    required String phoneCode,
    required String mobile,
    required String code,
  }) async =>
      _user;
}
```

- [ ] **Step 3: Write the failing widget test**

Open `test/features/auth/otp_verify_screen_test.dart`. Add these imports alongside the existing ones:

```dart
import 'package:safaria/features/profile/presentation/providers/profile_providers.dart';

import '../../support/fake_profile_repository.dart';
```

Then add this new `testWidgets` block after the existing one, inside `main()`:

```dart

  testWidgets(
      'verifying a Google phone-link OTP updates the user and navigates to returnTo',
      (tester) async {
    const session = AuthSession(token: 't', user: AuthUser(name: 'Abdallah'));
    const updatedUser = AuthUser(
      name: 'Abdallah',
      mobile: '1012345678',
      phoneCode: '20',
      isProfileCompleted: true,
    );
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(storage: InMemorySecureStorage({})),
        ),
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository(updatedUser),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(guestModeProvider.future);
    await container
        .read(sessionControllerProvider.notifier)
        .setSession(session);

    final router = GoRouter(
      initialLocation: AppRoutes.otp,
      routes: [
        GoRoute(
          path: AppRoutes.otp,
          builder: (context, state) => const OtpVerifyScreen(
            args: OtpArgs(
              phoneCode: '20',
              mobile: '1012345678',
              purpose: OtpPurpose.linkGoogleAccountPhone,
              returnTo: BusRoutes.confirm,
            ),
          ),
        ),
        GoRoute(
          path: BusRoutes.confirm,
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
    expect(
      container.read(sessionControllerProvider).value?.user?.mobile,
      '1012345678',
    );
  });
```

- [ ] **Step 4: Run the test to verify it fails**

```powershell
flutter test test/features/auth/otp_verify_screen_test.dart
```

Expected: FAIL — either a compile error (no `linkGoogleAccountPhone` handling yet is fine, the enum value itself compiles from Step 1) or the test hangs/errors because `OtpVerifyScreen._confirm()` doesn't have a branch for the new purpose (it currently only branches on `== OtpPurpose.registration` vs. else, so `linkGoogleAccountPhone` would incorrectly fall into the `passwordReset` branch and call `validateOtp` on `authRepositoryProvider`, which is not overridden in this test and would throw trying to hit a real Dio client).

- [ ] **Step 5: Implement the branch in `OtpVerifyScreen`**

Open `lib/features/auth/presentation/otp_verify_screen.dart`. Add this import alongside the existing ones:

```dart
import 'package:safaria/features/profile/presentation/providers/profile_providers.dart';
```

Replace the entire `_confirm` method:

```dart
  Future<void> _confirm() async {
    if (_code.length < _otpLength) {
      setState(() => _hasError = true);
      return;
    }

    setState(() => _submitting = true);
    final repo = ref.read(authRepositoryProvider);
    try {
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
      } else {
        await repo.validateOtp(
          phoneCode: widget.args.phoneCode,
          mobile: widget.args.mobile,
          code: _code,
        );
        if (!mounted) return;
        unawaited(
          context.push(
            AppRoutes.newPassword,
            extra: ResetArgs(
              phoneCode: widget.args.phoneCode,
              mobile: widget.args.mobile,
              code: _code,
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() => _hasError = true);
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
```

with:

```dart
  Future<void> _confirm() async {
    if (_code.length < _otpLength) {
      setState(() => _hasError = true);
      return;
    }

    setState(() => _submitting = true);
    try {
      switch (widget.args.purpose) {
        case OtpPurpose.registration:
          final session = await ref.read(authRepositoryProvider).verifyOtp(
                phoneCode: widget.args.phoneCode,
                mobile: widget.args.mobile,
                code: _code,
              );
          await ref
              .read(sessionControllerProvider.notifier)
              .setSession(session);
          await ref.read(guestModeProvider.notifier).disable();
          if (mounted) {
            context.go(widget.args.returnTo ?? AppRoutes.home);
          }
        case OtpPurpose.passwordReset:
          await ref.read(authRepositoryProvider).validateOtp(
                phoneCode: widget.args.phoneCode,
                mobile: widget.args.mobile,
                code: _code,
              );
          if (!mounted) return;
          unawaited(
            context.push(
              AppRoutes.newPassword,
              extra: ResetArgs(
                phoneCode: widget.args.phoneCode,
                mobile: widget.args.mobile,
                code: _code,
              ),
            ),
          );
        case OtpPurpose.linkGoogleAccountPhone:
          final user = await ref.read(profileRepositoryProvider).verifyAltPhone(
                phoneCode: widget.args.phoneCode,
                mobile: widget.args.mobile,
                code: _code,
              );
          await ref.read(sessionControllerProvider.notifier).updateUser(user);
          if (mounted) {
            context.go(widget.args.returnTo ?? AppRoutes.home);
          }
      }
    } on ApiException catch (e) {
      setState(() => _hasError = true);
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
```

- [ ] **Step 6: Run the test to verify it passes**

```powershell
flutter test test/features/auth/otp_verify_screen_test.dart
```

Expected: PASS (both tests in the file).

- [ ] **Step 7: Commit**

```powershell
git add lib/features/auth/domain/value/otp_purpose.dart lib/features/auth/presentation/otp_verify_screen.dart test/support/fake_profile_repository.dart test/features/auth/otp_verify_screen_test.dart
git commit -m "Add OtpPurpose.linkGoogleAccountPhone branch to OtpVerifyScreen"
```

---

### Task 7: `CompletePhoneScreen`

**Files:**
- Create: `lib/features/auth/presentation/complete_phone_screen.dart`
- Modify: `test/support/fake_auth_repository.dart` (make `sendOtp` succeed instead of throwing)
- Test: `test/features/auth/complete_phone_screen_test.dart` (new file)

**Interfaces:**
- Consumes: `AuthRepository.sendOtp` (existing), `CompleteProfileArgs` (Task 2), `OtpPurpose.linkGoogleAccountPhone` (Task 6), `AppRoutes.otp` (existing) — the route this screen pushes to, `AppRoutes.completeProfile` (added in Task 8; this screen doesn't reference it directly, but its route is wired there).
- Produces: `CompletePhoneScreen` widget — consumed by Task 8 (router).

- [ ] **Step 1: Update `FakeAuthRepository.sendOtp` to succeed**

Open `test/support/fake_auth_repository.dart`. Find:

```dart
  @override
  Future<void> sendOtp({required String phoneCode, required String mobile}) =>
      throw UnimplementedError();
```

Replace with:

```dart
  @override
  Future<void> sendOtp({
    required String phoneCode,
    required String mobile,
  }) async {}
```

Also update the class doc comment (from Task 4's edit) to mention it:

```dart
/// Minimal fake of [AuthRepository] for widget tests. Supports [login],
/// [verifyOtp], [socialLoginWithGoogle] (all return [_session]), and
/// [sendOtp] (succeeds as a no-op). All other methods throw
/// [UnimplementedError] — tests that need them should use a different fake.
```

Run the existing suite once to confirm this is a safe, non-breaking change:

```powershell
flutter test test/features/auth
```

Expected: PASS (no test currently asserts `sendOtp` throws).

- [ ] **Step 2: Write the failing widget test**

Create `test/features/auth/complete_phone_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/storage/secure_storage.dart';
import 'package:safaria/features/auth/domain/entities/auth_session.dart';
import 'package:safaria/features/auth/presentation/auth_flow_args.dart';
import 'package:safaria/features/auth/presentation/complete_phone_screen.dart';
import 'package:safaria/features/auth/presentation/otp_verify_screen.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/in_memory_secure_storage.dart';

void main() {
  testWidgets(
      'submitting a valid phone sends an OTP and pushes the OTP screen with returnTo carried through',
      (tester) async {
    const session = AuthSession(token: 't');
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(storage: InMemorySecureStorage({})),
        ),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(session)),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: AppRoutes.completeProfile,
      routes: [
        GoRoute(
          path: AppRoutes.completeProfile,
          builder: (context, state) {
            final args = state.extra;
            return CompletePhoneScreen(
              args: args is CompleteProfileArgs ? args : null,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.otp,
          builder: (context, state) {
            final args = state.extra;
            if (args is! OtpArgs) return const SizedBox.shrink();
            return Text(
              'OTP purpose=${args.purpose.name} '
              'phone=${args.phoneCode}${args.mobile} '
              'returnTo=${args.returnTo}',
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
      AppRoutes.completeProfile,
      extra: const CompleteProfileArgs(returnTo: '/car/confirm'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1012345678');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'OTP purpose=linkGoogleAccountPhone phone=201012345678 '
        'returnTo=/car/confirm',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows a validation error for an invalid phone and does not navigate',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(storage: InMemorySecureStorage({})),
        ),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: AppRoutes.completeProfile,
      routes: [
        GoRoute(
          path: AppRoutes.completeProfile,
          builder: (context, state) => const CompletePhoneScreen(),
        ),
        GoRoute(
          path: AppRoutes.otp,
          builder: (context, state) => const Text('OTP'),
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

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid phone number'), findsOneWidget);
    expect(find.text('OTP'), findsNothing);
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

```powershell
flutter test test/features/auth/complete_phone_screen_test.dart
```

Expected: FAIL to compile — `complete_phone_screen.dart` doesn't exist yet.

- [ ] **Step 4: Implement `CompletePhoneScreen`**

Create `lib/features/auth/presentation/complete_phone_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/core/utils/validators.dart';
import 'package:safaria/features/auth/domain/value/otp_purpose.dart';
import 'package:safaria/features/auth/presentation/auth_flow_args.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/auth/presentation/widgets/auth_card.dart';
import 'package:safaria/features/auth/presentation/widgets/auth_hero_layout.dart';
import 'package:safaria/features/auth/presentation/widgets/country_picker.dart';
import 'package:safaria/features/auth/presentation/widgets/phone_field.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Blocking step after a brand-new Google sign-up: the backend has no phone
/// on file for this account yet (`isProfileCompleted == false`), so the
/// router guard sends every signed-in-but-incomplete session here. There is
/// deliberately no back button — this mirrors the existing router guard
/// pattern (guest/login) rather than adding a new escape hatch.
class CompletePhoneScreen extends ConsumerStatefulWidget {
  const CompletePhoneScreen({super.key, this.args});

  final CompleteProfileArgs? args;

  @override
  ConsumerState<CompletePhoneScreen> createState() =>
      _CompletePhoneScreenState();
}

class _CompletePhoneScreenState extends ConsumerState<CompletePhoneScreen> {
  final _phone = TextEditingController();
  CountryCode _country = kDefaultCountry;
  bool _submitting = false;
  String? _phoneError;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryCodePicker(context);
    if (picked != null) setState(() => _country = picked);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _phoneError = Validators.isValidPhone(_phone.text) ? null : l10n.valPhone;
    });
    if (_phoneError != null) return;

    setState(() => _submitting = true);
    final mobile = Validators.digitsOnly(_phone.text);
    try {
      await ref.read(authRepositoryProvider).sendOtp(
            phoneCode: _country.dial,
            mobile: mobile,
          );
      if (!mounted) return;
      await context.push(
        AppRoutes.otp,
        extra: OtpArgs(
          phoneCode: _country.dial,
          mobile: mobile,
          purpose: OtpPurpose.linkGoogleAccountPhone,
          returnTo: widget.args?.returnTo,
        ),
      );
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppBreakpoints.maxContentWidth,
                    ),
                    child: AuthHeroLayout(
                      title: l10n.completeProfileTitle,
                      subtitle: l10n.completeProfileSubtitle,
                      child: AuthCard(
                        children: [
                          PhoneField(
                            controller: _phone,
                            country: _country,
                            onTapCountry: _pickCountry,
                            errorText: _phoneError,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                          ),
                          PrimaryButton(
                            label: l10n.commonConfirm,
                            loading: _submitting,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run the test — expect a route-not-found failure, not success yet**

```powershell
flutter test test/features/auth/complete_phone_screen_test.dart
```

Expected: FAIL — `AppRoutes.completeProfile` doesn't exist yet (Task 8), so this file won't compile (`AppRoutes.completeProfile` is referenced in the test). This is expected; Task 8 makes it pass. Confirm the failure is specifically about `AppRoutes.completeProfile`, not about `CompletePhoneScreen` itself (which should compile cleanly on its own).

- [ ] **Step 6: Commit**

```powershell
git add lib/features/auth/presentation/complete_phone_screen.dart test/support/fake_auth_repository.dart test/features/auth/complete_phone_screen_test.dart
git commit -m "Add CompletePhoneScreen for the Google phone-completion flow"
```

(This commit intentionally leaves `test/features/auth/complete_phone_screen_test.dart` red — Task 8 adds the missing route and turns it green. This is called out explicitly so the next task's implementer isn't surprised by a failing test at the start.)

---

### Task 8: Router — `AppRoutes.completeProfile` + redirect guard

**Files:**
- Modify: `lib/core/router/app_router.dart`
- Modify: `test/core/router/app_router_test.dart`

**Interfaces:**
- Consumes: `CompletePhoneScreen` (Task 7), `CompleteProfileArgs` (Task 2).
- Produces: `AppRoutes.completeProfile` (`'/complete-profile'`) — consumed by Task 7's test (already written) and Task 11.

- [ ] **Step 1: Write the failing router test**

Open `test/core/router/app_router_test.dart`. Add `import 'dart:convert';` as the first import in the file (before `import 'dart:io';`):

```dart
import 'dart:convert';
import 'dart:io';
```

Then add this new `testWidgets` block at the end of `main()`, after the last existing test:

```dart

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
```

- [ ] **Step 2: Run the test to verify it fails**

```powershell
flutter test test/core/router/app_router_test.dart
```

Expected: FAIL — either a compile error (`AppRoutes.completeProfile` not referenced here directly, so it should compile) or the assertion fails because the router currently sends this session straight to Home (`is_profile_completed: false` isn't handled yet).

- [ ] **Step 3: Add the route constant and `GoRoute`**

Open `lib/core/router/app_router.dart`. Add these imports alongside the existing `features/auth/presentation/...` imports:

```dart
import 'package:safaria/features/auth/presentation/complete_phone_screen.dart';
```

Find:

```dart
abstract final class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const otp = '/otp';
  static const forgotPassword = '/forgot-password';
  static const newPassword = '/new-password';
  static const home = '/';
  static const tickets = '/tickets';
  static const profile = '/profile';
}
```

Replace with:

```dart
abstract final class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const otp = '/otp';
  static const forgotPassword = '/forgot-password';
  static const newPassword = '/new-password';
  static const completeProfile = '/complete-profile';
  static const home = '/';
  static const tickets = '/tickets';
  static const profile = '/profile';
}
```

Find the `GoRoute` for `AppRoutes.newPassword` (it ends right before the `StatefulShellRoute.indexedStack` comment block):

```dart
      GoRoute(
        path: AppRoutes.newPassword,
        builder: (context, state) {
          final args = state.extra;
          if (args is! ResetArgs) return const LoginScreen();
          return NewPasswordScreen(args: args);
        },
      ),
      // Signed-in tab shell. Each tab is a branch with preserved state; the
```

Insert a new `GoRoute` between them:

```dart
      GoRoute(
        path: AppRoutes.newPassword,
        builder: (context, state) {
          final args = state.extra;
          if (args is! ResetArgs) return const LoginScreen();
          return NewPasswordScreen(args: args);
        },
      ),
      GoRoute(
        path: AppRoutes.completeProfile,
        builder: (context, state) {
          final args = state.extra;
          return CompletePhoneScreen(
            args: args is CompleteProfileArgs ? args : null,
          );
        },
      ),
      // Signed-in tab shell. Each tab is a branch with preserved state; the
```

- [ ] **Step 4: Update the redirect guard**

In the same file, find:

```dart
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

    // Signed-in users should not linger on auth screens; guests may open
    // login/register voluntarily (profile CTA, guest gate sheet).
    if (loggedIn && atAuthRoute && at != AppRoutes.splash) {
      return AppRoutes.home;
    }
    if (!allowedInApp && !atAuthRoute) {
      return AppRoutes.login;
    }
    return null;
  }
```

Replace with:

```dart
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

    // A Google sign-up with no phone on file yet: block everywhere except
    // the completion screen itself and the OTP screen it pushes to.
    final needsProfileCompletion =
        loggedIn && (session.value?.user?.isProfileCompleted ?? true) == false;
    final onCompleteProfileFlow =
        at == AppRoutes.completeProfile || at == AppRoutes.otp;
    if (needsProfileCompletion && !onCompleteProfileFlow) {
      return AppRoutes.completeProfile;
    }

    // Signed-in users should not linger on auth screens; guests may open
    // login/register voluntarily (profile CTA, guest gate sheet).
    if (loggedIn &&
        !needsProfileCompletion &&
        atAuthRoute &&
        at != AppRoutes.splash) {
      return AppRoutes.home;
    }
    if (!allowedInApp && !atAuthRoute) {
      return AppRoutes.login;
    }
    return null;
  }
```

- [ ] **Step 5: Run the router test to verify it passes**

```powershell
flutter test test/core/router/app_router_test.dart
```

Expected: PASS (all tests, including the new one).

- [ ] **Step 6: Run the `CompletePhoneScreen` test from Task 7 — it should now pass**

```powershell
flutter test test/features/auth/complete_phone_screen_test.dart
```

Expected: PASS (both tests).

- [ ] **Step 7: Run the full test suite to check for regressions**

```powershell
flutter test
```

Expected: PASS across the board (every response fixture in the codebase has `is_profile_completed: true`, so no existing flow is affected).

- [ ] **Step 8: Commit**

```powershell
git add lib/core/router/app_router.dart test/core/router/app_router_test.dart
git commit -m "Add /complete-profile route and router guard for incomplete Google sign-ups"
```

---

### Task 9: Localization keys

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ar.arb`

**Interfaces:**
- Produces: `l10n.googleSignInFailed`, `l10n.completeProfileTitle`, `l10n.completeProfileSubtitle` — consumed by Task 7 (already written against `completeProfileTitle`/`completeProfileSubtitle`) and Task 10 (`googleSignInFailed`).

- [ ] **Step 1: Add the English keys**

Open `lib/l10n/app_en.arb`. Find:

```json
  "authOrContinueWith": "or continue with",
  "authOrSignUpWith": "or sign up with",
  "socialComingSoon": "Social sign-in is coming soon",
```

Replace with:

```json
  "authOrContinueWith": "or continue with",
  "authOrSignUpWith": "or sign up with",
  "socialComingSoon": "Social sign-in is coming soon",
  "googleSignInFailed": "Google sign-in failed. Please try again.",
  "completeProfileTitle": "Complete your profile",
  "completeProfileSubtitle": "Add and verify your phone number to finish setting up your account.",
```

- [ ] **Step 2: Add the Arabic keys**

Open `lib/l10n/app_ar.arb`. Find the corresponding `authOrContinueWith`/`socialComingSoon` block (it's near the top of the file, mirroring the English one — search for `"socialComingSoon"` if the surrounding lines differ slightly from the English file's exact ordering) and add the three matching keys directly after it:

```json
  "googleSignInFailed": "فشل تسجيل الدخول عبر جوجل. حاول مرة أخرى.",
  "completeProfileTitle": "أكمل ملفك الشخصي",
  "completeProfileSubtitle": "أضف رقم هاتفك وتحقق منه لإتمام إعداد حسابك.",
```

If `app_ar.arb` doesn't already have `authOrContinueWith`/`socialComingSoon` keys at all (some ARB files only carry translated keys and rely on English fallback — verify by searching the file first with the Grep tool for `"socialComingSoon"`), instead add the three new keys directly after the `"registerSignIn"` line, matching the same relative position used in `app_en.arb`.

- [ ] **Step 3: Regenerate localizations**

```powershell
flutter gen-l10n
```

Expected: completes with no errors (no missing-translation warnings for the 3 new keys, since both files were updated).

- [ ] **Step 4: Run `flutter analyze` to confirm the generated code is consistent**

```powershell
flutter analyze lib/l10n
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```powershell
git add lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "Add localization keys for Google sign-in and profile completion"
```

(Do not commit `lib/l10n/app_localizations*.dart` — confirm via `git status` that they're gitignored, per `localization.mdc`.)

---

### Task 10: Wire the Google button — `SocialRow`, shared flow helper, Login/Register screens

**Files:**
- Modify: `lib/features/auth/presentation/widgets/social_row.dart`
- Create: `lib/features/auth/presentation/google_sign_in_flow.dart`
- Modify: `lib/features/auth/presentation/login_screen.dart`
- Modify: `lib/features/auth/presentation/register_screen.dart`
- Modify: `test/features/auth/login_screen_test.dart`
- Create: `test/features/auth/register_screen_test.dart`

**Interfaces:**
- Consumes: `GoogleSignInService`/`googleSignInServiceProvider` (Task 5), `AuthRepository.socialLoginWithGoogle` (Task 4), `AppRoutes.completeProfile` (Task 8), `CompleteProfileArgs` (Task 2), `AppConfig.isGoogleSignInConfigured` (Task 1).
- Produces: `SocialRow.onGoogleTap`/`SocialRow.busy` (renamed/added), `handleGoogleSignIn(...)` — this is the last task; nothing downstream consumes it.

- [ ] **Step 1: Update `SocialRow`**

Open `lib/features/auth/presentation/widgets/social_row.dart`. Replace the entire file:

```dart
import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/shared/widgets/brand_mark.dart';

/// "or continue with" divider plus the Google sign-in button.
class SocialRow extends StatelessWidget {
  const SocialRow({
    super.key,
    required this.dividerLabel,
    required this.onGoogleTap,
    this.busy = false,
  });

  final String dividerLabel;
  final VoidCallback onGoogleTap;

  /// True while a Google sign-in is in flight — shows a spinner on the
  /// button and ignores taps instead of firing [onGoogleTap] again.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.hairline)),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + AppSpacing.xs,
              ),
              child: Text(
                dividerLabel,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const Expanded(child: Divider(color: AppColors.hairline)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: _SocialButton(BrandMark.google, onGoogleTap, busy)),
          ],
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton(this.asset, this.onTap, this.busy);

  final String asset;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.input);
    return Material(
      color: AppColors.bgCard,
      borderRadius: radius,
      child: InkWell(
        key: const Key('googleSignInButton'),
        borderRadius: radius,
        onTap: busy ? null : onTap,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppColors.hairline),
          ),
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : BrandMark(asset, size: 26),
        ),
      ),
    );
  }
}
```

The `Key('googleSignInButton')` gives widget tests a stable, unambiguous
finder for the Google button regardless of how many other `InkWell`s exist
elsewhere on the screen.

- [ ] **Step 2: Create the shared `handleGoogleSignIn` flow**

Create `lib/features/auth/presentation/google_sign_in_flow.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/config/app_config.dart';
import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/storage/secure_storage.dart';
import 'package:safaria/features/auth/presentation/auth_flow_args.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Shared "Continue with Google" orchestration used by both [LoginScreen]
/// and [RegisterScreen] — Google auth resolves to the same
/// login-or-create-account backend call regardless of which screen the
/// button was tapped from.
Future<void> handleGoogleSignIn({
  required BuildContext context,
  required WidgetRef ref,
  required AuthGateArgs? gateArgs,
  required ValueChanged<bool> setBusy,
}) async {
  final l10n = AppLocalizations.of(context);

  if (!AppConfig.isGoogleSignInConfigured) {
    _snack(context, l10n.googleSignInFailed);
    return;
  }

  setBusy(true);
  try {
    final idToken = await ref.read(googleSignInServiceProvider).signIn();
    if (idToken == null) return; // user cancelled — no error to show

    final firebaseToken =
        await ref.read(secureStorageProvider).readOrCreateDeviceToken();
    final session =
        await ref.read(authRepositoryProvider).socialLoginWithGoogle(
              idToken: idToken,
              firebaseToken: firebaseToken,
            );
    await ref.read(sessionControllerProvider.notifier).setSession(session);
    await ref.read(guestModeProvider.notifier).disable();
    if (!context.mounted) return;

    if (session.user?.isProfileCompleted == true) {
      context.go(gateArgs?.returnTo ?? AppRoutes.home);
    } else {
      context.go(
        AppRoutes.completeProfile,
        extra: CompleteProfileArgs(returnTo: gateArgs?.returnTo),
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) _snack(context, e.message);
  } catch (_) {
    if (context.mounted) _snack(context, l10n.googleSignInFailed);
  } finally {
    setBusy(false);
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
```

- [ ] **Step 3: Wire `LoginScreen`**

Open `lib/features/auth/presentation/login_screen.dart`. Add the import alongside the other feature imports:

```dart
import 'package:safaria/features/auth/presentation/google_sign_in_flow.dart';
```

Add a new field next to the other `bool` fields in `_LoginScreenState`:

```dart
  bool _submitting = false;
```

becomes:

```dart
  bool _submitting = false;
  bool _socialSubmitting = false;
```

Replace the `SocialRow` usage:

```dart
                                SocialRow(
                                  dividerLabel: l10n.authOrContinueWith,
                                  onDisabledTap: () =>
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              l10n.socialComingSoon,
                                            ),
                                          ),
                                        ),
                                ),
```

with:

```dart
                                SocialRow(
                                  dividerLabel: l10n.authOrContinueWith,
                                  busy: _socialSubmitting,
                                  onGoogleTap: () => handleGoogleSignIn(
                                    context: context,
                                    ref: ref,
                                    gateArgs: widget.gateArgs,
                                    setBusy: (v) =>
                                        setState(() => _socialSubmitting = v),
                                  ),
                                ),
```

Update the primary submit button so it's disabled while a Google sign-in is in flight too. Find:

```dart
                                PrimaryButton(
                                  label: l10n.loginButton,
                                  loading: _submitting,
                                  onPressed: _submit,
                                ),
```

Replace with:

```dart
                                PrimaryButton(
                                  label: l10n.loginButton,
                                  loading: _submitting,
                                  onPressed: _socialSubmitting ? null : _submit,
                                ),
```

Update the guest button similarly. Find:

```dart
                                PrimaryButton(
                                  label: l10n.authContinueGuest,
                                  variant: PrimaryButtonVariant.ghost,
                                  onPressed:
                                      _submitting ? null : _continueAsGuest,
                                ),
```

Replace with:

```dart
                                PrimaryButton(
                                  label: l10n.authContinueGuest,
                                  variant: PrimaryButtonVariant.ghost,
                                  onPressed: (_submitting || _socialSubmitting)
                                      ? null
                                      : _continueAsGuest,
                                ),
```

- [ ] **Step 4: Wire `RegisterScreen`**

Open `lib/features/auth/presentation/register_screen.dart`. Add the import:

```dart
import 'package:safaria/features/auth/presentation/google_sign_in_flow.dart';
```

Add the field next to the other `bool` fields in `_RegisterScreenState`:

```dart
  bool _submitting = false;
```

becomes:

```dart
  bool _submitting = false;
  bool _socialSubmitting = false;
```

Replace the `SocialRow` usage:

```dart
                  SocialRow(
                    dividerLabel: l10n.authOrSignUpWith,
                    onDisabledTap: () => ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(content: Text(l10n.socialComingSoon)),
                      ),
                  ),
```

with:

```dart
                  SocialRow(
                    dividerLabel: l10n.authOrSignUpWith,
                    busy: _socialSubmitting,
                    onGoogleTap: () => handleGoogleSignIn(
                      context: context,
                      ref: ref,
                      gateArgs: widget.gateArgs,
                      setBusy: (v) => setState(() => _socialSubmitting = v),
                    ),
                  ),
```

Update the primary submit button. Find:

```dart
            PrimaryButton(
              label: l10n.registerButton,
              loading: _submitting,
              onPressed: _submit,
            ),
```

Replace with:

```dart
            PrimaryButton(
              label: l10n.registerButton,
              loading: _submitting,
              onPressed: _socialSubmitting ? null : _submit,
            ),
```

- [ ] **Step 5: Write the failing tests for `LoginScreen`**

Open `test/features/auth/login_screen_test.dart`. Add these imports alongside the existing ones:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:safaria/features/auth/data/google_sign_in_service.dart';
```

Add a `setUpAll` at the top of `main()` (before the `pumpLogin` helper definition):

```dart
void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'GOOGLE_WEB_CLIENT_ID=test-client-id');
  });

  Future<ProviderContainer> pumpLogin(
```

(This only changes indentation/wraps the existing `Future<ProviderContainer> pumpLogin(` declaration inside `main()` — the body of `pumpLogin` is unchanged.)

Add this small fake class near the top of the file, right after the imports and before `void main()`:

```dart
class _FakeGoogleSignInService extends GoogleSignInService {
  _FakeGoogleSignInService(this._idToken);

  final String? _idToken;

  @override
  Future<String?> signIn() async => _idToken;
}
```

Then add these three new `testWidgets` blocks at the end of `main()`, after the existing `'language button opens the language picker sheet'` test:

```dart

  testWidgets(
      'Google sign-in for an existing, complete account navigates to returnTo',
      (tester) async {
    const session = AuthSession(
      token: 'g-token',
      user: AuthUser(
        mobile: '1012345678',
        phoneCode: '20',
        isProfileCompleted: true,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(storage: InMemorySecureStorage({})),
        ),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(session)),
        googleSignInServiceProvider.overrideWithValue(
          _FakeGoogleSignInService('a-google-id-token'),
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
          path: BusRoutes.confirm,
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
      extra: const AuthGateArgs(returnTo: BusRoutes.confirm),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pumpAndSettle();

    expect(find.text('CONFIRM'), findsOneWidget);
    expect(container.read(guestModeProvider).value, isFalse);
  });

  testWidgets(
      'Google sign-in for a brand-new account navigates to Complete profile',
      (tester) async {
    const session = AuthSession(
      token: 'g-token',
      user: AuthUser(isProfileCompleted: false),
    );
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(storage: InMemorySecureStorage({})),
        ),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(session)),
        googleSignInServiceProvider.overrideWithValue(
          _FakeGoogleSignInService('a-google-id-token'),
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
          path: AppRoutes.completeProfile,
          builder: (context, state) => const Text('COMPLETE PROFILE'),
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

    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pumpAndSettle();

    expect(find.text('COMPLETE PROFILE'), findsOneWidget);
  });

  testWidgets('cancelling Google sign-in shows no error and stays on Login',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(storage: InMemorySecureStorage({})),
        ),
        googleSignInServiceProvider.overrideWithValue(
          _FakeGoogleSignInService(null),
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

    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
```

- [ ] **Step 6: Run the `LoginScreen` tests to verify the new ones pass**

```powershell
flutter test test/features/auth/login_screen_test.dart
```

Expected: PASS (all tests in the file, old and new). Steps 3–4 already wired `LoginScreen` to `handleGoogleSignIn`/`SocialRow.onGoogleTap`, so no further code changes should be needed here — this step is verification.

- [ ] **Step 7: Write `RegisterScreen`'s Google-flow test**

Create `test/features/auth/register_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/storage/secure_storage.dart';
import 'package:safaria/core/theme/app_theme.dart';
import 'package:safaria/features/auth/data/google_sign_in_service.dart';
import 'package:safaria/features/auth/domain/entities/auth_session.dart';
import 'package:safaria/features/auth/domain/entities/auth_user.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/auth/presentation/register_screen.dart';
import 'package:safaria/l10n/app_localizations.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/in_memory_secure_storage.dart';

class _FakeGoogleSignInService extends GoogleSignInService {
  _FakeGoogleSignInService(this._idToken);

  final String? _idToken;

  @override
  Future<String?> signIn() async => _idToken;
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'GOOGLE_WEB_CLIENT_ID=test-client-id');
  });

  testWidgets(
      'Google sign-in for an existing, complete account navigates Home',
      (tester) async {
    const session = AuthSession(
      token: 'g-token',
      user: AuthUser(
        mobile: '1012345678',
        phoneCode: '20',
        isProfileCompleted: true,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(storage: InMemorySecureStorage({})),
        ),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(session)),
        googleSignInServiceProvider.overrideWithValue(
          _FakeGoogleSignInService('a-google-id-token'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(guestModeProvider.future);

    final router = GoRouter(
      initialLocation: AppRoutes.register,
      routes: [
        GoRoute(
          path: AppRoutes.register,
          builder: (context, state) => const RegisterScreen(),
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

    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
  });
}
```

- [ ] **Step 8: Run the new test to verify it passes**

```powershell
flutter test test/features/auth/register_screen_test.dart
```

Expected: PASS.

- [ ] **Step 9: Run the full test suite**

```powershell
flutter test
```

Expected: PASS across the board.

- [ ] **Step 10: Commit**

```powershell
git add lib/features/auth/presentation/widgets/social_row.dart lib/features/auth/presentation/google_sign_in_flow.dart lib/features/auth/presentation/login_screen.dart lib/features/auth/presentation/register_screen.dart test/features/auth/login_screen_test.dart test/features/auth/register_screen_test.dart
git commit -m "Wire the Google button on Login/Register to real Google Sign-In"
```

---

### Task 11: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Run static analysis**

```powershell
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 2: Run the full test suite**

```powershell
flutter test
```

Expected: all tests PASS, zero failures.

- [ ] **Step 3: Run `dart format` and confirm no diffs**

```powershell
dart format --output=none --set-exit-if-changed .
```

Expected: exits 0 (already formatted, since every code block above followed the 80-column/trailing-comma conventions). If it reports files needing formatting, run `dart format .` and re-run Step 2.

- [ ] **Step 4: Manual smoke check (documented, not automatable here)**

Note for whoever runs this on a device: with `GOOGLE_WEB_CLIENT_ID` still empty in a local `.env`, tapping "Continue with Google" should show the `googleSignInFailed` snackbar without crashing. Full end-to-end Google sign-in cannot be verified until: (a) a real Google Cloud/Firebase OAuth Web client ID is set in `.env`, (b) the SHA-1 fingerprint is registered for the debug/release keystore, and (c) the backend team has implemented `POST /auth/social-login` per this plan's contract. These three are explicitly out of scope for this implementation plan (see the design spec's "Out of scope" section).

- [ ] **Step 5: Final commit (if Step 3 required formatting fixes)**

```powershell
git add -A
git commit -m "Apply dart format after Google sign-in feature work"
```

(Skip this commit if Step 3 reported no changes.)
