# Bus Trip Card Dates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a compact calendar date under each clock on the bus results `TripCard`, so midnight and overnight trips are not just a bare `HH:mm`.

**Architecture:** Reuse the DateTimes the clocks already resolve (`stop.arrivalAt ?? trip.dateTime`). Format with existing `formatSearchDateCell`. Always pass a departure date into `_TimeCell`; pass an arrival date only when `!isSameDay(depart, arrive)`. No mapper, entity, provider, or ARB changes.

**Tech Stack:** Flutter widgets, `intl` via `core/utils/date_formatting.dart`, `flutter_test`.

**Spec:** [`docs/superpowers/specs/2026-08-15-bus-trip-card-date-design.md`](../specs/2026-08-15-bus-trip-card-date-design.md)

## Global Constraints

- Bus `TripCard` only — do not add a date to `BookingAppBar`, flight, or car cards.
- No new ARB keys. Locale strings come from `formatSearchDateCell`.
- Date source is the same as the clocks: `_from.arrivalAt ?? trip.dateTime` and `_to.arrivalAt ?? trip.dateTime`.
- Package imports (`package:safaria/...`). `dart format` before commit. Line length 80.
- Phosphor Light icons only if a new icon is added (none expected).
- Do not disable text scaling. Date is one line with ellipsis.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `lib/features/bus/presentation/widgets/trip_card.dart` | **Modify.** Format dates in `build`, pass them into `_Timeline` / `_TimeCell`. |
| `test/features/bus/presentation/trip_card_test.dart` | **Modify.** Same-day, Arabic, and overnight widget tests. |

No new files. `formatSearchDateCell` and `isSameDay` already live in `lib/core/utils/date_formatting.dart`.

---

### Task 1: Departure date under the clock

**Files:**
- Modify: `test/features/bus/presentation/trip_card_test.dart`
- Modify: `lib/features/bus/presentation/widgets/trip_card.dart`

**Interfaces:**
- Consumes: `formatSearchDateCell(DateTime date, String localeName)` from `package:safaria/core/utils/date_formatting.dart`; existing `_departTime` / `_arriveTime` getters; existing `_pumpCard` / `_buildTrip` in the test file (`_buildTrip` is 10 Feb 2026, 08:00 → 12:45 same day).
- Produces: `_TimeCell` accepts optional `String? date`. `_Timeline` accepts `required String departDateLabel`. Same-day cards show that label **once** (departure only).

- [ ] **Step 1: Write the failing tests**

Add this import next to the other `package:safaria/...` imports in
`test/features/bus/presentation/trip_card_test.dart`:

```dart
import 'package:safaria/core/utils/date_formatting.dart';
```

Add these two tests in `main()`, immediately after the existing
`'shows the last drop-off stop and its arrival time on the card'` test:

```dart
  testWidgets('shows a compact date under departure on a same-day trip',
      (tester) async {
    await _pumpCard(tester, _buildTrip());

    final date = formatSearchDateCell(DateTime(2026, 2, 10), 'en');
    expect(find.text(date), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('12:45'), findsOneWidget);
  });

  testWidgets('formats the departure date in Arabic', (tester) async {
    await _pumpCard(
      tester,
      _buildTrip(),
      locale: const Locale('ar'),
    );

    expect(
      find.text(formatSearchDateCell(DateTime(2026, 2, 10), 'ar')),
      findsOneWidget,
    );
    expect(
      find.text(formatSearchDateCell(DateTime(2026, 2, 10), 'en')),
      findsNothing,
    );
  });
```

`findsOneWidget` is the same-day contract: the arrival cell must not
repeat the same date string.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
flutter test test/features/bus/presentation/trip_card_test.dart
```

Expected: FAIL on the new tests — `find.text(...)` finds zero widgets.
Existing tests still pass.

- [ ] **Step 3: Add the date_formatting import**

In `lib/features/bus/presentation/widgets/trip_card.dart`, add after the
theme imports:

```dart
import 'package:safaria/core/utils/date_formatting.dart';
```

- [ ] **Step 4: Pass a departure date into `_Timeline`**

In `_TripCardState.build`, replace the `_Timeline(` call with:

```dart
                _Timeline(
                  trip: widget.trip,
                  l10n: l10n,
                  from: _from,
                  to: _to,
                  departLabel: _departLabel,
                  arriveLabel: _arriveLabel,
                  durationLabel: _durationLabel,
                  departDateLabel: formatSearchDateCell(
                    _departTime,
                    Localizations.localeOf(context).toString(),
                  ),
                  onStopsTap:
                      widget.trip.stopsCount > 0 ? _openStopsSheet : null,
                ),
```

- [ ] **Step 5: Extend `_Timeline` with `departDateLabel`**

Add the field to the constructor and class body of `_Timeline`:

```dart
    required this.departLabel,
    required this.arriveLabel,
    required this.durationLabel,
    required this.departDateLabel,
    this.onStopsTap,
```

```dart
  final String departLabel;
  final String arriveLabel;
  final String durationLabel;
  final String departDateLabel;
  final VoidCallback? onStopsTap;
```

In the clocks `Row`, pass the date only to the departure `_TimeCell`:

```dart
            Expanded(
              flex: 1,
              child: _TimeCell(
                time: departLabel,
                date: departDateLabel,
                alignment: AlignmentDirectional.centerStart,
              ),
            ),
```

Leave the arrival `_TimeCell` as time-only for this task.

- [ ] **Step 6: Extend `_TimeCell` with an optional date line**

Replace the existing `_TimeCell` class with:

```dart
class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.time,
    required this.alignment,
    this.date,
  });

  final String time;
  final String? date;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final isEnd = alignment == AlignmentDirectional.centerEnd;
    final label = date == null ? time : '$time, $date';
    return Align(
      alignment: alignment,
      child: Semantics(
        label: label,
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isEnd
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                time,
                style: AppTypography.title.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (date != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  date!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Format and re-run tests**

Run:

```bash
dart format lib/features/bus/presentation/widgets/trip_card.dart test/features/bus/presentation/trip_card_test.dart
flutter test test/features/bus/presentation/trip_card_test.dart
```

Expected: All tests PASS, including the two new ones.

- [ ] **Step 8: Commit**

```bash
git add lib/features/bus/presentation/widgets/trip_card.dart test/features/bus/presentation/trip_card_test.dart
git commit -m "feat(bus): show compact departure date on trip cards"
```

---

### Task 2: Arrival date on a different calendar day

**Files:**
- Modify: `test/features/bus/presentation/trip_card_test.dart`
- Modify: `lib/features/bus/presentation/widgets/trip_card.dart`

**Interfaces:**
- Consumes: Task 1 `_TimeCell.date` and `_Timeline.departDateLabel`; `isSameDay` from `package:safaria/core/utils/date_formatting.dart`.
- Produces: `_Timeline` also takes `String? arriveDateLabel`. Parent sets it to `formatSearchDateCell(arrive, locale)` when `!isSameDay(depart, arrive)`, otherwise `null`.

- [ ] **Step 1: Write the failing test**

Add this helper next to `_buildTrip` in
`test/features/bus/presentation/trip_card_test.dart`:

```dart
BusTripSummary _buildOvernightTrip() {
  final board = BusStop(
    locationId: '1',
    name: 'Ramsis',
    cityId: 1,
    cityName: 'Cairo',
    arrivalAt: DateTime(2026, 2, 10, 23),
  );
  final drop = BusStop(
    locationId: '9',
    name: 'Sidi Gaber',
    cityId: 2,
    cityName: 'Alexandria',
    arrivalAt: DateTime(2026, 2, 11, 5),
    finalPrice: 180,
  );
  return BusTripSummary(
    id: '290545-night',
    gatewayId: 'Tazcara',
    operatorName: 'Go Bus',
    category: 'VIP',
    dateTime: DateTime(2026, 2, 10, 23),
    currency: 'EGP',
    availableSeats: 6,
    priceStartWith: 180,
    defaultBoardingStop: board,
    defaultDropoffStop: drop,
    boardingStops: [board],
    dropoffStops: [drop],
  );
}
```

`TripCard` uses `terminalDropoffStop` (last drop-off), so a single-item
`dropoffStops` list keeps arrival at 05:00 on 11 Feb.

Add this test immediately after `'formats the departure date in Arabic'`:

```dart
  testWidgets('shows arrival date when it falls on a different day',
      (tester) async {
    await _pumpCard(tester, _buildOvernightTrip());

    expect(
      find.text(formatSearchDateCell(DateTime(2026, 2, 10), 'en')),
      findsOneWidget,
    );
    expect(
      find.text(formatSearchDateCell(DateTime(2026, 2, 11), 'en')),
      findsOneWidget,
    );
    expect(find.text('23:00'), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/features/bus/presentation/trip_card_test.dart
```

Expected: FAIL — `Feb 11` (or whatever `formatSearchDateCell` emits for
11 Feb in `en`) is not on screen. Same-day tests still find exactly one
date.

- [ ] **Step 3: Compute `arriveDateLabel` in `build`**

In `_TripCardState.build`, after `final l10n = AppLocalizations.of(context);`:

```dart
    final localeName = Localizations.localeOf(context).toString();
    final departDateLabel = formatSearchDateCell(_departTime, localeName);
    final arriveDateLabel = isSameDay(_departTime, _arriveTime)
        ? null
        : formatSearchDateCell(_arriveTime, localeName);
```

Pass both into `_Timeline` (remove the inline `formatSearchDateCell`
call from Task 1):

```dart
                _Timeline(
                  trip: widget.trip,
                  l10n: l10n,
                  from: _from,
                  to: _to,
                  departLabel: _departLabel,
                  arriveLabel: _arriveLabel,
                  durationLabel: _durationLabel,
                  departDateLabel: departDateLabel,
                  arriveDateLabel: arriveDateLabel,
                  onStopsTap:
                      widget.trip.stopsCount > 0 ? _openStopsSheet : null,
                ),
```

- [ ] **Step 4: Thread `arriveDateLabel` through `_Timeline`**

Add to the `_Timeline` constructor and fields:

```dart
    required this.departDateLabel,
    this.arriveDateLabel,
```

```dart
  final String departDateLabel;
  final String? arriveDateLabel;
```

Pass it to the arrival `_TimeCell`:

```dart
            Expanded(
              flex: 1,
              child: _TimeCell(
                time: arriveLabel,
                date: arriveDateLabel,
                alignment: AlignmentDirectional.centerEnd,
              ),
            ),
```

Do not special-case inverted times. If the calendar days differ, the
date shows.

- [ ] **Step 5: Format and re-run tests**

Run:

```bash
dart format lib/features/bus/presentation/widgets/trip_card.dart test/features/bus/presentation/trip_card_test.dart
flutter test test/features/bus/presentation/trip_card_test.dart
```

Expected: All tests PASS. Same-day test still `findsOneWidget` for the
single date. Overnight finds both. Arabic test unchanged.

- [ ] **Step 6: Commit**

```bash
git add lib/features/bus/presentation/widgets/trip_card.dart test/features/bus/presentation/trip_card_test.dart
git commit -m "feat(bus): show arrival date on overnight trip cards"
```

---

## Spec coverage

| Spec requirement | Task |
|------------------|------|
| Departure date under departure clock | Task 1 |
| Compact `MMMd` via `formatSearchDateCell` | Task 1 |
| Arabic locale uses the same helper | Task 1 |
| Arrival date only when calendar day differs | Task 2 |
| Same DateTimes as the clocks | Tasks 1–2 (`_departTime` / `_arriveTime`) |
| Caption / muted / `AppSpacing.xxs` / ellipsis | Task 1 `_TimeCell` |
| Semantics groups time + date | Task 1 |
| Dates follow stop changes | Automatic — `_from` / `_to` already drive the getters |
| No app-bar date, no ARB, no mapper change | Global constraints |
| Same-day / overnight / Arabic tests | Tasks 1–2 |
