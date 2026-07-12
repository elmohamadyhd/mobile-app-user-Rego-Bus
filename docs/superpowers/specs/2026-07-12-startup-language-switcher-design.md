# Startup Language Switcher — Design

**Date:** 2026-07-12
**Status:** Approved

## Problem

`LocaleController` (`lib/core/providers/locale_controller.dart`) already supports
switching between Arabic and English, persists the choice to secure storage, and
drives both `MaterialApp.locale` and the Dio `Accept-Language` header. But no UI
anywhere calls it — the Profile screen's "Language" row shows a "Coming Soon"
toast instead. Users cannot change the app language from onboarding or login
(the two screens shown at app start), or anywhere else.

## Goal

Add a language switcher reachable from the app's start screens (onboarding,
login) and fix the dead Profile "Language" row to use the same picker. No
changes to `LocaleController` itself — this is purely UI wiring onto existing,
working state.

## Non-goals

- No "follow device language" option in the picker. Only two supported
  languages exist; an explicit choice is clearer than a third "auto" state.
- No new ARB strings for the language names themselves — language names are
  shown as autonyms (`العربية`, `English`), which are constants, not translated
  strings.
- No changes to splash screen — it is a ~2s branded animation that
  auto-routes onward with no interactive surface.

## Design

### 1. `showLanguagePickerSheet` — shared bottom sheet

New file: `lib/shared/widgets/language_picker_sheet.dart`.

Follows the existing `showCountryCodePicker` pattern
(`lib/features/auth/presentation/widgets/country_picker.dart`): a top-level
function that opens a modal bottom sheet, no `ref` parameter needed since the
sheet itself is a `Consumer`.

```dart
Future<void> showLanguagePickerSheet(BuildContext context)
```

Sheet contents:
- Title: `l10n.profileMenuLanguage` ("Language" / "اللغة") — reuses the
  existing key, no new strings needed.
- Two rows, each showing the language's autonym:
  - `العربية` → `Locale('ar')`
  - `English` → `Locale('en')`
- A checkmark (or equivalent selected-state styling) on whichever row matches
  `ref.watch(localeControllerProvider).languageCode`.
- Tapping a row (that isn't already selected) calls
  `ref.read(localeControllerProvider.notifier).setLocale(Locale(code))` and
  pops the sheet. Tapping the already-selected row just closes the sheet.
- Styled per the Skyline system (`AppColors`, `AppTypography`, `AppSpacing`),
  matching the visual weight of `country_picker.dart`'s sheet.

Changing the locale rebuilds `MaterialApp` (`lib/app.dart`) with the new
`locale`, which flips text and `TextDirection` (RTL/LTR) app-wide
automatically — no manual direction handling needed.

### 2. `LanguageIconButton` — trigger widget

New file: `lib/shared/widgets/language_icon_button.dart`.

A small `IconButton`-style widget using `AppIcons.language` (globe icon),
accepting an optional `color` so it can be styled correctly against both
light backgrounds (onboarding) and the blue hero gradient (login). On tap,
calls `showLanguagePickerSheet(context)`.

### 3. Wiring into existing screens

- **Onboarding** (`lib/features/auth/presentation/onboarding_screen.dart`):
  add `LanguageIconButton` to the existing top `Row`/`Align` alongside the
  "Skip" button, positioned at `AlignmentDirectional.centerEnd`, colored
  `AppColors.textSecondary` to match the Skip button's tone.
- **Login** (`lib/features/auth/presentation/login_screen.dart`): overlay a
  `LanguageIconButton` top-trailing on the blue hero via `Stack` + `SafeArea`
  + `PositionedDirectional(top, end)`, colored `AppColors.onHero` (white) to
  read against the gradient.
- **Profile** (`lib/features/profile/presentation/profile_screen.dart:55`):
  change the "Language" `_ProfileMenuItem.onTap` from
  `_showComingSoon(context, l10n)` to `showLanguagePickerSheet(context)`.
  Remove `_showComingSoon` if it becomes unused after this change.

## Testing

Widget tests following existing conventions under `test/features/auth/` and
`test/features/profile/`:

- `language_picker_sheet_test.dart`: sheet renders both language rows with
  correct autonyms; the active locale's row shows the selected state; tapping
  the other row updates `localeControllerProvider` state to the new locale
  and closes the sheet.
- Onboarding screen test: `LanguageIconButton` is present and opens the sheet
  on tap.
- Login screen test: `LanguageIconButton` is present and opens the sheet on
  tap.
- Profile screen test: tapping the "Language" row opens the sheet (replacing
  any existing "Coming Soon" toast assertion).

## Verification

`flutter analyze && flutter test`. This app is mobile-only (Android/iOS) —
no browser-based UI verification; manual on-device/emulator check of the
RTL/LTR flip and persistence across app restart is recommended after
implementation.
