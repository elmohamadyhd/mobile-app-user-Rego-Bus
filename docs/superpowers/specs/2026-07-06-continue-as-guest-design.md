# Continue as a Guest — Design Spec

**Date:** 2026-07-06
**Feature:** Guest entry from the login screen, free browsing, and a sign-in wall before payment.
**Package:** `rego` (REGO Buses / Wadeny — Arabic-first, RTL, "Skyline" design)

---

## 1. Summary

Add a **"Continue as a guest"** path so a user can enter the app from the login
screen without an account, browse freely (home, search, trip results, trip
details, seat selection, passenger review), and only hit a sign-in wall at the
**confirm-&-pay** step.

The long-term intent is **full guest checkout** (book + pay identified by phone,
no account). The backend does not support anonymous booking yet, so this spec
delivers the **guest entry + browsing + a clean sign-in wall right before
payment**. Button and gate copy still promise the full experience for when the
backend lands. Guest checkout, guest payment identity, and a persistent
"browsing as guest" banner are **out of scope**.

---

## 2. Decisions locked during brainstorming

- **Scope:** guest entry + free browsing now; sign-in wall at payment.
- **Entry point:** a ghost/outlined button directly under the primary Sign-in
  button on the login screen (chosen over a bottom text link or a hero "skip"
  chip — it reads as a first-class choice with the clearest hierarchy).
- **Sign-in wall:** a **bottom sheet** over the booking summary, triggered by the
  confirm-&-pay tap (chosen over a full-screen interstitial — keeps context,
  feels light, easy to dismiss and keep browsing).
- **Guest-state representation:** a **separate persisted `guestMode` flag** next
  to the existing session (chosen over a sealed `AppAuth` refactor or a sentinel
  `token = "guest"` session).

---

## 3. Architecture

### 3.1 Guest state (the core mechanism)

`SessionController` (`AsyncNotifier<AuthSession?>`) is unchanged — a token always
means a real authenticated session. Guest mode is a separate, persisted boolean.

- **`SecureStorage`** — add a `guest_mode` key and:
  - `Future<bool> isGuestMode()` → reads `guest_mode == 'true'`
  - `Future<void> setGuestMode()` → writes `'true'`
  - `Future<void> clearGuestMode()` → deletes the key
- **`GuestController extends Notifier<bool>`** in
  `lib/features/auth/presentation/providers/auth_providers.dart`:
  - `build()` restores the persisted flag on launch.
  - `enable()` → `setGuestMode()` + `state = true`.
  - `disable()` → `clearGuestMode()` + `state = false`.
  - Exposed as `guestModeProvider`.

> **Restore-on-launch note:** the router guard reads guest mode synchronously.
> Restore the persisted flag during app bootstrap (alongside the session) so the
> first guard pass sees the correct value. If `Notifier.build()` cannot read
> storage synchronously, seed the flag in `main()` before `runApp` (same place
> the session is warmed) and have `build()` return the seeded value. The plan
> must confirm the guard never runs before the flag is known.

### 3.2 Auth transitions clear guest mode

A real account supersedes guest browsing. On **successful login and successful
register**, call `guestModeProvider.notifier.disable()` right after
`setSession(...)`. `SessionController.logout()` also clears guest mode (defensive;
a logged-in user isn't a guest, but keep the two flags from drifting).

### 3.3 Router & splash

- **`_RouterNotifier`** (`app_router.dart`) also listens to `guestModeProvider`
  so the guard re-runs when guest mode changes:
  ```
  final isGuest = _ref.read(guestModeProvider);
  final allowedInApp = loggedIn || isGuest;
  ```
  - `allowedInApp && atAuthRoute && at != splash` → `home`
  - `!allowedInApp && !atAuthRoute` → `login`
  - The `login`, `register`, `otp`, `forgotPassword`, `newPassword` routes stay
    in `_authRoutes` and remain reachable **on top of** the app for a guest who
    chooses to sign in (see §3.5 resume).
- **`splash_screen.dart`** decision order becomes:
  1. session token present → `home`
  2. **else guest mode → `home`**
  3. else `onboardingSeen` → `login`
  4. else → `onboarding`

### 3.4 Entry point — login screen button

In `login_screen.dart`, add a secondary action beneath the primary Sign-in
button (inside the pinned `bottom` column, above the "no account / sign up" row):

- Visual: outlined/ghost, primary-blue border + text, same 54px height and
  `AppRadius.input` as `PrimaryButton`, full width.
- Implementation: add a **`PrimaryButtonVariant.ghost`** (outline, transparent
  fill, primary border/label, no glow) to the existing `PrimaryButton` rather
  than hand-rolling a one-off widget. Keeps one button component.
- Action: `ref.read(guestModeProvider.notifier).enable()` → `context.go(home)`.
- Label: `l10n.authContinueGuest`.

### 3.5 The sign-in wall (bottom sheet) + resume

**Widget:** `showGuestGate(BuildContext context, {required String returnTo})` — a
helper in the auth feature (e.g.
`lib/features/auth/presentation/widgets/guest_gate_sheet.dart`) that calls
`showModalBottomSheet` with a rounded-top sheet styled per the approved mockup:

- Grabber handle, amber lock badge (`AppColors.secondaryTint` + lock icon).
- Title `guestGateTitle`, body `guestGateBody`.
- **Sign in** — primary `PrimaryButton`.
- **Create account** — ghost `PrimaryButton`.
- Green reassurance row `guestGateReassure` ("your booking is saved").
- Dismissible (tap scrim / drag down) → returns to the summary, still a guest.

**Trigger:** in `passenger_confirm_screen.dart`, the confirm-&-pay button's
`onPressed` checks guest mode:

```
onPressed: isLoading ? null : () {
  if (ref.read(guestModeProvider)) {
    showGuestGate(context, returnTo: AppRoutes.tripConfirm);
  } else {
    ref.read(bookingFlowProvider.notifier).confirmBooking();
  }
}
```

**Resume (handles the guard gotcha):**

- The gate's **Sign in** / **Create account** buttons `context.push` the
  `login` / `register` route with `extra: AuthGateArgs(returnTo: AppRoutes.tripConfirm)`.
  (New `AuthGateArgs` class in `auth_flow_args.dart`.)
- On **successful auth**, the login/register screen checks for `AuthGateArgs`:
  - if present → `context.go(args.returnTo)` (back to the confirm screen)
  - else → existing default `context.go(home)`
- Why this works: the guard redirects an auth route → home the instant a session
  appears (`app_router.dart:204`). Navigating explicitly to `tripConfirm` (a
  non-auth route) with a live session is **allowed** by the guard, so there is no
  fight. Because `bookingFlowProvider` is a plain `NotifierProvider` (not
  `autoDispose`, `booking_providers.dart:139`), the booking selection is intact
  and the confirm screen rebuilds with it. The now-authenticated user taps pay
  and `confirmBooking()` proceeds normally.
- Guest mode is cleared by the auth-success path (§3.2), so the confirm screen no
  longer treats them as a guest.

> **Edge case:** if the user dismisses the sheet without authenticating, they
> stay on the confirm screen as a guest — no state change. The gate can be
> reopened by tapping pay again.

### 3.6 Profile in guest mode

`profile_screen.dart` already renders a null user gracefully (name falls back to
`l10n.profileGuest`). Two guest-mode adjustments:

- Replace the **Log out** card with a **"Sign in / Create account"** CTA card
  when `guestModeProvider` is true. Tapping it runs the same auth entry (push
  `login` with `AuthGateArgs(returnTo: AppRoutes.profile)` so they land back on
  Profile, now authenticated).
- Leave the menu items as-is (they already show "coming soon").

---

## 4. Data flow

```
Login screen ── tap "Continue as guest" ──▶ guestMode = true ──▶ go(home)
                                                    │
        guard: loggedIn || isGuest ⇒ browsing allowed (home, search, trips…)
                                                    │
Passenger confirm ── tap pay ──▶ isGuest? ──yes──▶ showGuestGate(returnTo)
                                     │no                     │
                              confirmBooking()      push login/register(AuthGateArgs)
                                                              │
                                              auth success ⇒ setSession + guestMode=false
                                                              │
                                                    go(returnTo = tripConfirm)
                                                              │
                                         confirm screen (booking intact) ⇒ pay ⇒ eTicket
```

---

## 5. Copy / localization

New ARB keys (add to both `app_ar.arb` and `app_en.arb`), Arabic-first tone
matching existing auth copy.

| Key | Arabic (`app_ar.arb`) | English (`app_en.arb`) |
|-----|----------------------|------------------------|
| `authContinueGuest` | المتابعة كضيف | Continue as a guest |
| `guestGateTitle` | خطوة أخيرة قبل الدفع | One step before payment |
| `guestGateBody` | سجّل الدخول أو أنشئ حساباً لتأكيد حجزك وإتمام الدفع بأمان. | Sign in or create an account to confirm your booking and pay securely. |
| `guestGateSignIn` | تسجيل الدخول | Sign in |
| `guestGateCreate` | أنشئ حساباً | Create account |
| `guestGateReassure` | حجزك محفوظ — لن تفقد مقاعدك | Your booking is saved — you won't lose your seats |
| `profileGuestSignInCta` | سجّل الدخول أو أنشئ حساباً | Sign in or create an account |

> `guestGateSignIn` / `guestGateCreate` may reuse existing `loginButton` /
> `loginSignUp` values if the plan prefers not to add duplicates; keep separate
> keys only if the gate wording should diverge.

---

## 6. Error handling

- **Auth failure inside the gate flow:** login/register keep their existing
  inline-error + snackbar behavior. The user stays on the auth screen; on
  cancel/back they return to the sheet's origin (confirm screen) still a guest.
- **Guest flag persistence failure:** if `setGuestMode()` write fails, still flip
  the in-memory `state = true` so the current session works; persistence is a
  best-effort convenience, not a correctness requirement for the live session.
- **Deep link / relaunch as guest:** splash reads the persisted flag (§3.3) so a
  returning guest lands on home, not login.

---

## 7. Files touched

**New**
- `lib/features/auth/presentation/widgets/guest_gate_sheet.dart` — `showGuestGate` + sheet UI.

**Modified**
- `lib/core/storage/secure_storage.dart` — `guest_mode` key + accessors.
- `lib/features/auth/presentation/providers/auth_providers.dart` — `GuestController` + `guestModeProvider`; clear guest on login; `logout()` clears guest.
- `lib/features/auth/presentation/auth_flow_args.dart` — `AuthGateArgs`.
- `lib/features/auth/presentation/login_screen.dart` — ghost guest button; `AuthGateArgs`-aware success nav.
- `lib/features/auth/presentation/register_screen.dart` — `AuthGateArgs`-aware success nav.
- `lib/features/auth/presentation/splash_screen.dart` — guest branch in routing.
- `lib/shared/widgets/primary_button.dart` — `PrimaryButtonVariant.ghost`.
- `lib/core/router/app_router.dart` — guard listens to guest mode; `allowedInApp` logic.
- `lib/features/booking/presentation/passenger_confirm_screen.dart` — gate on pay when guest.
- `lib/features/profile/presentation/profile_screen.dart` — guest CTA replaces logout.
- `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb` — new keys.

**Codegen:** none of the new code uses `@freezed`/`@riverpod`/`@JsonSerializable`
(providers are hand-written like the existing ones), so no `build_runner` run is
required beyond the ARB → `AppLocalizations` regeneration (`flutter gen-l10n` /
build). Confirm during planning.

---

## 8. Testing

- **Login button (widget test):** guest button renders under Sign in; tap sets
  `guestModeProvider == true` and navigates to home.
- **Guard (unit/widget test):** with `guestMode == true` and no session, a guest
  is allowed on `home`/`search`/`trips` and is not bounced to `login`; with both
  false, non-auth routes redirect to `login`.
- **Gate trigger (widget test):** on the confirm screen as a guest, tapping pay
  opens the bottom sheet and does **not** call `confirmBooking()`.
- **Resume (widget/integration test):** from the gate, completing auth clears
  guest mode, lands on the confirm screen, and the booking selection is intact.
- **Profile (widget test):** in guest mode the logout card is replaced by the
  sign-in CTA.
- **Regression:** an authenticated user's confirm-&-pay still calls
  `confirmBooking()` directly (no gate).

---

## 9. Out of scope

- Backend guest booking + guest payment identity (phone-only checkout).
- A persistent "you're browsing as guest" banner/indicator across the app.
- Migrating an in-progress guest booking's passenger details into the created
  account (beyond what `bookingFlowProvider` already holds in memory).
