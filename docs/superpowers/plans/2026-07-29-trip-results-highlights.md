# Trip Results Fastest / Cheapest Marks — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flag cheapest/fastest (and best-deal) bus trips on results cards, and add Cheapest/Fastest filter chips that narrow + pin without clearing the marks.

**Architecture:** Pure domain `computeTripHighlights` + `sortTripsWithHighlights`; extend `BusTripFilters` / `applyBusTripFilters`; wire in `TripResultsScreen`; header badge on `TripCard`; toggles in filter sheet.

**Tech Stack:** Flutter, Riverpod, Freezed, `flutter_test`, ARB l10n

**Spec:** `docs/superpowers/specs/2026-07-29-trip-results-highlights-design.md`

---

## File map

| File | Responsibility |
|---|---|
| `lib/features/bus/domain/entities/trip_highlight.dart` | `TripHighlight` enum |
| `lib/features/bus/domain/utils/compute_trip_highlights.dart` | Compute map + optional pin-sort |
| `lib/features/bus/domain/entities/bus_trip_filters.dart` | `cheapest`/`fastest` fields, chips, removeChip, isActive |
| `lib/features/bus/domain/utils/apply_bus_trip_filters.dart` | Match highlight flags; active count |
| `lib/features/bus/presentation/widgets/trip_card.dart` | Header badge |
| `lib/features/bus/presentation/widgets/trip_filter_sheet.dart` | Toggle rows |
| `lib/features/bus/presentation/trip_results_screen.dart` | Wire highlights + sort |
| `lib/l10n/app_en.arb` / `app_ar.arb` | Fastest + Best deal (+ filter section) keys |
| `test/features/bus/domain/compute_trip_highlights_test.dart` | Unit tests |
| `test/features/bus/domain/apply_bus_trip_filters_test.dart` | Highlight filter tests |
| `test/features/bus/presentation/trip_card_test.dart` | Badge widget tests |

**Pin-sort rule:** Apply `sortTripsWithHighlights` only when `filters.cheapest || filters.fastest`; otherwise keep departure-time order (no auto-sort without filter).

---

### Task 1: `TripHighlight` + `computeTripHighlights` (TDD)

**Files:**
- Create: `lib/features/bus/domain/entities/trip_highlight.dart`
- Create: `lib/features/bus/domain/utils/compute_trip_highlights.dart`
- Create: `test/features/bus/domain/compute_trip_highlights_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/bus/domain/entities/bus_stop.dart';
import 'package:safaria/features/bus/domain/entities/bus_trip.dart';
import 'package:safaria/features/bus/domain/entities/trip_highlight.dart';
import 'package:safaria/features/bus/domain/utils/compute_trip_highlights.dart';

BusTripSummary _trip({
  required String id,
  required DateTime depart,
  required DateTime arrive,
  required int priceEgp,
}) {
  return BusTripSummary(
    id: id,
    gatewayId: 'gw',
    operatorName: 'Op',
    category: 'VIP',
    dateTime: depart,
    currency: 'EGP',
    defaultBoardingStop: BusStop(
      locationId: 'b$id',
      name: 'Board',
      cityId: 1,
      cityName: 'Cairo',
      arrivalAt: depart,
    ),
    defaultDropoffStop: BusStop(
      locationId: 'd$id',
      name: 'Drop',
      cityId: 2,
      cityName: 'Alex',
      arrivalAt: arrive,
      finalPrice: priceEgp.toDouble(),
    ),
  );
}

void main() {
  test('empty list yields empty map', () {
    expect(computeTripHighlights(const []), isEmpty);
  });

  test('single trip is bestDeal', () {
    final t = _trip(
      id: 'a',
      depart: DateTime(2026, 7, 10, 8),
      arrive: DateTime(2026, 7, 10, 10),
      priceEgp: 100,
    );
    expect(computeTripHighlights([t])['a'], TripHighlight.bestDeal);
  });

  test('ties mark every cheapest and every fastest; both → bestDeal', () {
    final cheapFast = _trip(
      id: 'cf',
      depart: DateTime(2026, 7, 10, 8),
      arrive: DateTime(2026, 7, 10, 10),
      priceEgp: 100,
    );
    final cheapSlow = _trip(
      id: 'cs',
      depart: DateTime(2026, 7, 10, 9),
      arrive: DateTime(2026, 7, 10, 13),
      priceEgp: 100,
    );
    final priceyFast = _trip(
      id: 'pf',
      depart: DateTime(2026, 7, 10, 10),
      arrive: DateTime(2026, 7, 10, 12),
      priceEgp: 200,
    );
    final map = computeTripHighlights([cheapFast, cheapSlow, priceyFast]);
    expect(map['cf'], TripHighlight.bestDeal);
    expect(map['cs'], TripHighlight.cheapest);
    expect(map['pf'], TripHighlight.fastest);
  });

  test('sortTripsWithHighlights pins bestDeal then other marks then rest', () {
    final rest = _trip(
      id: 'r',
      depart: DateTime(2026, 7, 10, 7),
      arrive: DateTime(2026, 7, 10, 12),
      priceEgp: 300,
    );
    final cheapest = _trip(
      id: 'c',
      depart: DateTime(2026, 7, 10, 9),
      arrive: DateTime(2026, 7, 10, 14),
      priceEgp: 100,
    );
    final best = _trip(
      id: 'b',
      depart: DateTime(2026, 7, 10, 10),
      arrive: DateTime(2026, 7, 10, 12),
      priceEgp: 100,
    );
    final trips = [rest, cheapest, best];
    final highlights = computeTripHighlights(trips);
    final sorted = sortTripsWithHighlights(trips, highlights);
    expect(sorted.map((t) => t.id), ['b', 'c', 'r']);
  });
}
```

- [ ] **Step 2: Run tests — expect FAIL**

```bash
flutter test test/features/bus/domain/compute_trip_highlights_test.dart
```

- [ ] **Step 3: Implement**

`trip_highlight.dart`:

```dart
enum TripHighlight { cheapest, fastest, bestDeal }
```

`compute_trip_highlights.dart`:

```dart
import 'package:safaria/features/bus/domain/entities/bus_trip.dart';
import 'package:safaria/features/bus/domain/entities/trip_highlight.dart';

Map<String, TripHighlight> computeTripHighlights(
  List<BusTripSummary> trips,
) {
  if (trips.isEmpty) return {};
  var minPrice = trips.first.terminalPriceEgp;
  var minDuration = trips.first.durationMin;
  for (final t in trips.skip(1)) {
    if (t.terminalPriceEgp < minPrice) minPrice = t.terminalPriceEgp;
    if (t.durationMin < minDuration) minDuration = t.durationMin;
  }
  final map = <String, TripHighlight>{};
  for (final t in trips) {
    final cheap = t.terminalPriceEgp == minPrice;
    final fast = t.durationMin == minDuration;
    if (cheap && fast) {
      map[t.id] = TripHighlight.bestDeal;
    } else if (cheap) {
      map[t.id] = TripHighlight.cheapest;
    } else if (fast) {
      map[t.id] = TripHighlight.fastest;
    }
  }
  return map;
}

int _highlightRank(TripHighlight? h) {
  return switch (h) {
    TripHighlight.bestDeal => 0,
    TripHighlight.cheapest || TripHighlight.fastest => 1,
    null => 2,
  };
}

List<BusTripSummary> sortTripsWithHighlights(
  List<BusTripSummary> trips,
  Map<String, TripHighlight> highlights,
) {
  final list = [...trips];
  list.sort((a, b) {
    final ra = _highlightRank(highlights[a.id]);
    final rb = _highlightRank(highlights[b.id]);
    if (ra != rb) return ra.compareTo(rb);
    return a.departTime.compareTo(b.departTime);
  });
  return list;
}

bool tripMatchesHighlightFilter({
  required TripHighlight? highlight,
  required bool cheapest,
  required bool fastest,
}) {
  if (!cheapest && !fastest) return true;
  if (highlight == null) return false;
  final matchCheap = cheapest &&
      (highlight == TripHighlight.cheapest ||
          highlight == TripHighlight.bestDeal);
  final matchFast = fastest &&
      (highlight == TripHighlight.fastest ||
          highlight == TripHighlight.bestDeal);
  return matchCheap || matchFast;
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
flutter test test/features/bus/domain/compute_trip_highlights_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/bus/domain/entities/trip_highlight.dart \
  lib/features/bus/domain/utils/compute_trip_highlights.dart \
  test/features/bus/domain/compute_trip_highlights_test.dart \
  docs/superpowers/specs/2026-07-29-trip-results-highlights-design.md
git commit -m "feat(bus): compute cheapest/fastest trip highlights"
```

---

### Task 2: Extend filters + apply (TDD)

**Files:**
- Modify: `lib/features/bus/domain/entities/bus_trip_filters.dart`
- Modify: `lib/features/bus/domain/utils/apply_bus_trip_filters.dart`
- Modify: `test/features/bus/domain/apply_bus_trip_filters_test.dart`
- Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 1: Extend failing filter tests**

Add to `apply_bus_trip_filters_test.dart` (trips need `arrivalAt` on drop for duration; extend `_trip` helper with optional `arrive` / duration via dropoff `arrivalAt`):

```dart
test('cheapest filter keeps cheapest and bestDeal only', () {
  // build three trips with known highlights; pass highlights map
});

test('both highlight filters keep union', () { ... });

test('busTripFilterActiveCount includes cheapest/fastest', () {
  expect(
    busTripFilterActiveCount(
      const BusTripFilters(cheapest: true, fastest: true),
    ),
    2,
  );
});
```

Update `applyBusTripFilters` signature:

```dart
List<BusTripSummary> applyBusTripFilters(
  List<BusTripSummary> trips,
  BusTripFilters filters, {
  Map<String, TripHighlight> highlights = const {},
})
```

- [ ] **Step 2: Run — expect FAIL / compile errors**

- [ ] **Step 3: Implement filters**

In `BusTripFilters`:
- Add `@Default(false) bool cheapest` and `@Default(false) bool fastest`
- Update `isActive`, `activeChips`, `removeChip`
- Add `ActiveFilterChipKind.cheapest` / `.fastest`

In `apply_bus_trip_filters.dart`:
- Count +2 for flags
- In `_matches`, after price check, call `tripMatchesHighlightFilter`

Regenerate freezed:

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 4: Run filter tests — PASS**

```bash
flutter test test/features/bus/domain/apply_bus_trip_filters_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/bus/domain/entities/bus_trip_filters.dart \
  lib/features/bus/domain/utils/apply_bus_trip_filters.dart \
  test/features/bus/domain/apply_bus_trip_filters_test.dart
git commit -m "feat(bus): add cheapest/fastest trip filter flags"
```

---

### Task 3: Localization

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`

- [ ] **Step 1: Add keys**

EN:
- `tripResultsHighlightFastest`: "Fastest"
- `tripResultsHighlightBestDeal`: "Best deal"
- `tripFilterHighlights`: "Highlights" (section title)
- Reuse `tripResultsSortCheapest` for cheapest badge/chip label

AR:
- `tripResultsHighlightFastest`: "الأسرع"
- `tripResultsHighlightBestDeal`: "أفضل عرض"
- `tripFilterHighlights`: "المميزات"

- [ ] **Step 2: `flutter gen-l10n`**

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "feat(bus): localize trip highlight badges and filter"
```

---

### Task 4: TripCard badge (TDD)

**Files:**
- Modify: `lib/features/bus/presentation/widgets/trip_card.dart`
- Modify: `test/features/bus/presentation/trip_card_test.dart`

- [ ] **Step 1: Failing widget test** — pump card with `highlight: TripHighlight.cheapest`, expect `tripResultsSortCheapest` text; with `null`, expect no highlight texts.

- [ ] **Step 2: Implement** — `TripCard({ ..., this.highlight })`; in `_Header` trailing pill; switch colors per spec; label via l10n.

- [ ] **Step 3: `flutter test test/features/bus/presentation/trip_card_test.dart` — PASS**

- [ ] **Step 4: Commit**

```bash
git commit -am "feat(bus): show highlight badge on trip card header"
```

---

### Task 5: Filter sheet toggles + results wire-up

**Files:**
- Modify: `lib/features/bus/presentation/widgets/trip_filter_sheet.dart`
- Modify: `lib/features/bus/presentation/trip_results_screen.dart`
- Modify: `test/features/bus/presentation/trip_results_screen_test.dart` (if present)

- [ ] **Step 1: Filter sheet** — section `tripFilterHighlights` with two `SwitchListTile`s (or `Switch` + label) for cheapest/fastest; Clear-all already resets via `const BusTripFilters()`.

- [ ] **Step 2: Results screen**

```dart
final highlights = computeTripHighlights(state.trips);
final filtered = applyBusTripFilters(
  state.trips,
  _filters,
  highlights: highlights,
);
// empty handling...
var trips = _byDepartureTime(filtered);
if (_filters.cheapest || _filters.fastest) {
  trips = sortTripsWithHighlights(trips, highlights);
}
// TripCard(..., highlight: highlights[trips[i].id])
```

- [ ] **Step 3: Run**

```bash
flutter test test/features/bus/
flutter analyze lib/features/bus lib/l10n
```

- [ ] **Step 4: Commit**

```bash
git commit -am "feat(bus): wire highlight filters and badges on trip results"
```

---

### Task 6: Spec/plan docs commit (if not already)

- [ ] Ensure plan file committed:

```bash
git add docs/superpowers/plans/2026-07-29-trip-results-highlights.md
git commit -m "docs: add trip results highlights implementation plan"
```

---

## Spec coverage check

| Spec requirement | Task |
|---|---|
| compute highlights / ties / bestDeal | 1 |
| filter flags + chips + union | 2, 5 |
| pin sort when filter on | 1, 5 |
| marks survive clear | 5 (highlights from `state.trips`) |
| header badge + colors + l10n | 3, 4 |
| filter sheet toggles | 5 |
| tests | 1, 2, 4 |

## Self-review

- No TBD placeholders.
- `applyBusTripFilters` gains optional `highlights` — all call sites updated in Task 5; existing tests pass `{}` default.
- Pin only when highlight filters active — matches “no auto-sort” out of scope.
