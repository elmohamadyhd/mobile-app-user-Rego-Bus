# Delete Account (Settings) — Design

**Date:** 2026-08-10  
**Status:** Approved

## Problem

Settings currently only exposes language. Riders need a way to permanently
delete their account via the live API (`DELETE /profile`), with a strong
confirmation and a clean return to login (token cleared).

## Goal

Add **Delete account** to the Settings screen (signed-in users only). After a
typed confirmation, call `DELETE /profile`. On success, clear the session
token and navigate to login. On failure, keep the user signed in and show an
error.

## Non-goals

- Soft-delete / grace period / “download my data”
- Re-auth with password or OTP before delete
- Changing logout behavior elsewhere
- New feature slice (`features/settings/`) — stays under `profile`
- Redesigning language settings

## Decisions

| Topic | Choice |
|-------|--------|
| Confirmation | Type localized word to enable Delete (`DELETE` / `حذف`) |
| Placement | Same Settings card as Language; second destructive row |
| Guests | Hide Delete account |
| Ownership | Profile API → repository → Settings UI |
| Success | `sessionController.logout()` then `context.go(AppRoutes.login)` |
| Failure | Do not clear token; show localized error |

## API

- **Method / path:** `DELETE /profile`
- **Auth:** Existing Dio bearer interceptor
- **Success envelope (example):**
  ```json
  {
    "status": 200,
    "message": "Account deleted",
    "errors": {},
    "data": {}
  }
  ```
- Treat inner `status == 200` as success (same pattern as other profile
  envelope checks). Non-200 / Dio errors → `ApiException`.

## Design

### 1. Data layer

- `ProfileApi.deleteAccount()` → `_dio.delete('/profile')`, return body
- `ProfileRepository.deleteAccount()` → `Future<void>`; guard Dio →
  `ApiException`; verify envelope status 200
- No new providers required beyond existing `profileRepositoryProvider`

### 2. Settings UI

- Language row unchanged
- When **not** a guest (`guestModeProvider != true`) **and** a session exists
  (`sessionControllerProvider` has a value): show Delete account row in the
  same card
  - Icon: `PhosphorIconsLight.trash`
  - Destructive colors matching profile Log out tile
  - Label: `settingsDeleteAccount`
- Guests: Language only

### 3. Confirmation dialog

- Title / body / instruction from l10n (permanent delete warning)
- Show the required confirm word from l10n (`settingsDeleteAccountConfirmWord`)
  — English `DELETE`, Arabic `حذف`
- Text field; Delete enabled only when trimmed input **exactly equals** the
  confirm word (case-sensitive for Latin)
- Cancel dismisses; Delete runs the API
- While in flight: disable field + actions; show loading on Delete
- Skyline chrome: `AppRadius.card`, `AppTypography`, `AppColors` (error for
  destructive action)

### 4. Success / failure

- **Success:** pop dialog → `await ref.read(sessionControllerProvider.notifier).logout()` → `context.go(AppRoutes.login)`
- **Failure:** snackbar (or inline dialog error) with localized message /
  `ApiException` text; session remains; user can retry or cancel

### 5. i18n

Add to both `app_en.arb` and `app_ar.arb` (with `@` metadata on EN):

| Key | EN (intent) | AR (intent) |
|-----|-------------|-------------|
| `settingsDeleteAccount` | Delete account | حذف الحساب |
| `settingsDeleteAccountTitle` | Delete account? | حذف الحساب؟ |
| `settingsDeleteAccountMessage` | This permanently deletes your account and cannot be undone. | سيتم حذف حسابك نهائيًا ولا يمكن التراجع عن ذلك. |
| `settingsDeleteAccountTypePrompt` | Type {word} to confirm | اكتب {word} للتأكيد |
| `settingsDeleteAccountConfirmWord` | DELETE | حذف |
| `settingsDeleteAccountCancel` | Cancel | إلغاء |
| `settingsDeleteAccountConfirm` | Delete | حذف |
| `settingsDeleteAccountFailed` | Couldn't delete account | تعذر حذف الحساب |

Use ICU placeholder `{word}` in the type prompt.

### 6. Tests

- `profile_repository_impl_test`: delete success / non-200 / Dio error
- `settings_screen_test`: guest hides Delete; signed-in shows it; confirm
  button disabled until word matches; success path clears session and routes
  to login (fake repo + fake session + GoRouter harness)
- Pump under `Locale('ar')` at least for confirm-word / guest-hide coverage

## File layout

```
lib/features/profile/data/profile_api.dart
lib/features/profile/domain/repositories/profile_repository.dart
lib/features/profile/data/profile_repository_impl.dart
lib/features/profile/presentation/settings_screen.dart
lib/l10n/app_en.arb
lib/l10n/app_ar.arb

test/features/profile/data/profile_repository_impl_test.dart
test/features/profile/settings_screen_test.dart
```

## Success criteria

1. Signed-in Settings shows Delete account under Language in one card
2. Guests do not see Delete account
3. Delete stays disabled until the locale confirm word matches exactly
4. Successful `DELETE /profile` clears the token/session and lands on login
5. Failed delete leaves the user signed in and shows an error
6. Relevant tests pass (EN + AR coverage for the confirm word)
