# Google Login/Sign-Up — Design Spec

**Date:** 2026-07-29
**Scope:** Wire the existing "Continue with Google" button (currently a
"coming soon" stub) on Login and Register into a real Google Sign-In flow,
including the new-account phone-completion step.

---

## Context

Auth in this app is entirely phone + password against the Wadeny backend
(`/auth/login`, `/auth/register`, OTP endpoints). There is no email/username
login. `SocialRow` already renders a Google button on both `LoginScreen` and
`RegisterScreen`, but tapping it only shows a "coming soon" snackbar
(`socialComingSoon`).

The Wadeny backend (`docs/wadeny-apis.md`, `docs/Wadeny.postman_collection.json`)
has **no** Google/OAuth endpoint today — only the 8 phone/password auth
endpoints. The `firebase_token` field sent on `/auth/register` is not
Firebase Authentication; it's a locally generated device UUID used as an FCM
push-token placeholder (`SecureStorage.readOrCreateDeviceToken`).

`AuthUser.isProfileCompleted` already exists in the model and is round-tripped
from every backend response, but nothing in the app currently branches on it —
every real response observed has it `true`. This field is the intended hook
for an account that exists but is missing required info (e.g. a phone
number), and this feature is the first consumer of it.

No `ios/` project exists yet (`pubspec.yaml` has `flutter_native_splash.ios:
false`), so this feature targets **Android only**.

---

## Decisions (approved)

| Topic | Choice |
|-------|--------|
| Backend contract | New endpoint `POST /auth/social-login`; mobile designs the contract now, backend team implements to match |
| New-account phone gap | Blocking "Complete your profile" step (collect phone + OTP verify) before entering the app, reusing existing phone-field/OTP UI |
| Client SDK | `google_sign_in` package only — no `firebase_auth`/`firebase_core` (nothing else in the app uses Firebase) |
| Google Cloud/Firebase project | Not yet created — app reads the client ID from env and degrades gracefully if unset; user will create the project and hand over the Web client ID later |
| Platforms | Android only (no `ios/` project exists) |

---

## 1. Backend contract (new)

```
POST /auth/social-login
Content-Type: multipart/form-data   (matches every other /auth/* endpoint)

Body:
  provider        "google"                (fixed today; leaves room for future providers)
  id_token        <Google ID token>
  firebase_token  <device push token>     (same value/semantics as /auth/register's firebase_token)

Headers: Accept: application/json, Accept-Language: ar|en   (same as other /auth/* calls)

Response: identical envelope shape to /auth/login and /auth/register
{
  "status": 200,
  "message": "...",
  "errors": {},
  "data": {
    "id": 75,
    "name": "abdallah",           // from the Google profile
    "email": "abdallah@gmail.com",// from the Google profile
    "mobile": null,               // null when this Google account has no phone on file yet
    "phonecode": null,
    "status": "Active",
    "avatar": "",
    "api_token": "<bearer token>",
    "is_profile_completed": false // false exactly when mobile/phonecode are null
  }
}
```

- On the **first** sign-in with a given Google account, the backend creates
  the user record from the Google profile (name, email) with no phone, and
  returns `is_profile_completed: false`.
- On a **repeat** sign-in (existing Google-linked account, or an email match
  against an existing phone-registered account — a backend-side decision out
  of scope here), the backend returns the full profile with
  `is_profile_completed: true` as normal.
- This reuses the exact envelope `AuthResponseDto`/`AuthRepositoryImpl`
  already parse; `mobile`/`phonecode`/`name`/`email` are already nullable in
  both `AuthResponseDto` and `AuthUser`, so **no entity changes are needed**.

---

## 2. Mobile package & config additions

- Add `google_sign_in: ^7.2.0` to `pubspec.yaml` (current major version; API
  is `GoogleSignIn.instance.initialize(serverClientId: ...)` +
  `.authenticate()`, returning a `GoogleSignInAccount` whose
  `authentication.idToken` is sent to the backend).
- `.env.example` / `AppConfig` gets a new `GOOGLE_WEB_CLIENT_ID` var
  (empty-string default, mirroring `googleMapsApiKey`) plus
  `AppConfig.isGoogleSignInConfigured` (`googleWebClientId.isNotEmpty`).
- When not configured, the Google button still renders (no layout shift) but
  tapping it shows a snackbar explaining Google sign-in isn't set up yet,
  instead of attempting to initialize the SDK and crashing.
- No `firebase_core`/`firebase_auth` dependency.
- Android manifest / Gradle changes needed for `google_sign_in_android` are
  standard plugin wiring (no custom Kotlin patch expected, unlike
  `url_launcher_android`) — verified during implementation.

---

## 3. Data / domain layer

### `AuthRepository` (domain interface)

New method alongside the existing ones:

```dart
Future<AuthSession> socialLoginWithGoogle({
  required String idToken,
  required String firebaseToken,
});
```

`AuthRepositoryImpl` implements it exactly like `login`: call
`AuthApi.socialLogin(...)`, guard with `_guard`, parse with the existing
`_parseSession` (already tolerant of null `mobile`/`phonecode`).

`AuthApi` gets a matching transport method posting `FormData` to
`/auth/social-login`, following the same shape as `login`/`register`.

### `GoogleSignInService` (new, `features/auth/data/google_sign_in_service.dart`)

Thin wrapper isolating the third-party SDK from the repository/UI layers:

```dart
class GoogleSignInService {
  Future<String?> signIn(); // returns the Google ID token, or null if the user cancelled
  Future<void> signOut();
}
```

Internally initializes `GoogleSignIn.instance` once (idempotent) with
`serverClientId: AppConfig.googleWebClientId`, calls `.authenticate()`, and
maps SDK cancellation/errors: cancellation → `null`; any other
`GoogleSignInException`/platform error → rethrown as a small typed
`GoogleSignInFailure` exception so the caller can distinguish "user backed
out" (silent) from "something broke" (show an error).

### `ProfileRepository` (domain interface)

New method:

```dart
Future<AuthUser> verifyAltPhone({
  required String phoneCode,
  required String mobile,
  required String code,
});
```

Implemented via a new `ProfileApi.verifyAltPhone(...)` POSTing JSON to the
existing, already-documented, Bearer-authenticated
`/profile/verify-alt-phone` (`{ mobile, phonecode, code }`), parsed into an
`AuthUser` the same way `fetchProfile`/`updateProfile` do.

---

## 4. Presentation flow

### Google button wiring

`SocialRow.onDisabledTap` is renamed to `onGoogleTap` (it is the only button
rendered today) with an updated doc comment. `LoginScreen` and
`RegisterScreen` each wire it to a shared `_handleGoogleSignIn()` that:

1. Guards on `AppConfig.isGoogleSignInConfigured`; if false, shows the
   existing "coming soon"-style snackbar and returns.
2. Sets a `_socialSubmitting` flag (disables the phone/password submit button
   and the Google button together, mirroring the existing `_submitting`
   pattern) and calls `GoogleSignInService.signIn()`.
   - `null` (user cancelled) → clear the flag, do nothing else.
3. Calls `ref.read(authRepositoryProvider).socialLoginWithGoogle(idToken:
   ..., firebaseToken: await secureStorage.readOrCreateDeviceToken())`.
4. On success: `sessionController.setSession(session)`,
   `guestModeProvider.notifier.disable()` — identical to the existing
   phone-login success path.
5. Branch on `session.user?.isProfileCompleted`:
   - `true` → `context.go(widget.gateArgs?.returnTo ?? AppRoutes.home)`
     (same as today).
   - `false`/`null` → `context.go(AppRoutes.completeProfile, extra:
     CompleteProfileArgs(returnTo: widget.gateArgs?.returnTo))`.
6. `ApiException` → snackbar with `e.message` (same pattern as
   `_applyErrors`'s fallback branch). `GoogleSignInFailure`/other → snackbar
   with new l10n key `googleSignInFailed`.
7. `finally` clears `_socialSubmitting`.

### New `CompletePhoneScreen`

`lib/features/auth/presentation/complete_phone_screen.dart` — visually
consistent with Login/Register (`AuthHeroLayout`, `AuthCard`, `PhoneField`,
`PrimaryButton`), collecting only a phone number (name/email already came
from Google). On submit:

1. Validate via the existing `Validators.isValidPhone`.
2. Call `ref.read(authRepositoryProvider).sendOtp(phoneCode, mobile)` — the
   existing public endpoint, reused as-is.
3. `context.push(AppRoutes.otp, extra: OtpArgs(phoneCode: ..., mobile: ...,
   purpose: OtpPurpose.linkGoogleAccountPhone, returnTo: ...))`.

New route `AppRoutes.completeProfile = '/complete-profile'`, builder reads
`state.extra as CompleteProfileArgs?`. New arg class `CompleteProfileArgs
{ final String? returnTo; }` added to `auth_flow_args.dart`.

### `OtpPurpose` / `OtpVerifyScreen` — third branch

```dart
enum OtpPurpose {
  registration,
  passwordReset,
  linkGoogleAccountPhone, // new
}
```

`OtpVerifyScreen._confirm()` gets a third branch: for
`linkGoogleAccountPhone`, call `ref.read(profileRepositoryProvider)
.verifyAltPhone(phoneCode: ..., mobile: ..., code: _code)`, then
`ref.read(sessionControllerProvider.notifier).updateUser(user)` (existing
method — keeps the current bearer token, replaces the cached user), then
`context.go(widget.args.returnTo ?? AppRoutes.home)`. `_resend()` already
calls the shared, purpose-agnostic `resendOtp`, so it needs no change. No new
copy: `otpTitle`/`otpSubtitle` ("Enter verification code" / "We sent a
4-digit code to") are already generic enough to cover this case.

### Router guard (`app_router.dart`)

`AppRoutes.completeProfile` is added as a route (not added to the existing
`_authRoutes` set, since it applies to *logged-in* users). The redirect gains
one more branch, checked before the existing ones:

```dart
final needsProfileCompletion =
    loggedIn && (session.value?.user?.isProfileCompleted ?? true) == false;
final onCompleteProfileFlow =
    at == AppRoutes.completeProfile || at == AppRoutes.otp;

if (needsProfileCompletion && !onCompleteProfileFlow) {
  return AppRoutes.completeProfile;
}
if (loggedIn && !needsProfileCompletion && atAuthRoute && at != AppRoutes.splash) {
  return AppRoutes.home;
}
// ...existing guest/login branch unchanged...
```

Every real response observed today has `is_profile_completed: true`, so
existing phone login/register/guest flows are unaffected. `/otp` is
deliberately exempt from the "needs completion" redirect since it's also
used mid-flow by `linkGoogleAccountPhone` while the session is already set.

---

## 5. Error handling

- Google SDK cancellation is silent (no snackbar) — matches standard
  "Continue with Google" UX elsewhere.
- Any other Google SDK failure (misconfiguration, network, platform
  exception) surfaces a snackbar with the new `googleSignInFailed` l10n key.
- `/auth/social-login` and `/profile/verify-alt-phone` failures reuse the
  existing `ApiException`/envelope parsing — no new error-handling
  infrastructure.
- If `AppConfig.isGoogleSignInConfigured` is false (no client ID set yet),
  tapping the button never touches the SDK — no crash risk before the Google
  Cloud project exists.

---

## 6. Testing

- `AuthRepositoryImpl.socialLoginWithGoogle` — unit test mirroring
  `auth_repository_impl_test.dart`'s existing `login`/`register` cases
  (success with `is_profile_completed: false`/`true`, `ApiException` on
  failure).
- `ProfileRepositoryImpl.verifyAltPhone` — unit test alongside existing
  profile repository tests.
- `GoogleSignInService` — a test verifying cancellation maps to `null`
  without throwing (SDK calls themselves are not unit-testable without a
  platform channel fake, so this stays thin by design).
- Router guard — extend/add a router test asserting
  `is_profile_completed: false` redirects to `/complete-profile`, and that
  `/otp` and `/complete-profile` are exempt.
- Widget tests: `LoginScreen`/`RegisterScreen` Google button triggers the
  flow (fake `AuthRepository`/`GoogleSignInService`) and `CompletePhoneScreen`
  validates + navigates, following `login_screen_test.dart`'s existing
  patterns.

---

## Out of scope

- iOS Google Sign-In setup (no `ios/` project exists).
- Apple/Facebook social buttons — remain "coming soon".
- Creating the actual Google Cloud/Firebase project or registering the SHA-1
  fingerprint — the app reads the client ID from env and degrades gracefully
  until that exists.
- Backend implementation of `/auth/social-login` and any account-linking
  logic (matching a Google email against an existing phone-registered
  account) — this spec defines the contract the mobile app expects; the
  backend team builds/owns the server-side logic.
- Signing out of the underlying Google session on app logout (can reuse
  `GoogleSignInService.signOut()` later if the backend ever needs a fresh
  Google consent; not needed for this feature to work).
