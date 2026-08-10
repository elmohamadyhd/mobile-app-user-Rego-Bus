# Profile Settings Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a profile-owned Settings screen and move language selection into it (remove the top-level Language row from My Account).

**Architecture:** New `SettingsScreen` under `profile/presentation`, routed at `/profile/settings`. Profile menu Settings pushes that route. The Language row on Settings shows the current autonym and opens the existing `showLanguagePickerSheet` driven by `localeControllerProvider`.

**Tech Stack:** Flutter, Riverpod (`ConsumerWidget`), go_router, Skyline tokens (`AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`), Phosphor Light icons, `flutter_test`.

**Spec:** [`docs/superpowers/specs/2026-08-10-profile-settings-screen-design.md`](../specs/2026-08-10-profile-settings-screen-design.md)

## Global Constraints

- Own under `profile` — no new `features/settings/` slice
- v1 content: Language only
- Reuse `showLanguagePickerSheet` + `localeControllerProvider` — no new persistence/API
- Reuse ARB keys `profileMenuSettings` / `profileMenuLanguage`; language names stay autonyms
- Guests can open Settings (no auth gate)
- Design tokens only — no hardcoded colors/radii/spacing
- Package imports (`package:safaria/...`); Phosphor Light icons only
- Help on profile stays “coming soon”
- Do not change onboarding/login `LanguageIconButton` entry points

## File map

| File | Role |
|------|------|
| `lib/features/profile/presentation/settings_screen.dart` | New Settings UI |
| `lib/features/profile/presentation/profile_routes.dart` | Add `/profile/settings` |
| `lib/features/profile/presentation/profile_screen.dart` | Wire Settings; remove Language row |
| `test/features/profile/settings_screen_test.dart` | New widget tests |
| `test/features/profile/profile_screen_test.dart` | Update Language/Settings expectations |

---

### Task 1: Settings screen (TDD)

**Files:**
- Create: `test/features/profile/settings_screen_test.dart`
- Create: `lib/features/profile/presentation/settings_screen.dart`

**Interfaces:**
- Consumes: `showLanguagePickerSheet(BuildContext)`, `localeControllerProvider`, `ProfileAppBar`, `AppLocalizations.profileMenuSettings` / `profileMenuLanguage`
- Produces: `class SettingsScreen extends ConsumerWidget { const SettingsScreen({super.key}); }`

- [ ] **Step 1: Write the failing tests**

Create `test/features/profile/settings_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/core/providers/locale_controller.dart';
import 'package:safaria/core/storage/secure_storage.dart';
import 'package:safaria/core/theme/app_theme.dart';
import 'package:safaria/features/profile/presentation/settings_screen.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> pumpSettings(
    WidgetTester tester, {
    Locale materialLocale = const Locale('en'),
    Locale deviceLocale = const Locale('en'),
    Map<String, String> memoryLocaleStore = const {},
  }) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.localeTestValue = deviceLocale;
    addTearDown(binding.platformDispatcher.clearLocaleTestValue);

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorage(memoryLocaleStore: Map.of(memoryLocaleStore)),
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
          theme: AppTheme.light(),
          locale: materialLocale,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Allow LocaleController to finish loading any saved override.
    await Future<void>.delayed(Duration.zero);
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('shows Settings title, Language row, and English trailing value',
      (tester) async {
    await pumpSettings(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.translate), findsOneWidget);
  });

  testWidgets('shows العربية trailing value when locale is Arabic',
      (tester) async {
    await pumpSettings(
      tester,
      materialLocale: const Locale('ar'),
      deviceLocale: const Locale('ar'),
    );

    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('اللغة'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
  });

  testWidgets('tapping Language opens the language picker sheet',
      (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    expect(find.text('العربية'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsLight.check), findsOneWidget);
  });

  testWidgets('picking Arabic updates the trailing value on Settings',
      (tester) async {
    final container = await pumpSettings(tester);
    expect(container.read(localeControllerProvider).languageCode, 'en');

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    expect(container.read(localeControllerProvider).languageCode, 'ar');
    // Sheet closed; Settings still shows the Arabic autonym as trailing value.
    // MaterialApp locale is still en here, so the row label stays "Language".
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
flutter test test/features/profile/settings_screen_test.dart
```

Expected: FAIL — missing `settings_screen.dart` / unresolved `SettingsScreen` import.

- [ ] **Step 3: Implement `SettingsScreen`**

Create `lib/features/profile/presentation/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/providers/locale_controller.dart';
import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/features/profile/presentation/widgets/profile_app_bar.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/language_picker_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  String _languageAutonym(String languageCode) =>
      languageCode == 'ar' ? 'العربية' : 'English';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final languageCode = ref.watch(localeControllerProvider).languageCode;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: ProfileAppBar(title: l10n.profileMenuSettings),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = context.isLandscape
                ? AppBreakpoints.maxContentWidth
                : constraints.maxWidth;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.lg + viewInsets,
                  ),
                  child: _SettingsMenuCard(
                    child: _SettingsLanguageTile(
                      label: l10n.profileMenuLanguage,
                      value: _languageAutonym(languageCode),
                      onTap: () => showLanguagePickerSheet(context),
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

class _SettingsMenuCard extends StatelessWidget {
  const _SettingsMenuCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.20),
            blurRadius: 40,
            spreadRadius: -18,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SettingsLanguageTile extends StatelessWidget {
  const _SettingsLanguageTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  PhosphorIconsLight.translate,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.title.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                value,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                PhosphorIconsLight.caretRight,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
flutter test test/features/profile/settings_screen_test.dart
```

Expected: PASS (all four tests).

If the Arabic trailing test fails because `localeControllerProvider` still resolves to `en` on the host, call `setLocale(const Locale('ar'))` after the first settle (or seed `memoryLocaleStore: {'locale_override': 'ar'}`) and re-settle before asserting — keep MaterialApp `locale: Locale('ar')` so chrome strings stay Arabic.

- [ ] **Step 5: Commit**

```bash
git add test/features/profile/settings_screen_test.dart \
  lib/features/profile/presentation/settings_screen.dart
git commit -m "$(cat <<'EOF'
feat(profile): add Settings screen with language row

EOF
)"
```

---

### Task 2: Route + move Language out of profile menu

**Files:**
- Modify: `lib/features/profile/presentation/profile_routes.dart`
- Modify: `lib/features/profile/presentation/profile_screen.dart`
- Modify: `test/features/profile/profile_screen_test.dart`

**Interfaces:**
- Consumes: `SettingsScreen` from Task 1
- Produces: `ProfileRoutes.settings` = `'/profile/settings'`; profile Settings row pushes it; Language row removed from profile

- [ ] **Step 1: Update the failing profile test first**

In `test/features/profile/profile_screen_test.dart`, **replace** the existing test:

```dart
testWidgets('tapping Language opens the language picker sheet',
```

with:

```dart
  testWidgets('profile menu has Settings but not Language', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpProfile(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
  });

  testWidgets('tapping Settings pushes the settings screen', (tester) async {
    final container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(
          () => _FakeSessionController(session),
        ),
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
          path: ProfileRoutes.settings,
          builder: (context, state) => const Text('SETTINGS'),
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

    final settingsTile = find.text('Settings');
    await tester.ensureVisible(settingsTile);
    await tester.pumpAndSettle();
    await tester.tap(settingsTile);
    await tester.pumpAndSettle();

    expect(find.text('SETTINGS'), findsOneWidget);
  });
```

Add this import at the top of the test file (with the other profile imports):

```dart
import 'package:safaria/features/profile/presentation/profile_routes.dart';
```

- [ ] **Step 2: Run the updated profile tests — expect failure**

Run:

```bash
flutter test test/features/profile/profile_screen_test.dart
```

Expected: FAIL — `Language` still present and/or Settings still shows coming-soon / does not navigate (`ProfileRoutes.settings` missing or still snackbar).

- [ ] **Step 3: Wire the route**

Replace `lib/features/profile/presentation/profile_routes.dart` with:

```dart
import 'package:go_router/go_router.dart';

import 'package:safaria/features/profile/presentation/profile_edit_screen.dart';
import 'package:safaria/features/profile/presentation/saved_travellers_screen.dart';
import 'package:safaria/features/profile/presentation/settings_screen.dart';

abstract final class ProfileRoutes {
  static const edit = '/profile/edit';
  static const savedTravellers = '/profile/saved-travellers';
  static const settings = '/profile/settings';
}

List<RouteBase> profileRoutes() => [
      GoRoute(
        path: ProfileRoutes.edit,
        builder: (_, __) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: ProfileRoutes.savedTravellers,
        builder: (_, __) => const SavedTravellersScreen(),
      ),
      GoRoute(
        path: ProfileRoutes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
    ];
```

- [ ] **Step 4: Update `ProfileScreen`**

In `lib/features/profile/presentation/profile_screen.dart`:

1. Remove:

```dart
import 'package:safaria/shared/widgets/language_picker_sheet.dart';
```

2. Delete the Language `_ProfileMenuItem` block entirely:

```dart
                _ProfileMenuItem(
                  icon: PhosphorIconsLight.translate,
                  label: l10n.profileMenuLanguage,
                  onTap: () => showLanguagePickerSheet(context),
                ),
```

3. Change the Settings item `onTap` from `_showComingSoon(context, l10n)` to:

```dart
                  onTap: () => context.push(ProfileRoutes.settings),
```

Keep Help on `_showComingSoon`. `profile_routes.dart` is already imported.

- [ ] **Step 5: Run profile + settings tests**

Run:

```bash
flutter test test/features/profile/profile_screen_test.dart test/features/profile/settings_screen_test.dart
```

Expected: PASS.

Also run:

```bash
dart format lib/features/profile/presentation/settings_screen.dart \
  lib/features/profile/presentation/profile_routes.dart \
  lib/features/profile/presentation/profile_screen.dart \
  test/features/profile/settings_screen_test.dart \
  test/features/profile/profile_screen_test.dart
flutter analyze lib/features/profile test/features/profile
```

Expected: no issues from these files.

- [ ] **Step 6: Commit**

```bash
git add lib/features/profile/presentation/profile_routes.dart \
  lib/features/profile/presentation/profile_screen.dart \
  test/features/profile/profile_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(profile): route Settings and move language under it

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| `/profile/settings` + `SettingsScreen` | 1, 2 |
| Profile Settings navigates; Language removed | 2 |
| Language row + trailing autonym + existing sheet | 1 |
| Guests can open Settings | 2 (no auth gate on push) |
| Reuse ARB / autonyms; no new feature slice | Global + 1 |
| Help stays coming soon | 2 (untouched) |
| Tests: settings + profile updates | 1, 2 |
| Responsive scroll + max width | 1 (`LayoutBuilder` / landscape) |

## Out of scope (do not implement)

- Theme, notifications prefs, Help content
- Redesigning `language_picker_sheet.dart`
- Extracting shared profile menu tile (local Settings tile only)
- Changing onboarding/login language buttons
