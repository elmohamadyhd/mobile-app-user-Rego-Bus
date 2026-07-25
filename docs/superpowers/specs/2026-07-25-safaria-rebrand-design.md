# Safaria Full Rebrand — Design Spec

**Date:** 2026-07-25  
**Status:** Approved  
**Scope:** Rename app from REGO/ReGo to Safaria across user-facing strings, visual wordmarks, Dart package identity, and Android application ID.

## Goal

Rebrand the rider mobile app to **Safaria** — matching the `demo.safaria.travel` backend domain — in a single atomic change set with no mixed intermediate state.

## In scope

| Layer | From | To |
|-------|------|-----|
| Launcher / system title | `ReGo` | `Safaria` |
| In-app title & copy | `REGO` | `Safaria` |
| Dart package | `rego` | `safaria` |
| Android applicationId | `com.example.rego` | `com.safaria.travel` |
| Hero/splash wordmark image | `rego-wordmark-white.png` | `safaria-wordmark-white.png` (placeholder) |

Pin/icon artwork (`new-logo-white.svg`, native splash pin, launcher icons) stays unchanged.

## User-facing strings

All `REGO` mentions in `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb` become `Safaria`. Brand name stays Latin in Arabic strings (BiDi pattern unchanged).

Keys affected: `appTitle`, `homeWelcome`, `onboarding3Body`, `registerSubtitle`, `tripDetailOpenMapsBody`, `tripDetailOpenMapsStopBody`, `eTicketShareSubject`.

Hardcoded fallback in `passenger_confirm_screen.dart`: `'REGO Buses'` → `'Safaria'`.

## Visual wordmark

Add placeholder `assets/safaria-wordmark-white.png`. Update references in `splash_screen.dart` and `gradient_hero.dart`. No native-splash regen (pin image unchanged).

## Dart package rename

- `pubspec.yaml` name: `safaria`
- Bulk replace `package:rego/` → `package:safaria/` in `lib/` and `test/`
- Update `l10n.yaml`, `CLAUDE.md`, `.cursor/rules/dart-style.mdc`, `.cursor/rules/localization.mdc`

## Android

- `namespace` and `applicationId`: `com.safaria.travel`
- `android:label`: `Safaria`
- Move `MainActivity.kt` to `com/safaria/travel/`

**Side effect:** New applicationId = fresh install on devices (secure storage cleared, onboarding re-shown). Acceptable pre-release.

## Out of scope

- iOS bundle ID (no `ios/` folder)
- Git repo / workspace folder rename
- Historical docs under `docs/superpowers/` and `design/V1/`
- Backend domain references (already `safaria.travel`)
- Non-user-facing design-token doc comments

## Verification

```bash
./tool/pub-get.ps1
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter analyze
flutter test
```

## Risks

| Risk | Mitigation |
|------|------------|
| Missed `package:rego` import | Ripgrep verify zero matches |
| Android build breaks | Confirm MainActivity path matches namespace |
| Placeholder wordmark rough | Swap when brand assets arrive |
| Fresh install from new applicationId | Note in release notes |
