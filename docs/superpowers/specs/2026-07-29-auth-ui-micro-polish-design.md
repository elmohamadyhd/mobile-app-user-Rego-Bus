# Auth UI Micro-Polish — Design Spec

**Date:** 2026-07-29  
**Scope:** Shared auth shell micro-polish only (Approach A)  
**Screens:** Login, Register, Forgot password, OTP, New password (via shared widgets)

---

## Goal

Tighten visual and interaction quality of the auth form shell without
changing layout architecture (pinned bottom CTAs stay), brand tokens, or
auth business logic.

---

## Decisions (approved)

| Topic | Choice |
|-------|--------|
| Scope | Micro-polish only — keep `AuthPinnedBottomLayout` |
| Breadth | Shared auth shell (not login-only) |
| Approach | Token / interaction pass; light density only where padding is magic numbers |
| New chrome | Small shared helpers OK when they remove duplicated unsafe taps (`AuthTextLink`, `AuthPasswordToggle`) |
| Mid-screen gap | **Superseded 2026-07-29:** Login CTA moved into the card under Forgot password; login screen no longer uses pinned-bottom for the primary CTA |

---

## In scope

### 1. `AuthCard` elevation & spacing

**File:** `lib/features/auth/presentation/widgets/auth_card.dart`

- Soften the blue glow shadow (lower alpha / blur / offset) so the card
  still lifts from `bgBase` without looking heavy.
- Replace magic padding (`22`) and default gap (`14`) with `AppSpacing`
  tokens (`lg` padding, `md` or `sm + xs` gap).
- Keep `AppRadius.card` and `AppColors.bgCard`.

### 2. Touch targets ≥ 48dp

Replace bare `GestureDetector` + 20px icons / bare text taps with:

| Control | Shared widget / pattern |
|---------|-------------------------|
| Password eye | `AuthPasswordToggle` — `IconButton` min 48×48, semantic label |
| Forgot password / Sign up / Sign in links | `AuthTextLink` — `TextButton` with min height 48 |
| Country chip (PhoneField) | Expand hit area via padding / `InkWell` without changing visual size much |

Apply on login, register, and new-password (and any other auth screen using the same patterns).

### 3. RTL / directional layout

- Forgot-password: `AlignmentDirectional.centerStart` (reading-side, under fields).
- Error captions under fields: `EdgeInsetsDirectional` — no `left`/`right`.
- Prefer `EdgeInsetsDirectional` on auth card margin/padding where directional.

### 4. Semantics & a11y labels

- Add l10n keys for password visibility toggle (`authShowPassword` /
  `authHidePassword`) in `app_en.arb` + `app_ar.arb`.
- Text links expose button semantics via `TextButton` / `AuthTextLink`.

### 5. Bottom CTA rhythm (login / register)

Keep pinned layout. Normalize:

- Primary ↔ guest (login): `AppSpacing.md` between buttons.
- Primary ↔ footer link: `AppSpacing.lg` (unchanged intentional cluster).
- Footer “muted + link” row: use `AuthTextLink` for the tappable part;
  keep ≥8dp gap between adjacent targets.

---

## Out of scope

- Moving CTAs into the scroll body / closing the mid-screen empty band
- New colors, fonts, hero redesign, or design-token palette changes beyond
  using existing `AppSpacing` / softer shadow values from existing colors
- Visible floating labels (placeholder-only inputs stay)
- Wiring Google / social auth
- Changing validation, API, or navigation behavior

---

## Files (expected)

| File | Change |
|------|--------|
| `auth_card.dart` | Shadow + spacing tokens |
| `auth_text_field.dart` | Directional error padding |
| `phone_field.dart` | Directional error padding; country chip hit target |
| `social_row.dart` | Spacing tokens |
| `auth_text_link.dart` | **New** shared text link |
| `auth_password_toggle.dart` | **New** shared eye toggle |
| `login_screen.dart` | Use helpers; start-align forgot; CTA gaps |
| `register_screen.dart` | Use helpers; footer link; gap token |
| `new_password_screen.dart` | Use `AuthPasswordToggle` |
| `app_en.arb` / `app_ar.arb` | Show/hide password a11y strings |
| Tests | Update login (and add small widget tests if useful) |

---

## Success criteria

- Auth screens look consistent; card shadow softer, spacing on 4/8 rhythm
- Eye toggle and text links have ≥48dp interactive area and ink feedback
- Forgot password sits on the start edge in both `ar` and `en`
- No hardcoded left/right insets in touched field error paddings
- `flutter analyze` clean on touched files; existing auth widget tests pass
- Pinned-bottom architecture unchanged

---

## Self-review

- No placeholders or TBD behavior
- Scope matches “micro-polish + shared shell” only
- No contradiction with responsive / localization / design-token rules
