# Bus Progressive Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the bus results screen keep filling in for ~15 seconds after the first response, so riders stop being shown a truncated list of trips as if it were the complete answer.

**Architecture:** `BusBookingNotifier` runs three extra searches at a fixed 5-second gap after the first one, merging each response into the list by trip id instead of replacing it. Trips found after the first round land in a staging list and are revealed either automatically (rider is at the top of the list) or on tap of a "N new trips" pill, so nothing moves under the rider's finger. A generation counter drops responses belonging to a superseded search.

**Tech Stack:** Flutter, Riverpod (`Notifier`), Freezed, `dart:async` `Timer`, `flutter_test`.

**Spec:** [`docs/superpowers/specs/2026-08-15-bus-progressive-search-design.md`](../specs/2026-08-15-bus-progressive-search-design.md)

---

## File Structure

| File | Responsibility |
|------|----------------|
| `lib/features/bus/domain/utils/merge_bus_trips.dart` | **Create.** Pure upsert-by-id fold of a search round into a list. No Flutter, no Riverpod — the whole merge rule lives here and is unit-tested in isolation. |
| `lib/features/bus/presentation/providers/bus_booking_providers.dart` | **Modify.** Phase enum, schedule config, three new state fields, the polling loop, and the cancellation rules. |
| `lib/features/bus/presentation/widgets/trip_search_status_strip.dart` | **Create.** Renders the phase: progress bar, nothing, or the slow-operators message plus refresh button. Stateless, takes a phase and a callback. |
| `lib/features/bus/presentation/widgets/new_trips_pill.dart` | **Create.** The floating "N new trips" affordance. Stateless, takes a count and a callback. |
| `lib/features/bus/presentation/trip_results_screen.dart` | **Modify.** Wires the two widgets, the scroll listener, and the lifecycle listener. |
| `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` | **Modify.** Four new strings. |
| `test/features/bus/fake_bus_repository.dart` | **Modify.** A queue of successive pages and a per-call failure switch — without these, none of the round behaviour is testable. |

Merge logic is deliberately **not** a private method on the notifier: it is the part most likely to be wrong, and a pure function is the cheapest thing to test exhaustively.

---

### Task 1: Search phase, schedule, and state fields

**Files:**
- Modify: `lib/features/bus/presentation/providers/bus_booking_providers.dart:17-59`
- Test: `test/features/bus/bus_booking_notifier_test.dart`

- [ ] **Step 1: Write the failing test**

Add inside the `group('BusBookingNotifier', ...)` block in `test/features/bus/bus_booking_notifier_test.dart`:

```dart
    test('initial state is not searching and has nothing staged', () {
      final container = makeContainer(FakeBusRepository());
      final state = container.read(busBookingProvider);
      expect(state.searchPhase, BusSearchPhase.idle);
      expect(state.stagedTrips, isEmpty);
      expect(state.searchGeneration, 0);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/bus/bus_booking_notifier_test.dart`
Expected: FAIL — `Undefined name 'BusSearchPhase'`.

- [ ] **Step 3: Add the enum and schedule config**

In `bus_booking_providers.dart`, directly below the existing `enum PaymentMethod { visa, wallet }` line:

```dart
/// Lifecycle of the progressive search window, kept separate from
/// [BusBookingStatus] so the existing error view, skeleton, and filter code
/// keep reading exactly the field they read today.
enum BusSearchPhase { idle, polling, complete, exhausted }

/// Schedule for the follow-up search rounds.
///
/// The aggregating backend answers with whatever operator inventory has landed
/// so far, and was observed to have more roughly 5 seconds later. These numbers
/// are a starting point to re-tune from measurement, not a result — which is
/// also why they are injected rather than hardcoded: tests override the gap to
/// zero instead of pulling in a fake clock.
class BusSearchSchedule {
  const BusSearchSchedule({
    this.gap = const Duration(seconds: 5),
    this.rounds = 3,
  });

  final Duration gap;
  final int rounds;
}

final busSearchScheduleProvider =
    Provider<BusSearchSchedule>((ref) => const BusSearchSchedule());
```

- [ ] **Step 4: Add the three state fields**

In `BusBookingState`, directly after the existing `String? searchToLabel,` line and before the closing `}) = _BusBookingState;`:

```dart
    @Default(BusSearchPhase.idle) BusSearchPhase searchPhase,
    @Default([]) List<BusTripSummary> stagedTrips,
    @Default(0) int searchGeneration,
```

- [ ] **Step 5: Regenerate Freezed output**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `Succeeded after …` with `bus_booking_providers.freezed.dart` rewritten.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/bus/bus_booking_notifier_test.dart`
Expected: PASS, all tests in the file.

- [ ] **Step 7: Commit**

```bash
git add lib/features/bus/presentation/providers/bus_booking_providers.dart test/features/bus/bus_booking_notifier_test.dart
git commit -m "feat(bus): add search phase and staging fields to booking state"
```

---

### Task 2: The merge function

**Files:**
- Create: `lib/features/bus/domain/utils/merge_bus_trips.dart`
- Test: `test/features/bus/domain/merge_bus_trips_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/bus/domain/merge_bus_trips_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/bus/domain/entities/bus_trip.dart';
import 'package:safaria/features/bus/domain/utils/merge_bus_trips.dart';

import '../fake_bus_repository.dart';

BusTripSummary _trip(String id, {double price = 100}) {
  return FakeBusRepository.sampleTrip.copyWith(id: id, priceStartWith: price);
}

void main() {
  group('mergeBusTrips', () {
    test('appends unseen trips and reports a change', () {
      final result = mergeBusTrips([_trip('a')], [_trip('b')]);

      expect(result.trips.map((t) => t.id), ['a', 'b']);
      expect(result.changed, isTrue);
    });

    test('replaces a trip whose price moved and reports a change', () {
      final result = mergeBusTrips(
        [_trip('a', price: 100)],
        [_trip('a', price: 120)],
      );

      expect(result.trips, hasLength(1));
      expect(result.trips.single.priceStartWith, 120);
      expect(result.changed, isTrue);
    });

    test('reports no change when the round repeats what is already held', () {
      final result = mergeBusTrips([_trip('a')], [_trip('a')]);

      expect(result.trips.map((t) => t.id), ['a']);
      expect(result.changed, isFalse);
    });

    test('keeps a trip that disappeared from the newer round', () {
      final result = mergeBusTrips([_trip('a'), _trip('b')], [_trip('a')]);

      expect(result.trips.map((t) => t.id), ['a', 'b']);
      expect(result.changed, isFalse);
    });

    test('preserves first-seen order across several rounds', () {
      final first = mergeBusTrips([], [_trip('c'), _trip('a')]);
      final second = mergeBusTrips(first.trips, [_trip('b')]);

      expect(second.trips.map((t) => t.id), ['c', 'a', 'b']);
    });

    test('collapses ids duplicated in the existing list', () {
      final result = mergeBusTrips([_trip('a'), _trip('a')], []);

      expect(result.trips.map((t) => t.id), ['a']);
      expect(result.changed, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/bus/domain/merge_bus_trips_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:safaria/features/bus/domain/utils/merge_bus_trips.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/features/bus/domain/utils/merge_bus_trips.dart`:

```dart
import 'package:safaria/features/bus/domain/entities/bus_trip.dart';

/// Outcome of folding one search round into a list already held.
typedef BusTripMerge = ({List<BusTripSummary> trips, bool changed});

/// Upserts [incoming] into [existing], keyed on trip id.
///
/// `/buses/trips` aggregates several operator APIs and answers with whatever
/// has landed so far, so a later round is usually — but not reliably — a
/// superset of an earlier one. The merge therefore adds and replaces but never
/// removes: a trip that drops out of a later response stays on screen rather
/// than vanishing while the rider is looking at it.
///
/// [changed] is true when an id was added, or an existing entry was replaced by
/// a non-equal one (price and seat counts go stale between rounds). It is what
/// the caller's "two quiet rounds means the search settled" rule reads.
BusTripMerge mergeBusTrips(
  List<BusTripSummary> existing,
  List<BusTripSummary> incoming,
) {
  final byId = <String, BusTripSummary>{};
  final order = <String>[];

  for (final trip in existing) {
    if (byId.containsKey(trip.id)) continue;
    byId[trip.id] = trip;
    order.add(trip.id);
  }

  var changed = false;
  for (final trip in incoming) {
    final held = byId[trip.id];
    if (held == null) {
      byId[trip.id] = trip;
      order.add(trip.id);
      changed = true;
    } else if (held != trip) {
      byId[trip.id] = trip;
      changed = true;
    }
  }

  return (trips: [for (final id in order) byId[id]!], changed: changed);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/bus/domain/merge_bus_trips_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bus/domain/utils/merge_bus_trips.dart test/features/bus/domain/merge_bus_trips_test.dart
git commit -m "feat(bus): add id-keyed trip merge for progressive search rounds"
```

---

### Task 3: Test harness for successive rounds

**Files:**
- Modify: `test/features/bus/fake_bus_repository.dart:14-23` (constructor) and `:72-82` (`searchTrips`)

No test of its own — this is scaffolding the next four tasks consume. It is a separate task so its diff stays reviewable.

- [ ] **Step 1: Add the queue and failure fields**

In `test/features/bus/fake_bus_repository.dart`, add `this.tripsPageQueue,` to the constructor parameter list directly after `this.tripsPage,`, then add these fields next to the existing `BusTripsPage? tripsPage;`:

```dart
  /// Successive `searchTrips` results, one per call. Once the queue runs dry
  /// the last entry repeats — which is what a settled aggregator looks like.
  List<BusTripsPage>? tripsPageQueue;

  /// Zero-based indices of `searchTrips` calls that should throw instead.
  Set<int> failingSearchCalls = {};

  int searchTripsCallCount = 0;
```

- [ ] **Step 2: Replace `searchTrips`**

Replace the existing `searchTrips` override with:

```dart
  @override
  Future<BusTripsPage> searchTrips(BusSearchParams params, {int page = 1}) {
    final index = searchTripsCallCount++;
    if (failingSearchCalls.contains(index)) {
      return Future.error(
        const ApiException('search failed', statusCode: 500),
      );
    }
    final queue = tripsPageQueue;
    if (queue != null && queue.isNotEmpty) {
      return Future.value(queue[index < queue.length ? index : queue.length - 1]);
    }
    return Future.value(
      tripsPage ??
          const BusTripsPage(
            trips: [],
            currentPage: 1,
            lastPage: 1,
          ),
    );
  }
```

`ApiException` is already imported at the top of this file.

- [ ] **Step 3: Verify nothing regressed**

Run: `flutter test test/features/bus/`
Expected: PASS — the existing suite is untouched because `tripsPageQueue` defaults to null.

- [ ] **Step 4: Commit**

```bash
git add test/features/bus/fake_bus_repository.dart
git commit -m "test(bus): let the fake repository return successive search rounds"
```

---

### Task 4: Run the follow-up rounds and stage arrivals

**Files:**
- Modify: `lib/features/bus/presentation/providers/bus_booking_providers.dart:61-90`
- Test: `test/features/bus/bus_booking_notifier_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to the top of `test/features/bus/bus_booking_notifier_test.dart`, below the existing imports:

```dart
BusTripSummary _trip(String id, {double price = 100}) {
  return FakeBusRepository.sampleTrip.copyWith(id: id, priceStartWith: price);
}

BusTripsPage _page(List<BusTripSummary> trips) {
  return BusTripsPage(trips: trips, currentPage: 1, lastPage: 1);
}

Future<void> _search(BusBookingNotifier notifier) {
  return notifier.searchTrips(
    BusSearchParams(cityFromId: 1, cityToId: 2, date: DateTime(2026, 7, 10)),
  );
}
```

Replace the body of `makeContainer` so tests can pick their own gap. The default
of zero runs the whole window inside a `pumpEventQueue`; cancellation tests pass
a long gap instead, so a round provably cannot fire while they assert:

```dart
  ProviderContainer makeContainer(
    FakeBusRepository repo, {
    Duration gap = Duration.zero,
  }) {
    final container = ProviderContainer(
      overrides: [
        busRepositoryProvider.overrideWithValue(repo),
        busSearchScheduleProvider.overrideWithValue(
          BusSearchSchedule(gap: gap),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }
```

Then add a new group at the end of `main()`:

```dart
  group('BusBookingNotifier progressive search', () {
    test('round 0 renders immediately and enters the polling phase', () async {
      final repo = FakeBusRepository(
        tripsPageQueue: [
          _page([_trip('a')]),
          _page([_trip('a'), _trip('b')]),
        ],
      );
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);

      final state = container.read(busBookingProvider);
      expect(state.trips.map((t) => t.id), ['a']);
      expect(state.searchPhase, BusSearchPhase.polling);
      expect(state.status, BusBookingStatus.idle);
    });

    test('trips found in later rounds are staged, not shown', () async {
      final repo = FakeBusRepository(
        tripsPageQueue: [
          _page([_trip('a')]),
          _page([_trip('a'), _trip('b')]),
        ],
      );
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      await pumpEventQueue();

      final state = container.read(busBookingProvider);
      expect(state.trips.map((t) => t.id), ['a']);
      expect(state.stagedTrips.map((t) => t.id), ['b']);
    });

    test('arrivals go straight in while nothing is on screen yet', () async {
      final repo = FakeBusRepository(
        tripsPageQueue: [
          _page([]),
          _page([_trip('a')]),
        ],
      );
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      await pumpEventQueue();

      final state = container.read(busBookingProvider);
      expect(state.trips.map((t) => t.id), ['a']);
      expect(state.stagedTrips, isEmpty);
    });

    test('a price change on a visible trip updates it in place', () async {
      final repo = FakeBusRepository(
        tripsPageQueue: [
          _page([_trip('a', price: 100)]),
          _page([_trip('a', price: 120)]),
        ],
      );
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      await pumpEventQueue();

      final state = container.read(busBookingProvider);
      expect(state.trips.single.priceStartWith, 120);
      expect(state.stagedTrips, isEmpty);
    });

    test('two quiet rounds settle the search as complete', () async {
      final repo = FakeBusRepository(tripsPage: _page([_trip('a')]));
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      await pumpEventQueue();

      final state = container.read(busBookingProvider);
      expect(state.searchPhase, BusSearchPhase.complete);
      // Round 0 plus the two quiet rounds — the third never runs.
      expect(repo.searchTripsCallCount, 3);
    });

    test('revealStagedTrips moves staged trips into the visible list', () async {
      final repo = FakeBusRepository(
        tripsPageQueue: [
          _page([_trip('a')]),
          _page([_trip('a'), _trip('b')]),
        ],
      );
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      await pumpEventQueue();
      notifier.revealStagedTrips();

      final state = container.read(busBookingProvider);
      expect(state.trips.map((t) => t.id), ['a', 'b']);
      expect(state.stagedTrips, isEmpty);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/bus/bus_booking_notifier_test.dart`
Expected: FAIL — `The method 'revealStagedTrips' isn't defined` and `busSearchScheduleProvider` overrides having no effect on a notifier that never polls.

- [ ] **Step 3: Add the imports and the polling machinery**

Add to the top of `bus_booking_providers.dart`, above the existing `import 'package:freezed_annotation/...'`:

```dart
import 'dart:async';
```

and alongside the other feature imports:

```dart
import 'package:safaria/features/bus/domain/utils/merge_bus_trips.dart';
```

Replace the opening of `BusBookingNotifier` (the `_repo` getter, `build`, and `searchTrips`) with:

```dart
class BusBookingNotifier extends Notifier<BusBookingState> {
  BusRepository get _repo => ref.read(busRepositoryProvider);
  BusSearchSchedule get _schedule => ref.read(busSearchScheduleProvider);

  /// Rounds finding nothing new before the search is called settled.
  static const _quietRoundsToComplete = 2;

  /// Consecutive round failures before the window gives up.
  static const _maxConsecutiveFailures = 3;

  Timer? _pollTimer;

  @override
  BusBookingState build() {
    ref.onDispose(_cancelPolling);
    return const BusBookingState();
  }

  Future<void> searchTrips(BusSearchParams params) async {
    _cancelPolling();
    final generation = state.searchGeneration + 1;
    state = state.copyWith(
      status: BusBookingStatus.loadingTrips,
      searchParams: params,
      error: null,
      trips: [],
      stagedTrips: [],
      tripsPage: 1,
      tripsHasMore: false,
      searchPhase: BusSearchPhase.polling,
      searchGeneration: generation,
    );
    try {
      final page = await _repo.searchTrips(params);
      if (generation != state.searchGeneration) return;
      state = state.copyWith(
        status: BusBookingStatus.idle,
        trips: page.trips,
        tripsPage: page.currentPage,
        tripsHasMore: page.hasMore,
      );
      _scheduleRound(
        generation: generation,
        round: 1,
        quiet: 0,
        failures: 0,
      );
    } catch (e) {
      if (generation != state.searchGeneration) return;
      state = state.copyWith(
        status: BusBookingStatus.error,
        error: e.toString(),
        searchPhase: BusSearchPhase.idle,
      );
    }
  }

  void _scheduleRound({
    required int generation,
    required int round,
    required int quiet,
    required int failures,
  }) {
    _pollTimer?.cancel();
    if (round > _schedule.rounds) {
      _finishPolling(generation, BusSearchPhase.exhausted);
      return;
    }
    _pollTimer = Timer(_schedule.gap, () {
      unawaited(
        _runRound(
          generation: generation,
          round: round,
          quiet: quiet,
          failures: failures,
        ),
      );
    });
  }

  Future<void> _runRound({
    required int generation,
    required int round,
    required int quiet,
    required int failures,
  }) async {
    if (generation != state.searchGeneration) return;
    final params = state.searchParams;
    if (params == null) return;

    final BusTripsPage page;
    try {
      page = await _repo.searchTrips(params);
    } catch (_) {
      // A failed round is not evidence the aggregation finished, so it never
      // counts toward the quiet rule — and it never surfaces a message to a
      // rider who already has results on screen.
      if (generation != state.searchGeneration) return;
      final nextFailures = failures + 1;
      if (nextFailures >= _maxConsecutiveFailures) {
        _finishPolling(generation, BusSearchPhase.exhausted);
        return;
      }
      _scheduleRound(
        generation: generation,
        round: round + 1,
        quiet: quiet,
        failures: nextFailures,
      );
      return;
    }

    if (generation != state.searchGeneration) return;

    final visibleIds = {for (final trip in state.trips) trip.id};
    final updates = page.trips.where((t) => visibleIds.contains(t.id));
    final arrivals = page.trips.where((t) => !visibleIds.contains(t.id));

    // With nothing on screen there is no reading position to protect, so
    // arrivals skip the staging list entirely.
    final stageArrivals = state.trips.isNotEmpty;

    final visible = mergeBusTrips(
      state.trips,
      [...updates, if (!stageArrivals) ...arrivals],
    );
    final staged = mergeBusTrips(
      state.stagedTrips,
      [if (stageArrivals) ...arrivals],
    );

    state = state.copyWith(trips: visible.trips, stagedTrips: staged.trips);

    final nextQuiet = (visible.changed || staged.changed) ? 0 : quiet + 1;
    if (nextQuiet >= _quietRoundsToComplete) {
      _finishPolling(generation, BusSearchPhase.complete);
      return;
    }
    _scheduleRound(
      generation: generation,
      round: round + 1,
      quiet: nextQuiet,
      failures: 0,
    );
  }

  void _finishPolling(int generation, BusSearchPhase phase) {
    _cancelPolling();
    if (generation != state.searchGeneration) return;
    state = state.copyWith(searchPhase: phase);
  }

  void _cancelPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Promotes trips found after the first round into the visible list. Called
  /// by the results screen when the rider is at the top, or taps the pill.
  void revealStagedTrips() {
    if (state.stagedTrips.isEmpty) return;
    state = state.copyWith(
      trips: [...state.trips, ...state.stagedTrips],
      stagedTrips: const [],
    );
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/bus/bus_booking_notifier_test.dart`
Expected: PASS, including the six new tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bus/presentation/providers/bus_booking_providers.dart test/features/bus/bus_booking_notifier_test.dart
git commit -m "feat(bus): run follow-up search rounds and stage late arrivals"
```

---

### Task 5: The exhausted paths

**Files:**
- Modify: `lib/features/bus/presentation/providers/bus_booking_providers.dart` (no new code — verifying Task 4's branches)
- Test: `test/features/bus/bus_booking_notifier_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to the `progressive search` group:

```dart
    test('a schedule that keeps finding trips ends as exhausted', () async {
      final repo = FakeBusRepository(
        tripsPageQueue: [
          _page([_trip('a')]),
          _page([_trip('a'), _trip('b')]),
          _page([_trip('a'), _trip('b'), _trip('c')]),
          _page([_trip('a'), _trip('b'), _trip('c'), _trip('d')]),
        ],
      );
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      await pumpEventQueue();

      final state = container.read(busBookingProvider);
      expect(state.searchPhase, BusSearchPhase.exhausted);
      // Round 0 plus all three follow-ups; the queue never went quiet.
      expect(repo.searchTripsCallCount, 4);
      expect(state.stagedTrips.map((t) => t.id), ['b', 'c', 'd']);
    });

    test('a failed round does not count toward the quiet rule', () async {
      final repo = FakeBusRepository(tripsPage: _page([_trip('a')]))
        ..failingSearchCalls = {1};
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      await pumpEventQueue();

      final state = container.read(busBookingProvider);
      // Rounds 2 and 3 are the first two quiet ones, so the window runs out
      // rather than settling: the failure in between reset nothing.
      expect(state.searchPhase, BusSearchPhase.complete);
      expect(state.trips.map((t) => t.id), ['a']);
      expect(state.error, isNull);
      expect(state.status, BusBookingStatus.idle);
    });

    test('three consecutive failures end the window as exhausted', () async {
      final repo = FakeBusRepository(tripsPage: _page([_trip('a')]))
        ..failingSearchCalls = {1, 2, 3};
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      await pumpEventQueue();

      final state = container.read(busBookingProvider);
      expect(state.searchPhase, BusSearchPhase.exhausted);
      expect(state.trips.map((t) => t.id), ['a']);
      expect(state.error, isNull);
    });

    test('a failing round 0 keeps the existing error behaviour', () async {
      final repo = FakeBusRepository()..failingSearchCalls = {0};
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      await pumpEventQueue();

      final state = container.read(busBookingProvider);
      expect(state.status, BusBookingStatus.error);
      expect(state.searchPhase, BusSearchPhase.idle);
      expect(state.error, isNotNull);
      // No follow-up rounds were scheduled off a failed first call.
      expect(repo.searchTripsCallCount, 1);
    });
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/features/bus/bus_booking_notifier_test.dart`
Expected: PASS — Task 4 already implements these branches. If any fail, the bug is in Task 4's `_runRound` and belongs there, not in new code here.

- [ ] **Step 3: Commit**

```bash
git add test/features/bus/bus_booking_notifier_test.dart
git commit -m "test(bus): cover exhausted and failure paths of progressive search"
```

---

### Task 6: Cancellation rules

**Files:**
- Modify: `lib/features/bus/presentation/providers/bus_booking_providers.dart` — `loadMoreTrips` and `selectTrip`
- Test: `test/features/bus/bus_booking_notifier_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to the `progressive search` group:

```dart
    test('a new search resets the list and bumps the generation', () async {
      final repo = FakeBusRepository(
        tripsPageQueue: [
          _page([_trip('old')]),
          _page([_trip('new')]),
        ],
      );
      // A long gap guarantees the first search's follow-up round is still
      // pending when the second search cancels it.
      final container = makeContainer(repo, gap: const Duration(seconds: 30));
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      final firstGeneration =
          container.read(busBookingProvider).searchGeneration;
      await _search(notifier);

      final state = container.read(busBookingProvider);
      expect(state.searchGeneration, greaterThan(firstGeneration));
      expect(state.trips.map((t) => t.id), ['new']);
      expect(state.stagedTrips, isEmpty);
    });

    test('stopProgressiveSearch keeps results and offers a refresh', () async {
      final repo = FakeBusRepository(
        tripsPageQueue: [
          _page([_trip('a')]),
          _page([_trip('a'), _trip('b')]),
        ],
      );
      final container = makeContainer(repo, gap: const Duration(seconds: 30));
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      notifier.stopProgressiveSearch();

      final state = container.read(busBookingProvider);
      expect(state.searchPhase, BusSearchPhase.exhausted);
      expect(state.trips.map((t) => t.id), ['a']);
      // The pending round was cancelled before it could run.
      expect(repo.searchTripsCallCount, 1);
    });

    test('loadMoreTrips is a no-op while rounds are still running', () async {
      final repo = FakeBusRepository(
        tripsPageQueue: [
          BusTripsPage(trips: [_trip('a')], currentPage: 1, lastPage: 3),
        ],
      );
      final container = makeContainer(repo, gap: const Duration(seconds: 30));
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      await notifier.loadMoreTrips();

      final state = container.read(busBookingProvider);
      expect(state.searchPhase, BusSearchPhase.polling);
      // Paging never advanced past the first page.
      expect(state.tripsPage, 1);
      expect(repo.searchTripsCallCount, 1);
    });

    test('checkForMoreTrips reopens the window and merges what it finds',
        () async {
      final repo = FakeBusRepository(
        tripsPageQueue: [
          _page([_trip('a')]),
          _page([_trip('a')]),
          _page([_trip('a')]),
          _page([_trip('a'), _trip('b')]),
        ],
      );
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);

      await _search(notifier);
      await pumpEventQueue();
      expect(container.read(busBookingProvider).searchPhase,
          BusSearchPhase.complete);

      notifier.checkForMoreTrips();
      await pumpEventQueue();

      final state = container.read(busBookingProvider);
      expect(state.stagedTrips.map((t) => t.id), ['b']);
      expect(state.trips.map((t) => t.id), ['a']);
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/bus/bus_booking_notifier_test.dart`
Expected: FAIL — `The method 'stopProgressiveSearch' isn't defined`.

- [ ] **Step 3: Add the two public methods**

In `bus_booking_providers.dart`, directly below `revealStagedTrips`:

```dart
  /// Ends the window early without discarding anything already found.
  ///
  /// Used when the rider leaves the results list or the app goes to the
  /// background: a progress bar that no timer will ever advance is worse than
  /// a refresh button.
  void stopProgressiveSearch() {
    _cancelPolling();
    if (state.searchPhase == BusSearchPhase.polling) {
      state = state.copyWith(searchPhase: BusSearchPhase.exhausted);
    }
  }

  /// Manual re-entry after the automatic window closed. Runs a round straight
  /// away — a tap deserves an immediate answer, not a 5-second wait — and
  /// merges rather than resetting, so the list on screen never blinks.
  void checkForMoreTrips() {
    if (state.searchPhase == BusSearchPhase.polling) return;
    if (state.searchParams == null) return;
    state = state.copyWith(searchPhase: BusSearchPhase.polling);
    unawaited(
      _runRound(
        generation: state.searchGeneration,
        round: 1,
        quiet: 0,
        failures: 0,
      ),
    );
  }
```

- [ ] **Step 4: Guard `loadMoreTrips`**

Add as the third line of `loadMoreTrips`, directly below the existing `if (params == null || !state.tripsHasMore) return;`:

```dart
    // `page` is not a stable coordinate while the aggregator is still filling
    // in: page 2 fetched now may repeat or skip rows relative to page 1.
    if (state.searchPhase == BusSearchPhase.polling) return;
```

- [ ] **Step 5: Cancel the window when the rider opens a trip**

Add as the first line of the `selectTrip` body, above the existing `// Seed the pair synchronously` comment:

```dart
    stopProgressiveSearch();
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/bus/`
Expected: PASS, whole bus suite.

- [ ] **Step 7: Commit**

```bash
git add lib/features/bus/presentation/providers/bus_booking_providers.dart test/features/bus/bus_booking_notifier_test.dart
git commit -m "feat(bus): cancel progressive search on navigation, new search, and paging"
```

---

### Task 7: Strings

**Files:**
- Modify: `lib/l10n/app_en.arb:673` (after `tripResultsRetry`)
- Modify: `lib/l10n/app_ar.arb:241` (after `tripResultsRetry`)

- [ ] **Step 1: Add the English strings**

In `lib/l10n/app_en.arb`, directly after the `"tripResultsRetry": "Try again",` line:

```json
  "tripResultsSearchingMore": "Looking for more trips…",
  "@tripResultsSearchingMore": {
    "description": "Shown while extra search rounds run against slow bus operators."
  },
  "tripResultsNewTrips": "{count, plural, =1{1 new trip} other{{count} new trips}}",
  "@tripResultsNewTrips": {
    "description": "Pill revealing trips that arrived after the rider scrolled away from the top.",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "tripResultsSlowOperators": "Some operators are still responding slowly",
  "@tripResultsSlowOperators": {
    "description": "Shown when the progressive search window closed while results were still arriving."
  },
  "tripResultsCheckForMore": "Check for more",
  "@tripResultsCheckForMore": {
    "description": "Button that runs another search round after the automatic window closed."
  },
```

- [ ] **Step 2: Add the Arabic strings**

In `lib/l10n/app_ar.arb`, directly after the `"tripResultsRetry": "حاول مجدداً",` line. This file carries no `@` metadata blocks — match that:

```json
  "tripResultsSearchingMore": "جارٍ البحث عن رحلات إضافية…",
  "tripResultsNewTrips": "{count, plural, =1{رحلة جديدة} other{{count} رحلات جديدة}}",
  "tripResultsSlowOperators": "بعض الشركات لم ترد بعد",
  "tripResultsCheckForMore": "ابحث عن المزيد",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: no output, exit 0. If it warns about untranslated messages, the Arabic keys were misspelled — fix and re-run.

- [ ] **Step 4: Verify the getters exist**

Run: `flutter analyze lib/l10n`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "i18n(bus): add progressive search strings"
```

---

### Task 8: Status strip widget

**Files:**
- Create: `lib/features/bus/presentation/widgets/trip_search_status_strip.dart`
- Test: `test/features/bus/presentation/widgets/trip_search_status_strip_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/bus/presentation/widgets/trip_search_status_strip_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:safaria/features/bus/presentation/widgets/trip_search_status_strip.dart';
import 'package:safaria/l10n/app_localizations.dart';

Future<void> _pumpStrip(
  WidgetTester tester,
  BusSearchPhase phase, {
  VoidCallback? onCheckForMore,
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: TripSearchStatusStrip(
          phase: phase,
          onCheckForMore: onCheckForMore ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('polling shows progress and the searching label', (tester) async {
    await _pumpStrip(tester, BusSearchPhase.polling);

    expect(find.text('Looking for more trips…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('complete collapses to nothing', (tester) async {
    await _pumpStrip(tester, BusSearchPhase.complete);

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('idle collapses to nothing', (tester) async {
    await _pumpStrip(tester, BusSearchPhase.idle);

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('exhausted offers a refresh that fires the callback',
      (tester) async {
    var taps = 0;
    await _pumpStrip(
      tester,
      BusSearchPhase.exhausted,
      onCheckForMore: () => taps++,
    );

    expect(find.text('Some operators are still responding slowly'),
        findsOneWidget);
    await tester.tap(find.text('Check for more'));
    await tester.pump();

    expect(taps, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/bus/presentation/widgets/trip_search_status_strip_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../trip_search_status_strip.dart'`.

- [ ] **Step 3: Write the widget**

Create `lib/features/bus/presentation/widgets/trip_search_status_strip.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Tells the rider whether the results list is still filling in.
///
/// `complete` renders nothing on purpose: a settled search needs no chrome,
/// and a permanent "search finished" banner is noise on every result set.
class TripSearchStatusStrip extends StatelessWidget {
  const TripSearchStatusStrip({
    super.key,
    required this.phase,
    required this.onCheckForMore,
  });

  final BusSearchPhase phase;
  final VoidCallback onCheckForMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (phase) {
      case BusSearchPhase.idle:
      case BusSearchPhase.complete:
        return const SizedBox.shrink();
      case BusSearchPhase.polling:
        return _Frame(
          child: Row(
            children: [
              const SizedBox(
                width: 56,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: AppColors.hairline,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.tripResultsSearchingMore,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        );
      case BusSearchPhase.exhausted:
        return _Frame(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.tripResultsSlowOperators,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: onCheckForMore,
                child: Text(l10n.tripResultsCheckForMore),
              ),
            ],
          ),
        );
    }
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.bgElevated,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: child,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/bus/presentation/widgets/trip_search_status_strip_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bus/presentation/widgets/trip_search_status_strip.dart test/features/bus/presentation/widgets/trip_search_status_strip_test.dart
git commit -m "feat(bus): add progressive search status strip"
```

---

### Task 9: New-trips pill widget

**Files:**
- Create: `lib/features/bus/presentation/widgets/new_trips_pill.dart`
- Test: `test/features/bus/presentation/widgets/new_trips_pill_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/bus/presentation/widgets/new_trips_pill_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/bus/presentation/widgets/new_trips_pill.dart';
import 'package:safaria/l10n/app_localizations.dart';

Future<void> _pumpPill(
  WidgetTester tester,
  int count, {
  VoidCallback? onTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: NewTripsPill(count: count, onTap: onTap ?? () {}),
      ),
    ),
  );
}

void main() {
  testWidgets('pluralises the count', (tester) async {
    await _pumpPill(tester, 1);
    expect(find.text('1 new trip'), findsOneWidget);

    await _pumpPill(tester, 3);
    expect(find.text('3 new trips'), findsOneWidget);
  });

  testWidgets('a zero count renders nothing', (tester) async {
    await _pumpPill(tester, 0);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('tapping fires the callback', (tester) async {
    var taps = 0;
    await _pumpPill(tester, 2, onTap: () => taps++);

    await tester.tap(find.text('2 new trips'));
    await tester.pump();

    expect(taps, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/bus/presentation/widgets/new_trips_pill_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../new_trips_pill.dart'`.

- [ ] **Step 3: Write the widget**

Create `lib/features/bus/presentation/widgets/new_trips_pill.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Offers trips that arrived while the rider was reading further down the
/// list. Inserting them silently would move the card under their finger, so
/// the reveal is theirs to trigger.
class NewTripsPill extends StatelessWidget {
  const NewTripsPill({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.input),
      elevation: 3,
      shadowColor: AppColors.cardShadowSoft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            l10n.tripResultsNewTrips(count),
            style: AppTypography.caption.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
```

`AppRadius` lives in `app_spacing.dart` alongside `AppSpacing` — the same import covers both.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/bus/presentation/widgets/new_trips_pill_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bus/presentation/widgets/new_trips_pill.dart test/features/bus/presentation/widgets/new_trips_pill_test.dart
git commit -m "feat(bus): add new-trips reveal pill"
```

---

### Task 10: Wire the results screen

**Files:**
- Modify: `lib/features/bus/presentation/trip_results_screen.dart:35-134`
- Test: `test/features/bus/presentation/trip_results_screen_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to `test/features/bus/presentation/trip_results_screen_test.dart`. First extend the existing `_pumpResultsWithTrips` helper so it can drive rounds — add this second helper below it:

```dart
/// Pumps the results screen with a queue of successive search rounds and a
/// zero-length gap, so the progressive window runs inside the test.
Future<ProviderContainer> _pumpResultsWithRounds(
  WidgetTester tester,
  List<List<BusTripSummary>> rounds,
) async {
  final repo = FakeBusRepository(
    tripsPageQueue: [
      for (final trips in rounds)
        BusTripsPage(trips: trips, currentPage: 1, lastPage: 1),
    ],
  );

  final router = GoRouter(
    initialLocation: BusRoutes.results,
    routes: [
      GoRoute(
        path: BusRoutes.results,
        builder: (context, state) => const TripResultsScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        busRepositoryProvider.overrideWithValue(repo),
        busSearchScheduleProvider.overrideWithValue(
          const BusSearchSchedule(gap: Duration.zero),
        ),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        routerConfig: router,
      ),
    ),
  );

  final container = ProviderScope.containerOf(
    tester.element(find.byType(TripResultsScreen)),
  );
  await container.read(busBookingProvider.notifier).searchTrips(
        BusSearchParams(
          cityFromId: 1,
          cityToId: 2,
          date: DateTime(2026, 7, 10),
        ),
      );
  await tester.pumpAndSettle();
  return container;
}
```

Add these imports at the top of the file if not already present:

```dart
import 'package:safaria/features/bus/presentation/widgets/new_trips_pill.dart';
import 'package:safaria/features/bus/presentation/widgets/trip_search_status_strip.dart';
```

Then add the tests:

```dart
  testWidgets('the strip reports the search is still running', (tester) async {
    await _pumpResultsWithRounds(tester, [
      [FakeBusRepository.sampleTrip],
    ]);

    expect(find.byType(TripSearchStatusStrip), findsOneWidget);
    expect(find.text('Looking for more trips…'), findsOneWidget);
  });

  testWidgets('an empty list while polling shows the skeleton, not "no trips"',
      (tester) async {
    await _pumpResultsWithRounds(tester, [[]]);

    expect(find.text('No trips found'), findsNothing);
  });

  testWidgets('staged trips reveal themselves while the rider is at the top',
      (tester) async {
    final tripA = FakeBusRepository.sampleTrip;
    final tripB = tripA.copyWith(
      id: 'trip-b',
      operatorName: 'Blue Bus',
      dateTime: tripA.dateTime.add(const Duration(minutes: 30)),
    );

    final container = await _pumpResultsWithRounds(tester, [
      [tripA],
      [tripA, tripB],
    ]);
    await tester.pumpAndSettle();

    // The rider never scrolled, so nothing they are reading can move.
    expect(container.read(busBookingProvider).stagedTrips, isEmpty);
    expect(find.byType(TripCard), findsNWidgets(2));
    expect(find.byType(NewTripsPill), findsNothing);
  });

  testWidgets('a scrolled rider gets the pill instead of a moving list',
      (tester) async {
    final base = FakeBusRepository.sampleTrip;
    final many = [
      for (var i = 0; i < 12; i++)
        base.copyWith(
          id: 'trip-$i',
          dateTime: base.dateTime.add(Duration(minutes: 30 * i)),
        ),
    ];
    // Not named `late` — that is a Dart keyword and will not compile.
    final lateArrival = base.copyWith(
      id: 'trip-late',
      operatorName: 'Blue Bus',
      dateTime: base.dateTime.add(const Duration(hours: 9)),
    );

    // Rounds 1 and 2 repeat round 0, so the window settles; the extra trip
    // only appears on the round that the manual button fires.
    final container = await _pumpResultsWithRounds(tester, [
      many,
      many,
      many,
      [...many, lateArrival],
    ]);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(TripCard).first, const Offset(0, -400));
    await tester.pumpAndSettle();

    container.read(busBookingProvider.notifier).checkForMoreTrips();
    await tester.pumpAndSettle();

    expect(container.read(busBookingProvider).stagedTrips, hasLength(1));
    expect(find.byType(NewTripsPill), findsOneWidget);
    expect(find.text('1 new trip'), findsOneWidget);

    await tester.tap(find.byType(NewTripsPill));
    await tester.pumpAndSettle();

    expect(container.read(busBookingProvider).stagedTrips, isEmpty);
    expect(find.byType(NewTripsPill), findsNothing);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/bus/presentation/trip_results_screen_test.dart`
Expected: FAIL — `TripSearchStatusStrip` is not in the tree, and the empty-list case still finds "No trips found".

- [ ] **Step 3: Add the controller, listeners, and lifecycle hook**

In `trip_results_screen.dart`, replace the `_TripResultsScreenState` field block and add lifecycle members, so the top of the class reads:

```dart
class _TripResultsScreenState extends ConsumerState<TripResultsScreen> {
  /// Below this scroll offset the rider is effectively still at the top, so
  /// new results can be inserted without moving anything they are reading.
  static const _autoRevealOffset = 24.0;

  String? _loadingTripId;
  BusTripFilters _filters = const BusTripFilters();
  final ScrollController _scrollController = ScrollController();
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeRevealStaged);
    _lifecycleListener = AppLifecycleListener(
      onPause: () =>
          ref.read(busBookingProvider.notifier).stopProgressiveSearch(),
    );
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeRevealStaged() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.offset > _autoRevealOffset) return;
    ref.read(busBookingProvider.notifier).revealStagedTrips();
  }
```

- [ ] **Step 4: Reveal staged trips that arrive while the rider is already at the top**

The scroll listener only fires on scroll, so a rider who never scrolls needs the same check when new trips land. Add this as the first statement inside `build`, above `final l10n = ...`:

```dart
    ref.listen(
      busBookingProvider.select((s) => s.stagedTrips.length),
      (_, count) {
        if (count == 0) return;
        if (_scrollController.hasClients &&
            _scrollController.offset > _autoRevealOffset) {
          return;
        }
        ref.read(busBookingProvider.notifier).revealStagedTrips();
      },
    );
```

- [ ] **Step 5: Guard the empty state and mount the strip, pill, and controller**

In `_buildBody`, replace the existing empty-list branch:

```dart
    if (state.trips.isEmpty) {
      return Center(
        child: Text(
          l10n.tripResultsNoTrips,
          style: AppTypography.body.copyWith(color: AppColors.textMuted),
        ),
      );
    }
```

with:

```dart
    if (state.trips.isEmpty) {
      // "No trips" is not yet a true statement while operators are still
      // answering — keep the skeleton up until the window closes.
      if (state.searchPhase == BusSearchPhase.polling) {
        return const _LoadingSkeleton();
      }
      return Center(
        child: Text(
          l10n.tripResultsNoTrips,
          style: AppTypography.body.copyWith(color: AppColors.textMuted),
        ),
      );
    }
```

Then replace the `return Column(...)` at the end of `_buildBody` with:

```dart
    return Column(
      children: [
        TripSearchStatusStrip(
          phase: state.searchPhase,
          onCheckForMore: () =>
              ref.read(busBookingProvider.notifier).checkForMoreTrips(),
        ),
        if (_filters.isActive)
          ActiveFilterChips(
            filters: _filters,
            onRemove: (chip) =>
                setState(() => _filters = _filters.removeChip(chip)),
          ),
        Expanded(
          child: Stack(
            children: [
              ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
                itemCount: trips.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) => TripCard(
                  key: ValueKey(trips[i].id),
                  trip: trips[i],
                  highlight: highlights[trips[i].id],
                  loading: _loadingTripId == trips[i].id,
                  onSelect: ({required from, required to}) =>
                      _selectTrip(trips[i], from: from, to: to),
                ),
              ),
              Positioned(
                top: AppSpacing.sm,
                left: 0,
                right: 0,
                child: Center(
                  child: NewTripsPill(
                    count: state.stagedTrips.length,
                    onTap: () {
                      ref.read(busBookingProvider.notifier).revealStagedTrips();
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/bus/presentation/trip_results_screen_test.dart`
Expected: PASS, including the three new tests and every pre-existing one.

- [ ] **Step 7: Commit**

```bash
git add lib/features/bus/presentation/trip_results_screen.dart test/features/bus/presentation/trip_results_screen_test.dart
git commit -m "feat(bus): show progressive search progress and staged results"
```

---

### Task 11: Full verification

**Files:** none — this task only runs commands.

- [ ] **Step 1: Analyze the whole project**

Run: `flutter analyze`
Expected: `No issues found!`

Common failure here: an unused `AppRadius` or `dart:async` import left behind if a step was reordered. Remove it rather than suppressing the lint.

- [ ] **Step 2: Run the whole test suite**

Run: `flutter test`
Expected: `All tests passed!`

If any test outside `test/features/bus/` fails, the cause is almost certainly a pending `Timer` at teardown — check that `ref.onDispose(_cancelPolling)` from Task 4 Step 3 is present in `build()`.

- [ ] **Step 3: Confirm the behaviour in the real app**

Run: `flutter run`

Search a busy route (Cairo → Alexandria) against the demo backend and confirm: results appear immediately, the strip shows the searching label, the list grows within ~15 seconds, and the strip either disappears or offers **Check for more** when it stops.

This is the step that produces the numbers to re-tune `BusSearchSchedule` with. Record how many trips arrive per round.

- [ ] **Step 4: Commit any tuning**

```bash
git add -A
git commit -m "chore(bus): tune progressive search schedule from measurement"
```

Skip this commit if the defaults held up.

---

## Notes for the implementer

**Do not widen the scope to pagination.** `loadMoreTrips` stays unwired to the UI — Task 6 only stops it running at a moment when it would corrupt the list. Infinite scroll is a separate piece of work, recorded in the spec's Deferred section.

**Do not touch `BusBookingStatus`.** Every existing consumer of it — the error view, the skeleton, the filter sheet, the seat and payment flows — must keep behaving exactly as it does today. Everything about the progressive window is read from `searchPhase`.

**The failure branch in `_runRound` looks redundant** at three rounds and a three-failure threshold, because both paths land on `exhausted`. It is not dead: it is what keeps the behaviour correct if `BusSearchSchedule.rounds` is tuned upward, which Task 11 Step 3 may well do.
