# Startup Language Switcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users switch between Arabic and English from the app's start screens (onboarding, login), and fix the dead Profile "Language" row — all by wiring UI onto the already-working `LocaleController`.

**Architecture:** One shared bottom-sheet widget (`showLanguagePickerSheet`) drives `localeControllerProvider.setLocale()`. A small reusable `LanguageIconButton` opens it. `GradientHero`/`AuthHeroLayout` gain an optional `topEnd` slot so the button can sit on the login hero without restructuring `LoginScreen`'s body.

**Tech Stack:** Flutter, Riverpod (`Notifier`/`ConsumerWidget`), existing Skyline design tokens (`AppColors`, `AppTypography`, `AppSpacing`), `flutter_test`.

**Spec:** [`docs/superpowers/specs/2026-07-12-startup-language-switcher-design.md`](../specs/2026-07-12-startup-language-switcher-design.md)

---

## Task 1: Language picker bottom sheet

**Files:**
- Create: `lib/shared/widgets/language_picker_sheet.dart`
- Test: `test/shared/widgets/language_picker_sheet_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/core/providers/locale_controller.dart';
import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/language_picker_sheet.dart';

void main() {
  Future<ProviderContainer> pumpSheetHarness(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(memoryLocaleStore: {}),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showLanguagePickerSheet(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('shows both languages with a check mark on the active one',
      (tester) async {
    await pumpSheetHarness(tester);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('العربية'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.byIcon(AppIcons.check), findsOneWidget);
  });

  testWidgets('tapping a language updates the locale and closes the sheet',
      (tester) async {
    final container = await pumpSheetHarness(tester);
    expect(container.read(localeControllerProvider).languageCode, 'en');

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    expect(find.text('العربية'), findsNothing);
    expect(container.read(localeControllerProvider).languageCode, 'ar');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/language_picker_sheet_test.dart`
Expected: FAIL — `Error: Error when reading 'lib/shared/widgets/language_picker_sheet.dart': No such file or directory.` (or an unresolved-import compile error for `showLanguagePickerSheet`).

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/core/providers/locale_controller.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/l10n/app_localizations.dart';

class _LanguageOption {
  const _LanguageOption(this.locale, this.autonym);

  final Locale locale;
  final String autonym;
}

const _kLanguageOptions = [
  _LanguageOption(Locale('ar'), 'العربية'),
  _LanguageOption(Locale('en'), 'English'),
];

/// Bottom sheet for switching the app language between Arabic and English.
/// Applies the pick immediately via [localeControllerProvider], which also
/// persists it to secure storage.
Future<void> showLanguagePickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (context) => const _LanguagePickerSheet(),
  );
}

class _LanguagePickerSheet extends ConsumerWidget {
  const _LanguagePickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(localeControllerProvider).languageCode;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(l10n.profileMenuLanguage, style: AppTypography.h2),
            ),
          ),
          for (final option in _kLanguageOptions)
            ListTile(
              title: Text(option.autonym, style: AppTypography.title),
              trailing: option.locale.languageCode == current
                  ? const Icon(AppIcons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                if (option.locale.languageCode != current) {
                  ref
                      .read(localeControllerProvider.notifier)
                      .setLocale(option.locale);
                }
                Navigator.of(context).pop();
              },
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/language_picker_sheet_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/language_picker_sheet.dart test/shared/widgets/language_picker_sheet_test.dart
git commit -m "feat(shared): add language picker bottom sheet"
```

---

## Task 2: Language icon button

**Files:**
- Create: `lib/shared/widgets/language_icon_button.dart`
- Test: `test/shared/widgets/language_icon_button_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/language_icon_button.dart';

void main() {
  testWidgets('tapping the button opens the language picker sheet',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(body: LanguageIconButton()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(LanguageIconButton));
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/language_icon_button_test.dart`
Expected: FAIL — unresolved import / `LanguageIconButton` undefined.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/shared/widgets/language_picker_sheet.dart';

/// Globe icon button that opens [showLanguagePickerSheet] on tap. Used on
/// the app's start screens (onboarding, login) to switch languages.
class LanguageIconButton extends StatelessWidget {
  const LanguageIconButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(AppIcons.language, color: color),
      onPressed: () => showLanguagePickerSheet(context),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/language_icon_button_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/language_icon_button.dart test/shared/widgets/language_icon_button_test.dart
git commit -m "feat(shared): add language icon button trigger"
```

---

## Task 3: Wire into Onboarding screen

**Files:**
- Modify: `lib/features/auth/presentation/onboarding_screen.dart`
- Test: `test/features/auth/onboarding_screen_test.dart` (new)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/features/auth/presentation/onboarding_screen.dart';
import 'package:rego/l10n/app_localizations.dart';

void main() {
  Future<ProviderContainer> pumpOnboarding(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(memoryLocaleStore: {}, memoryGuestModeStore: {}),
        ),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: AppRoutes.onboarding,
      routes: [
        GoRoute(
          path: AppRoutes.onboarding,
          builder: (context, state) => const OnboardingScreen(),
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

  testWidgets('language button opens the language picker sheet',
      (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.byIcon(AppIcons.language));
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/onboarding_screen_test.dart`
Expected: FAIL — `find.byIcon(AppIcons.language)` finds nothing (`Bad state: No element` / `findsOneWidget` for the sheet text fails because the sheet never opens).

- [ ] **Step 3: Modify the screen**

In `lib/features/auth/presentation/onboarding_screen.dart`, add the import (keep alphabetical order):

```dart
import 'package:rego/l10n/app_localizations.dart';
```
becomes:
```dart
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/language_icon_button.dart';
```

Then replace the top-left "Skip" `Align` with a `Row` that also holds the language button:

Old:
```dart
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    l10n.onboardingSkip,
                    style: AppTypography.title.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
```

New:
```dart
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      l10n.onboardingSkip,
                      style: AppTypography.title.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const LanguageIconButton(color: AppColors.textSecondary),
                ],
              ),
            ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/onboarding_screen_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Run the full onboarding-adjacent suite to check for regressions**

Run: `flutter test test/features/auth/`
Expected: PASS (all tests, including the new one)

- [ ] **Step 6: Commit**

```bash
git add lib/features/auth/presentation/onboarding_screen.dart test/features/auth/onboarding_screen_test.dart
git commit -m "feat(onboarding): add language switcher next to Skip"
```

---

## Task 4: Wire into Login screen (via a `GradientHero` top-end slot)

Rather than restructuring `LoginScreen`'s body into a `Stack`, give the shared hero a
small optional overlay slot — `GradientHero` already renders inside its own `Stack`,
so this is a purely additive change with no impact on existing callers (Home,
Profile, Register, OTP, etc. all leave `topEnd` at its `null` default).

**Files:**
- Modify: `lib/shared/widgets/gradient_hero.dart`
- Modify: `lib/features/auth/presentation/widgets/auth_hero_layout.dart`
- Modify: `lib/features/auth/presentation/login_screen.dart`
- Test: `test/features/auth/login_screen_test.dart` (add a test + tweak the shared harness)

- [ ] **Step 1: Write the failing test**

Add this import to `test/features/auth/login_screen_test.dart` (alphabetical, before `app_theme.dart`):

```dart
import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_theme.dart';
```

Update `pumpLogin`'s `SecureStorage` override so the locale controller has an
in-memory store to read/write instead of touching the real secure storage plugin:

Old:
```dart
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(memoryGuestModeStore: guestModeMemory),
        ),
      ],
    );
```

New:
```dart
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(
            memoryGuestModeStore: guestModeMemory,
            memoryLocaleStore: {},
          ),
        ),
      ],
    );
```

Add a new test at the end of `main()`, after the last existing `testWidgets` block:

Old (end of file):
```dart
    expect(
      find.text('REGISTER returnTo=${BusRoutes.confirm}'),
      findsOneWidget,
    );
  });
}
```

New:
```dart
    expect(
      find.text('REGISTER returnTo=${BusRoutes.confirm}'),
      findsOneWidget,
    );
  });

  testWidgets('language button opens the language picker sheet',
      (tester) async {
    await pumpLogin(tester, guestModeMemory: {});

    await tester.tap(find.byIcon(AppIcons.language));
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/login_screen_test.dart`
Expected: FAIL — `find.byIcon(AppIcons.language)` finds nothing.

- [ ] **Step 3: Add the `topEnd` slot to `GradientHero`**

In `lib/shared/widgets/gradient_hero.dart`, add the field:

Old:
```dart
    this.reserveCardOverlap = false,
    this.child,
  });

  final String? title;
  final String? subtitle;
  final bool showWordmark;
  final EdgeInsets padding;

  /// When true, extends the gradient below the text so a floating card can
  /// overlap upward (matches Home / Profile Skyline layout).
  final bool reserveCardOverlap;
  final Widget? child;
```

New:
```dart
    this.reserveCardOverlap = false,
    this.child,
    this.topEnd,
  });

  final String? title;
  final String? subtitle;
  final bool showWordmark;
  final EdgeInsets padding;

  /// When true, extends the gradient below the text so a floating card can
  /// overlap upward (matches Home / Profile Skyline layout).
  final bool reserveCardOverlap;
  final Widget? child;

  /// Optional widget pinned to the top-end corner (e.g. a language switcher).
  final Widget? topEnd;
```

Then render it inside the existing `Stack`:

Old:
```dart
                    ],
                  ),
                ),
              ],
```

New:
```dart
                    ],
                  ),
                ),
                if (topEnd != null)
                  PositionedDirectional(
                    top: 40,
                    end: 12,
                    child: topEnd!,
                  ),
              ],
```

- [ ] **Step 4: Thread `topEnd` through `AuthHeroLayout`**

In `lib/features/auth/presentation/widgets/auth_hero_layout.dart`:

Old:
```dart
  const AuthHeroLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;
```

New:
```dart
  const AuthHeroLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.topEnd,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? topEnd;
```

Old:
```dart
        GradientHero(
          title: title,
          subtitle: subtitle,
          reserveCardOverlap: true,
        ),
```

New:
```dart
        GradientHero(
          title: title,
          subtitle: subtitle,
          reserveCardOverlap: true,
          topEnd: topEnd,
        ),
```

- [ ] **Step 5: Use it in `LoginScreen`**

In `lib/features/auth/presentation/login_screen.dart`, add the import (alphabetical, between `double_back_to_exit.dart` and `primary_button.dart`):

Old:
```dart
import 'package:rego/shared/widgets/double_back_to_exit.dart';
import 'package:rego/shared/widgets/primary_button.dart';
```

New:
```dart
import 'package:rego/shared/widgets/double_back_to_exit.dart';
import 'package:rego/shared/widgets/language_icon_button.dart';
import 'package:rego/shared/widgets/primary_button.dart';
```

Then pass `topEnd`:

Old:
```dart
              AuthHeroLayout(
                title: l10n.loginTitle,
                subtitle: l10n.loginSubtitle,
                child: AuthCard(
```

New:
```dart
              AuthHeroLayout(
                title: l10n.loginTitle,
                subtitle: l10n.loginSubtitle,
                topEnd: const LanguageIconButton(color: AppColors.onHero),
                child: AuthCard(
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/auth/login_screen_test.dart`
Expected: PASS (all tests in the file, including the new one)

- [ ] **Step 7: Run the full auth suite to check for regressions**

Run: `flutter test test/features/auth/`
Expected: PASS (all tests)

- [ ] **Step 8: Commit**

```bash
git add lib/shared/widgets/gradient_hero.dart lib/features/auth/presentation/widgets/auth_hero_layout.dart lib/features/auth/presentation/login_screen.dart test/features/auth/login_screen_test.dart
git commit -m "feat(login): add language switcher on the hero via GradientHero topEnd slot"
```

---

## Task 5: Wire into Profile screen

**Files:**
- Modify: `lib/features/profile/presentation/profile_screen.dart`
- Test: `test/features/profile/profile_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Add this test at the end of `main()` in `test/features/profile/profile_screen_test.dart`:

Old (end of file):
```dart
    expect(find.text('LOGIN returnTo=${AppRoutes.profile}'), findsOneWidget);
  });
}
```

New:
```dart
    expect(find.text('LOGIN returnTo=${AppRoutes.profile}'), findsOneWidget);
  });

  testWidgets('tapping Language opens the language picker sheet',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpProfile(tester);

    final languageTile = find.text('Language');
    await tester.ensureVisible(languageTile);
    await tester.pumpAndSettle();
    await tester.tap(languageTile);
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/profile/profile_screen_test.dart`
Expected: FAIL — tapping "Language" shows the "Coming Soon" snackbar instead of the sheet, so `find.text('English')` finds nothing.

- [ ] **Step 3: Wire the menu row**

In `lib/features/profile/presentation/profile_screen.dart`, add the import (alphabetical, before `ltr_text.dart`):

Old:
```dart
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/ltr_text.dart';
```

New:
```dart
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/language_picker_sheet.dart';
import 'package:rego/shared/widgets/ltr_text.dart';
```

Then change the Language row's `onTap`:

Old:
```dart
                _ProfileMenuItem(
                  icon: AppIcons.language,
                  label: l10n.profileMenuLanguage,
                  onTap: () => _showComingSoon(context, l10n),
                ),
```

New:
```dart
                _ProfileMenuItem(
                  icon: AppIcons.language,
                  label: l10n.profileMenuLanguage,
                  onTap: () => showLanguagePickerSheet(context),
                ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/profile/profile_screen_test.dart`
Expected: PASS (all tests in the file, including the new one)

- [ ] **Step 5: Commit**

```bash
git add lib/features/profile/presentation/profile_screen.dart test/features/profile/profile_screen_test.dart
git commit -m "fix(profile): wire Language row to the language picker sheet"
```

---

## Task 6: Full verification pass

**Files:** none (verification only)

- [ ] **Step 1: Static analysis**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: All tests PASS, no regressions in unrelated suites.

- [ ] **Step 3: Format check**

Run: `dart format --output=none --set-exit-if-changed lib test`
Expected: exit code 0 (no files need reformatting). If it lists files, run `dart format lib test` and re-run `flutter analyze && flutter test` before committing the formatting fix.

- [ ] **Step 4: Manual on-device/emulator check (mobile-only app — no browser preview)**

Launch the app (`flutter run`) and manually verify:
1. Onboarding: tap the globe icon → sheet opens → pick العربية → app flips to RTL and Arabic text immediately.
2. Restart the app → language choice persisted (still Arabic).
3. Login: tap the globe icon on the hero → pick English → app flips back to LTR.
4. Profile → Language → same sheet opens, current language has the check mark.

- [ ] **Step 5: Final commit (only if Step 3 required formatting fixes)**

```bash
git add -u
git commit -m "style: run dart format after language switcher changes"
```
