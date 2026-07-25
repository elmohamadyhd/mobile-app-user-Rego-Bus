# Booking terms checkbox + CMS pages — design

**Date:** 2026-07-25  
**Status:** Draft — pending review

## Goal

Before Confirm & Pay on booking confirmation screens, the rider must accept
Terms and Conditions. Tapping the linked phrase opens a full-screen CMS page
loaded from `GET /pages/terms-and-conditions`. The pages API is implemented as
a reusable feature so Settings (and other surfaces) can open terms/privacy
later without re-fetching logic.

## Decisions (from brainstorming)

| Topic | Decision |
|-------|----------|
| Scope of checkbox | All booking modes that have confirm/pay (bus first; flight/car when those screens exist) |
| Terms tap target | Full-screen in-app page (`GET /pages/{slug}`) |
| Unchecked Confirm | Button disabled **and** tap-while-unchecked shows a snackbar |
| Pages reuse | Build reusable `features/pages/` now (terms + privacy-ready) |
| Architecture | Approach 1: pages feature + shared checkbox widget |

## Current state

- Bus confirm UI: `PassengerConfirmScreen`
  (`lib/features/bus/presentation/passenger_confirm_screen.dart`).
- Confirm & Pay is a `PrimaryButton` in `bottomNavigationBar`; no terms gate.
- No `lib/features/pages/` slice; no CMS page screens or providers.
- `webview_flutter` is already a dependency (payment WebViews).
- Flight / private-car confirmation screens are not in scope of this PR’s
  wire-up (shared checkbox is ready for them later).

## Backend APIs (`docs/wadeny-apis.md` / Postman Content → Pages)

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/pages` | List pages (`id`, `title`, `slug`, `status`) |
| `GET` | `/pages/{slug}` | Page detail (`id`, `slug`, `title`, `content` HTML, `status`) |

Auth + `Accept-Language` follow the existing Dio client (bearer when logged
in; locale from `LocaleController`).

### Known slugs (from saved Responses)

| Slug | Typical title |
|------|----------------|
| `terms-and-conditions` | Terms and Conditions |
| `privacy-and-policy` | Privacy And Policy |

Booking uses the **hardcoded** slug `terms-and-conditions`. The list endpoint
is implemented for completeness / future Settings, but the confirm screen does
**not** call `GET /pages` — it navigates directly by slug.

### Detail response shape

```json
{
  "status": 200,
  "message": "Page details",
  "errors": {},
  "data": {
    "id": 1,
    "slug": "terms-and-conditions",
    "title": "Terms and Conditions",
    "content": "<p>…</p>",
    "status": 1
  }
}
```

## Ownership

| Piece | Lives in |
|-------|----------|
| Pages API, entities, repository, detail screen, routes | `lib/features/pages/` |
| Terms checkbox + disabled-button + snackbar gate | `lib/shared/widgets/` |
| Wire into confirm screen | Each transport feature (bus in this PR) |
| Settings menu rows linking to pages | Out of scope for this PR; routes/providers must support it |

Cross-feature rule: transport features import `shared/` and navigate to pages
routes; they do **not** import `pages/data/`. Presentation may depend on pages
route constants / screen entry via go_router paths only (or a thin
`pages_routes.dart` public path helper). Prefer:

- `context.push('/pages/terms-and-conditions')` (or `PagesRoutes.detail(slug)`)
- Shared checkbox owns navigation to the terms slug constant.

## UI & behavior

### Booking confirmation (bus first)

Placement: between the price-summary card and the bottom Confirm & Pay bar
(the empty gap in the current Skyline confirm layout).

- Unchecked by default.
- Label: localized “I agree to the **Terms and Conditions**” (exact copy in
  ARB). The “Terms and Conditions” portion is a tappable link (primary color /
  underline per Skyline text-link patterns).
- Tapping the link → `push` full-screen page detail for
  `terms-and-conditions`.
- Confirm & Pay: `onPressed` is `null` while unchecked (disabled look via
  existing `PrimaryButton`).
- A wrapper around the button area still receives taps when disabled and shows
  a snackbar: must accept terms before booking.
- Acceptance is **local UI state** for the current visit to the confirm screen.
  Leaving and returning resets it. It is **not** sent on `create-ticket` or
  any booking payload.

### Page detail screen

- App bar title = API `title`; while loading, fall back to a localized label
  for known slugs (terms / privacy) or a generic “Page” string.
- Body:
  - Loading: centered progress.
  - Success: `WebView` loads a minimal HTML document wrapping `content`
    (base styles for readable body text; `dir` / `lang` from app locale for
    RTL).
  - Error: message + retry (invalidate/refetch provider).
- Back pops to the previous screen; checkbox state on confirm is unchanged.

### Settings (ready, not wired in this PR)

Same route `/pages/:slug` with `privacy-and-policy` or `terms-and-conditions`.
No Settings UI changes in this PR.

## Data layer & file layout

```
lib/features/pages/
├── data/
│   ├── pages_api.dart
│   └── pages_repository_impl.dart
├── domain/
│   ├── entities/
│   │   └── cms_page.dart          # Freezed: CmsPage + CmsPageSummary
│   └── repositories/
│       └── pages_repository.dart
└── presentation/
    ├── pages_routes.dart          # /pages/:slug
    ├── page_detail_screen.dart
    └── providers/
        └── pages_providers.dart   # repo + pageDetailProvider(slug)

lib/shared/widgets/
├── booking_terms_checkbox.dart
└── gated_primary_button.dart   # PrimaryButton + tap-through snackbar when gated
```

### Domain

- `CmsPageSummary` — `id`, `title`, `slug`, `status`
- `CmsPage` — `id`, `slug`, `title`, `content`, `status`
- `PagesRepository`:
  - `Future<List<CmsPageSummary>> listPages()`
  - `Future<CmsPage> getPage(String slug)`

### Presentation providers

- `pagesRepositoryProvider`
- `pageDetailProvider(String slug)` → `AsyncValue<CmsPage>` (autoDispose
  family; refetch on retry)

### Constants

- `PagesSlugs.termsAndConditions = 'terms-and-conditions'`
- `PagesSlugs.privacyAndPolicy = 'privacy-and-policy'`

### HTML rendering

Use existing `webview_flutter` (no new package). Load via
`loadHtmlString` with a small wrapper:

- UTF-8 meta, viewport
- `lang` + `dir` from current locale (`ar` → `rtl`)
- Minimal CSS for padding and body font size (system / readable default)
- Inject API `content` as the body HTML

External link clicks inside the WebView: allow default navigation or open
externally — prefer leaving in-WebView for same-origin/simple anchors; do not
block reading the page. (No payment redirect classification needed.)

## Errors

| Case | Behavior |
|------|----------|
| Page fetch fails | Error UI + retry on detail screen; confirm checkbox still usable |
| Unchecked Confirm tap | Snackbar only; no booking API call |
| Booking API error | Unchanged (`BusBookingStatus.error` snackbar) |
| Missing / inactive page (`status != 1`) | Detail screen shows error + retry. Booking gate is **checkbox-only**: the rider may still check the box and book even if they never opened the page or the page failed to load |

## Localization

Add keys to both `app_en.arb` and `app_ar.arb` (then `flutter gen-l10n`):

- Agree label with linked phrase (or split: prefix + link label + suffix if
  ICU/link composition needs it)
- Snackbar: must accept terms
- Fallback titles for terms / privacy / generic page
- Retry / error strings if not already shared

No hardcoded user-facing English in widgets.

## Testing

- Unit: repository/mapper for detail (and list) JSON → entities.
- Widget/unit: terms gate —
  - Confirm disabled when unchecked
  - Tap-while-unchecked shows snackbar (or invokes snackbar callback)
  - Enabled / `onPressed` fires when checked
- Page detail: provider/repo error → error UI path (widget test light; no
  full WebView integration required in v1).

## Out of scope

- Wiring Settings / Profile menu rows to Terms or Privacy
- Flight / private-car confirm screen integration (widget is shared and ready)
- Persisting or sending “accepted terms” to any booking API
- Offline caching of page HTML
- Editing CMS content in-app
- Using `GET /pages` on the booking confirm screen itself

## Success criteria

1. On bus confirm, Confirm & Pay is disabled until terms are checked.
2. Tapping the disabled button area shows a clear must-accept snackbar.
3. Tapping the terms link opens `/pages/terms-and-conditions` with API HTML.
4. `features/pages/` can load any slug (including privacy) for future Settings.
5. No booking API contract changes.
