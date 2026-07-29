# Auth UI Micro-Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Micro-polish the shared auth shell (card shadow, spacing tokens, ≥48dp taps, RTL alignment, a11y labels) per `docs/superpowers/specs/2026-07-29-auth-ui-micro-polish-design.md`.

**Architecture:** In-place edits to `AuthCard` / fields / social row, plus two thin shared widgets (`AuthTextLink`, `AuthPasswordToggle`) consumed by login, register, and new-password. Keep `AuthPinnedBottomLayout`.

**Tech Stack:** Flutter, Riverpod, existing Skyline tokens, Phosphor Light icons, ARB l10n.

## Global Constraints

- Do not invent new brand hex colors; softer shadow uses existing `AppColors.primaryDark` alpha only
- All user-facing / a11y strings via `AppLocalizations` (both ARBs)
- RTL: `EdgeInsetsDirectional`, `AlignmentDirectional` — no left/right
- Icons: `PhosphorIconsLight.*` only
- Never edit `*.g.dart` / `*.freezed.dart`
- Commit only when the user asks
- Out of scope stays out: mid-screen gap closure, social auth, floating labels

---

## File map

| File | Role |
|------|------|
| `lib/l10n/app_en.arb` + `app_ar.arb` | `authShowPassword` / `authHidePassword` |
| `lib/features/auth/presentation/widgets/auth_text_link.dart` | Shared text link (≥48 tap) |
| `lib/features/auth/presentation/widgets/auth_password_toggle.dart` | Shared eye toggle |
| `lib/features/auth/presentation/widgets/auth_card.dart` | Softer shadow + spacing tokens |
| `lib/features/auth/presentation/widgets/auth_text_field.dart` | Directional error padding |
| `lib/features/auth/presentation/widgets/phone_field.dart` | Directional error + chip hit target |
| `lib/features/auth/presentation/widgets/social_row.dart` | Spacing tokens |
| `lib/features/auth/presentation/login_screen.dart` | Helpers + forgot start + CTA gaps |
| `lib/features/auth/presentation/register_screen.dart` | Helpers + footer + gap |
| `lib/features/auth/presentation/new_password_screen.dart` | `AuthPasswordToggle` |
| `test/features/auth/presentation/auth_text_link_test.dart` | New: min height / semantics |
| `test/features/auth/login_screen_test.dart` | Smoke: forgot link still present |

---

### Task 1: L10n keys for password toggle

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ar.arb`

- [x] **Step 1: Add keys**
- [x] **Step 2: Regenerate l10n**

---

### Task 2: `AuthTextLink` + `AuthPasswordToggle`

**Files:**
- Create: `lib/features/auth/presentation/widgets/auth_text_link.dart`
- Create: `lib/features/auth/presentation/widgets/auth_password_toggle.dart`
- Create: `test/features/auth/presentation/auth_text_link_test.dart`

**Interfaces:**
- Produces:
  - `AuthTextLink({required String label, required VoidCallback onTap, TextStyle? style})`
  - `AuthPasswordToggle({required bool obscure, required VoidCallback onTap})`

- [ ] **Step 1: Write failing widget test**

```dart
testWidgets('AuthTextLink has at least 48px tap height', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AuthTextLink(label: 'Sign up', onTap: () {}),
      ),
    ),
  );
  final size = tester.getSize(find.byType(AuthTextLink));
  expect(size.height, greaterThanOrEqualTo(48));
});
```

- [ ] **Step 2: Implement widgets**

`AuthTextLink`: `TextButton` with `minimumSize: Size(48, 48)`, primary bold caption/body style default matching login forgot / signup links.

`AuthPasswordToggle`: `IconButton` size constraints 48, icon 20, `PhosphorIconsLight.eye` / `eyeSlash`, tooltip + `semanticLabel` from l10n (`authShowPassword` when `obscure`, else `authHidePassword`).

- [ ] **Step 3: Run test**

```bash
flutter test test/features/auth/presentation/auth_text_link_test.dart
```

---

### Task 3: Shared shell widgets (`AuthCard`, fields, social)

**Files:**
- Modify: `auth_card.dart`, `auth_text_field.dart`, `phone_field.dart`, `social_row.dart`

- [ ] **Step 1: AuthCard**

Default `gap: AppSpacing.md` (16). Padding `EdgeInsetsDirectional.all(AppSpacing.lg)`. Softer shadow e.g. alpha `0.12`, `blurRadius: 28`, `spreadRadius: -12`, `offset: Offset(0, 10)`.

- [ ] **Step 2: AuthTextField + PhoneField error padding**

```dart
padding: const EdgeInsetsDirectional.only(top: 6, start: 6, end: 6),
```

- [ ] **Step 3: Country chip**

Wrap with `InkWell` / ensure vertical padding yields ≥48 height, or wrap in `ConstrainedBox(minHeight: 48)` while keeping visual chip compact via alignment.

- [ ] **Step 4: SocialRow**

Replace `14` / `12` magic with `AppSpacing.md` / `AppSpacing.sm + AppSpacing.xs` as appropriate.

---

### Task 4: Wire login / register / new-password

**Files:**
- Modify: `login_screen.dart`, `register_screen.dart`, `new_password_screen.dart`

- [ ] **Step 1: Login**

- Forgot: `Align(alignment: AlignmentDirectional.centerStart, child: AuthTextLink(...))`
- Password trailing: `AuthPasswordToggle`
- Footer signup: `AuthTextLink`
- Remove local `_EyeToggle`
- Button gaps: primary↔guest `AppSpacing.md`; then `AppSpacing.lg` before footer

- [ ] **Step 2: Register**

- Remove `gap: 13` (use card default) or set `gap: AppSpacing.md`
- Trailing: `AuthPasswordToggle`
- Footer sign-in: `AuthTextLink`
- Primary↔footer: keep `AppSpacing.lg`

- [ ] **Step 3: New password**

Replace `_eye()` with `AuthPasswordToggle`.

- [ ] **Step 4: Verify**

```bash
flutter analyze lib/features/auth
flutter test test/features/auth/
```

---

### Task 5: Spec compliance self-check

- [ ] Confirm pinned bottom layout untouched
- [ ] Confirm no left/right insets in touched error paddings
- [ ] Confirm mid-screen gap not “fixed”
- [ ] Run `dart format` on touched Dart files
