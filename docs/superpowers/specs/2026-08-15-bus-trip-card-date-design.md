# Bus trip card dates — design

**Date:** 2026-08-15
**Status:** Design approved — ready for an implementation plan.
**Feature slice:** `lib/features/bus/` (results `TripCard` only)

## Goal

The results list shows `HH:mm` with no calendar day. Midnight Super Jet
departures (`00:00` on `2026-08-25`) look like a time with no day, and
overnight arrivals land on a different calendar day with no signal.

Show the compact date under each clock on the trip card, using the same
`DateTime`s the clocks already use.

## Scope

| In | Out |
|----|-----|
| Departure date under the departure clock on every `TripCard` | App-bar / search-date subtitle |
| Arrival date under the arrival clock when the calendar day differs | Flight and private-car cards |
| Compact `MMMd` via existing `formatSearchDateCell` | New ARB keys |
| Dates update when the rider changes boarding/drop-off | Changing `date` / `date_time` parsing |
| Widget tests on `TripCard` | Confirm / e-ticket / order screens (already show a date) |

## Decisions (from brainstorming)

| Topic | Choice |
|---|---|
| Which dates | Departure always; arrival only on a different calendar day |
| Placement | On each card, under the clocks — not in the app bar |
| Format | Compact `MMMd` (`25 Aug` / locale Arabic equivalent) |
| Approach | Extend `_TimeCell` (date under the existing `HH:mm`) |
| Date source | Same as clocks: `stop.arrivalAt ?? trip.dateTime` |
| Same-day test | `isSameDay` from `core/utils/date_formatting.dart` |

Rejected:

- A dedicated date row between stations and clocks — overnight arrival would
  not sit under the arrival time.
- Date under the station name — mixes place with schedule; clocks stay
  date-less.

## Behaviour

Clocks already resolve:

```
depart = from.arrivalAt ?? trip.dateTime
arrive = to.arrivalAt   ?? trip.dateTime
```

Rules:

1. Always render `formatSearchDateCell(depart, locale)` under the departure
   clock.
2. Render `formatSearchDateCell(arrive, locale)` under the arrival clock
   **only if** `!isSameDay(depart, arrive)`.
3. Locale is `Localizations.localeOf(context).toString()` — same helper the
   home search date cell uses. No new strings.
4. Changing boarding or drop-off in the stops sheet updates `_from` / `_to`,
   so both clocks and dates follow the selected stops.
5. If `arrivalAt` is missing, both clocks fall back to `trip.dateTime`, so
   they are the same calendar day and the arrival date stays hidden.

Do not special-case inverted times (arrive before depart). If the calendar
days differ, show the arrival date.

## Layout

`_TimeCell` grows a second line:

- Time: existing `AppTypography.title`, weight 800, `AppColors.textPrimary`.
- Date: `AppTypography.caption`, `AppColors.textMuted`, weight 600.
- Alignment: same `AlignmentDirectional` as the clock (start for depart,
  end for arrive).
- Gap: `AppSpacing.xxs` between time and date.

The timeline row stays three columns (depart | connector | arrive). The
date must not wrap onto a second visual column or crush the duration
label. One line, ellipsis if a large text scale overflows.

Group time + date in one `Semantics` node so a screen reader announces
them together (e.g. "00:00, 25 Aug").

## Files

| File | Change |
|------|--------|
| `lib/features/bus/presentation/widgets/trip_card.dart` | Pass locale-formatted dates into `_Timeline` / `_TimeCell` |
| `test/features/bus/presentation/trip_card_test.dart` | Same-day, overnight, and Arabic locale cases |

No mapper, entity, provider, or ARB changes.

## Tests

Pump `TripCard` as today (`_pumpCard` in `trip_card_test.dart`).

1. **Same-day** (existing fixture: 10 Feb 08:00 → 12:45) — shows one compact
   date (`Feb 10` in `en`). Arrival cell has the time only.
2. **Overnight** — depart 10 Feb 23:00, arrive 11 Feb 05:00. Shows `Feb 10`
   under depart and `Feb 11` under arrive.
3. **Arabic** — same-day card under `Locale('ar')` shows
   `formatSearchDateCell` for that locale, not the English string.

Exact `DateFormat.MMMd` output is asserted via the same helper the widget
calls, so the test does not hard-code a brittle glyph.

## Out of scope (explicit)

- Search date in `BookingAppBar`
- `+1` / "next day" copy instead of a real date
- Eastern vs Western digits beyond whatever `DateFormat.MMMd(locale)`
  already does on home
- Showing the date on the loading skeleton cards
