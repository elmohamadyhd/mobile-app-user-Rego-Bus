# Profile Settings Screen — Design

**Date:** 2026-08-10  
**Status:** Approved

## Problem

The My Account (profile) tab exposes a **Language** row that opens the shared
language picker, and a **Settings** row that only shows a “coming soon”
snackbar. Language belongs under Settings; Settings itself has no real screen.

## Goal

Ship a minimal Settings screen under the profile feature. Move language into
it (remove the top-level Language row). Reuse the existing picker sheet and
`LocaleController` — no new persistence or API.

## Non-goals

- Theme / dark mode, notification preferences, account security, Help content
- New `features/settings/` slice
- Replacing or redesigning `showLanguagePickerSheet`
- New packages or backend work
- Changing language entry points on onboarding / login (`LanguageIconButton`)

## Decisions

| Topic | Choice |
|-------|--------|
| Scope (v1) | Language only |
| Language UX | Row opens existing bottom sheet |
| Current value | Trailing autonym (`العربية` / `English`) |
| Ownership | Profile feature, pushed route |
| Guests | Settings available (no auth gate) |

## Design

### 1. Navigation

- Add `ProfileRoutes.settings` = `/profile/settings`
- Register a `GoRoute` in `profile_routes.dart` → `SettingsScreen`
- Profile menu: **Settings** → `context.push(ProfileRoutes.settings)`
- Remove the profile **Language** menu item and its
  `showLanguagePickerSheet` import from `profile_screen.dart`
- Help remains “coming soon” on the profile menu

### 2. `SettingsScreen`

New file: `lib/features/profile/presentation/settings_screen.dart`

- `Scaffold` + existing `ProfileAppBar` titled with `l10n.profileMenuSettings`
- Body: `SafeArea` + scrollable content; constrain to
  `AppBreakpoints.maxContentWidth` and center on wider windows
- One Skyline menu card (same visual language as `_ProfileMenuCard` on
  profile: card radius, shadow, icon tile chrome)
- Single row:
  - Icon: `PhosphorIconsLight.translate`
  - Label: `l10n.profileMenuLanguage`
  - Trailing: current language autonym from
    `ref.watch(localeControllerProvider).languageCode` (`ar` → `العربية`,
    else `English`), muted secondary style, plus caret
  - Tap → `showLanguagePickerSheet(context)`
- Tokens only: `AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`
- RTL: `EdgeInsetsDirectional`; caret treatment matches the existing profile
  menu tiles (same icon / layout as `_ProfileMenuTile`)
- No domain / repository / new providers

Optional polish (only if it avoids messy duplication): extract a small
profile menu tile that supports an optional trailing value. Prefer a local
Settings tile over a speculative shared widget if extraction is unclear.

### 3. i18n

- Reuse `profileMenuSettings` and `profileMenuLanguage` (already in
  `app_en.arb` / `app_ar.arb`)
- Language names remain autonyms — no new ARB keys for `العربية` / `English`
- No hardcoded user-facing English/Arabic copy in widgets beyond those
  autonyms (same as the existing picker)

### 4. Tests

- Update `test/features/profile/profile_screen_test.dart`:
  - Drop / rewrite “tapping Language opens the language picker sheet”
  - Assert Settings is present; Language is not a top-level profile row
  - Prefer asserting navigation to settings when the test harness can do so
    cleanly; otherwise assert Settings no longer shows the coming-soon snackbar
- Add `test/features/profile/settings_screen_test.dart`:
  - Shows Language row and current autonym for the active locale
  - Tap Language opens the picker sheet
- Leave `language_picker_sheet_test.dart` unchanged

## File layout

```
lib/features/profile/presentation/
  settings_screen.dart          # new
  profile_routes.dart           # add settings route
  profile_screen.dart           # wire Settings; remove Language row

test/features/profile/
  profile_screen_test.dart      # update
  settings_screen_test.dart     # new
```

## Error handling

None beyond existing picker / locale behavior. Settings has no network calls.

## Success criteria

1. Profile menu has Settings, not Language
2. Settings screen shows Language with the active autonym
3. Tapping Language opens the existing sheet; switching locale updates the
   trailing value and app direction as today
4. Guests can open Settings and change language
5. Relevant profile/settings widget tests pass under `Locale('ar')` at minimum
