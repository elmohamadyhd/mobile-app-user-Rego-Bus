# REGO BUSES — App Screens Design Kit

**Date:** 2026-06-25
**Status:** In progress
**Deliverable:** Standalone HTML design kit under `design/`, opened in a browser, used as the visual reference for the Flutter build.

---

## Goal

Design every screen of the REGO BUSES mobile app (the "Wadeny" multi-modal travel platform) as
high-fidelity HTML mockups, matching the brand logo and covering all business domains.

## Decisions made (brainstorming)

| Decision | Choice | Why |
|----------|--------|-----|
| Visual direction | **"Skyline"** — immersive blue gradient hero + floating white search card | Picked by user over Aurora (light/bento) and Midnight (dark) |
| Fidelity | **Rich**: real gradients, soft shadows, glow | User explicitly rejected the flat look; wants the gradient mockup feel |
| Tooling | **Standalone HTML** in `design/` (not Claude's flat canvas, not Figma) | Claude canvas forbids gradients/shadows; HTML gives full fidelity + lives in repo |
| Language / layout | **Arabic, RTL first** | Primary audience is Arabic speakers (MENA); `Accept-Language: ar` |
| Icons | Tabler outline webfont (CDN) | Consistent, professional, no emoji |
| Font | Tajawal (Google Fonts) | Clean modern Arabic + Latin |

## Design tokens (see `design/styles.css`)

- **Brand blue** `#1464EC` (dark `#0E50C7`, deepest `#0A3FA3`) — from the existing app
- **Amber accent** `#F0B256` (dark `#D98A2B`) — the logo's "BUS" color
- **Hero gradient** `linear-gradient(160deg,#1D6FF2,#0E50C7,#0A3FA3)`
- **Surfaces** bg `#F4F6FB`, cards white, ink `#141831`, muted `#8A90A6`
- **Radius** cards 24px, inputs 15px, pills 100px
- **Signature components** blue hero (rounded bottom), floating lifted card (`-126px` overlap),
  segmented transport tabs (باص / طيران / نقل), from→to field with swap button, floating bottom
  nav with raised search FAB, OTP boxes, popular-destination cards.

## Screen inventory (~30 screens, 6 batches)

| Batch | File | Screens |
|-------|------|---------|
| 1 — Auth | `design/01-auth.html` | Splash · Onboarding · Login · Register · OTP verify · Forgot password · New password |
| 2 — Home & Bus | `design/02-home-bus.html` | Home · Trip results · Trip details · Seat selection · Passenger & confirm · E-ticket |
| 3 — Flights | `design/03-flights.html` | Flight search · Results · Fare bundles · Passenger details · Hold/review · Payment |
| 4 — Transfer & Wallet | `design/04-transfer-wallet.html` | Transfer search (map) · Transfer confirm · Wallet · Top-up |
| 5 — Support & Profile | `design/05-support-profile.html` | Tickets list · Ticket chat · New ticket · Profile · Edit profile · Address book · Settings |
| 6 — Content | `design/06-content.html` | Notifications · Posts/blog list · Post detail · FAQ |

`design/index.html` — landing page: brand, design-system showcase (colors, type, components), links to each batch.

## How to view

Open `design/index.html` in any browser (needs internet for the Tabler/Tajawal CDNs).
Each batch file shows its screens in a phone-frame gallery.

## Mapping to APIs (reference)

Screens map to the documented Wadeny endpoints (`docs/wadeny-apis.md`): auth group → Auth batch;
`/buses/*` → Home & Bus; `/flights/*` → Flights; `/private/*` → Transfer; `/profile/wallet` → Wallet;
`/profile/tickets/*` → Support; `/profile`, `/profile/address-book` → Profile; `/banners`,`/posts`,`/faq` → Content.

## Out of scope (for now)

Real implementation in Flutter, animations/motion specs, and pixel-perfect asset export — this kit
is the visual blueprint that those steps will follow.
