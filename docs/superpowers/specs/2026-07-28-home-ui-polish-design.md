# Home UI Polish — Design Spec

**Date:** 2026-07-28  
**Scope:** Home search card + hero greeting only (options 1 + 2 + 4)  
**Approach:** In-place polish of existing widgets (no new parallel components)

---

## Goal

Make the Home booking surface clearer and faster to use without changing
brand tokens (Skyline), navigation, or backend contracts:

1. Stronger transport-mode selection + mode-aware CTA label  
2. Compact date|time row on private-car form; disable CTA until required
   places are set; keep loading feedback  
3. Real profile avatar on the hero + clearer unread-style bell dot

---

## Decisions (approved)

| Topic | Choice |
|-------|--------|
| Empty form CTA | **Disabled** until from + to are both set (no snackbar for that case) |
| Bell badge | **Larger/clearer amber dot only** — no count, no notifications API |
| Date/time layout (car) | **Side-by-side** `date \| time` in one row |
| Implementation | **Polish existing widgets** shared where appropriate |

---

## Screen / widget behavior

### 1. Transport mode selector (`TransportModeTabBar`)

**Files:** `lib/shared/widgets/transport_mode_tab_bar.dart`  
(Used by Home and Tickets — visual change applies to both.)

**Selected tab**
- Keep white pill on `bgBase` track.
- Stronger selected affordance: primary icon + bold primary-tinted label;
  slightly stronger elevation / soft primary shadow (token colors only).
- Optional subtle `primaryTint` wash behind selected pill if white-on-white
  still feels weak — must stay WCAG-friendly.

**Unselected tabs**
- Muted icon + label (`textMuted`), no elevation.

**Interaction**
- Tap feedback 150–300ms (Material ink / opacity). Hit target remains full
  expanded cell (≥48dp tall via padding).
- Home coming-soon snack for flight/train tabs stays as today.

**Out of scope for this tab bar**
- Removing train, horizontal scroll, or changing tab order.

### 2. Dynamic CTA + disabled-until-valid

**Files:**
- `lib/features/home/presentation/widgets/home_search_card.dart` (bus)
- `lib/features/car/presentation/car_search_form.dart` (private)

**Labels (existing l10n keys)**
| Mode | CTA label key |
|------|----------------|
| Bus | `homeSearch` (“ابحث عن رحلات” / “Search trips”) |
| Private | `carRequestCar` (“اطلب سيارة” / “Request a car”) |
| Flight / Train | Keep showing `homeSearch` (or current bus form CTA); tabs still show coming-soon on select |

**Enabled rules**
- **Bus:** `onPressed` non-null only when `_fromCity != null && _toCity != null`.
  Remove the snackbar path that only says “select cities”; other errors (if any)
  keep existing handling.
- **Private:** `onPressed` non-null only when `_from != null && _to != null`.
  Remove snackbar for missing places only. Keep snackbars for same-place,
  depart-in-past, return-before-depart.
- **Loading:** Pass `loading: _searching` as today; button stays disabled while
  loading (`PrimaryButton` already does this).

### 3. Compact date \| time (private car)

**File:** `lib/features/car/presentation/car_search_form.dart` (`_DateTimeField`)

**One-way**
- Single bordered container.
- One horizontal row: calendar icon | **date** (tappable) | divider | **time**
  (tappable). Labels: depart label above date; time label above time (or
  compact overlines above each half).
- Chevron optional; prefer none when both halves are clearly tappable.

**Round-trip**
- Two columns (depart | return) as today, each column using the same
  compact date|time row (may stack date then time vertically *inside* a
  narrow column if width is too tight — prefer side-by-side when
  `compact: false` / one-way; for round-trip columns, date over time is
  acceptable if side-by-side overflows).

**Bus form**
- No time picker today — leave bus date row as-is (date only). Not part of
  option 2 beyond shared disabled-CTA rule.

### 4. Hero avatar + bell badge

**Files:**
- `lib/shared/widgets/skyline_tab_hero.dart`
- `lib/features/home/presentation/home_screen.dart`
- Reuse `ProfileCircleAvatar` (`hero` style) from profile widgets.

**Avatar**
- Pass `avatarUrl` from `sessionControllerProvider` user when present.
- Fallback: first letter of display name (current behavior).
- Size ~42dp to match current circle.
- Home must not import profile *feature data* layers — presentation widget
  reuse from `profile/.../widgets/profile_circle_avatar.dart` is acceptable
  (already a shared visual atom). Prefer moving to `shared/widgets` only if
  import causes architecture lint pain; otherwise reuse in place.

**Bell**
- Keep `SkylineTabHeroBellButton`.
- Increase dot size slightly (e.g. 8 → 10–11) and/or tighten position so it
  reads clearly on the blue hero; keep `AppColors.secondary` + border.
- No count text. No notifications route required (onTap may stay null / noop).

---

## Error / empty states

| Case | UI |
|------|-----|
| Missing from/to | CTA disabled (opacity via `PrimaryButton`) |
| Same place / past time / bad return (car) | Existing snackbars |
| Flight/train tab | Existing coming-soon snackbar |
| Search in flight | CTA loading spinner |
| No avatar URL | Letter initial |

---

## Localization

- Prefer existing keys (`homeSearch`, `carRequestCar`).
- New keys only if accessibility labels are missing (e.g. bell
  `Semantics` / swap). Add to both `app_en.arb` and `app_ar.arb` if needed.

---

## Responsive / RTL

- Date|time row uses `EdgeInsetsDirectional` / `VerticalDivider` so RTL
  mirrors correctly.
- Form remains inside scrollable shell (`ShellTabScrollView`) for landscape.
- Touch targets ≥48dp for swap, tabs, date/time halves, bell.

---

## Testing

- Widget tests: car form CTA null when places empty; non-null when both set.
- Bus form: same enabled rule.
- Golden/visual optional; at least pump Home under `Locale('ar')`.
- Update existing car search form tests if they assert snackbar-on-empty.

---

## Out of scope

- Popular destinations images / carousel  
- Notifications feature / unread count API  
- New design tokens or font changes  
- Mode selector layout overhaul (scroll, hide train)  
- Sticky CTA / landscape-only layouts beyond existing scroll  

---

## File touch list (expected)

1. `lib/shared/widgets/transport_mode_tab_bar.dart`  
2. `lib/features/car/presentation/car_search_form.dart`  
3. `lib/features/home/presentation/widgets/home_search_card.dart`  
4. `lib/shared/widgets/skyline_tab_hero.dart`  
5. `lib/features/home/presentation/home_screen.dart`  
6. Tests under `test/features/car/` and/or `test/features/home/` as needed  
7. ARB only if new a11y strings are required  

---

## Success criteria

- Selected transport mode is obvious at a glance.  
- CTA label matches bus vs private.  
- CTA cannot fire with empty places; shows loading while searching.  
- Car date and time sit on one compact row (one-way).  
- Hero shows photo avatar when available; bell dot is clearly visible.  
`flutter analyze` clean on touched files; relevant tests pass.
