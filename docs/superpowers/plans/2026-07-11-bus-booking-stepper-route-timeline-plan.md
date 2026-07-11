# Bus booking stepper + route timeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the post-search bus booking flow into a 3-step wizard (Route → Seat → Confirm) with a shared progress bar, replace the two boarding/drop-off picker lists with one full-route timeline, and enrich the final confirm screen to recap every choice the rider made.

**Architecture:** Two new presentation-only widgets (`BookingStepBar`, `RouteTimeline`) slot into the three existing booking screens (`BusTripDetailsScreen`, `SeatSelectionScreen`, `PassengerConfirmScreen`), which keep their current routes, `push`/`pop` navigation, and shared `busBookingProvider`. No API, entity, or state-shape changes.

**Tech Stack:** Flutter, Riverpod (`Notifier`/`ProviderContainer` in tests), go_router, Freezed entities, `flutter gen-l10n` (arb → generated `AppLocalizations`).

Spec: [`docs/superpowers/specs/2026-07-11-bus-booking-stepper-route-timeline-design.md`](../specs/2026-07-11-bus-booking-stepper-route-timeline-design.md)

---

## Task 1: Localization keys

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ar.arb`

- [ ] **Step 1: Add the stepper + route + confirm keys to the English arb**

In `lib/l10n/app_en.arb`, find this block:

```json
  "tripResultsFareLabel": "Fare",
  "tripDetailTitle": "Trip details",
```

Replace with:

```json
  "tripResultsFareLabel": "Fare",
  "bookingStepRoute": "Route",
  "bookingStepSeat": "Seat",
  "bookingStepConfirm": "Confirm",
  "tripDetailTitle": "Trip details",
```

Then find:

```json
  "tripDetailFareLiveHint": "Updates with the stops you pick",
  "tripDetailBoardAt": "Board at",
  "tripDetailDropOffAt": "Drop off at",
  "amenityWifi": "Wi-Fi",
```

Replace with (this removes the now-unused picker-list titles and adds the route-timeline keys):

```json
  "tripDetailFareLiveHint": "Updates with the stops you pick",
  "tripDetailRouteSection": "Trip route",
  "tripDetailBoardHere": "Board here",
  "tripDetailDropOffHere": "Drop off",
  "amenityWifi": "Wi-Fi",
```

Then find:

```json
  "confirmTitle": "Confirm booking",
  "confirmBook": "Confirm & pay",
  "confirmPassengerSection": "Passenger",
```

Replace with:

```json
  "confirmTitle": "Confirm booking",
  "confirmBook": "Confirm & pay",
  "confirmRouteSection": "Your journey",
  "confirmDateLabel": "Date",
  "confirmPassengerSection": "Passenger",
```

- [ ] **Step 2: Mirror the same keys in the Arabic arb**

In `lib/l10n/app_ar.arb`, find:

```json
  "tripResultsFareLabel": "السعر",
  "tripDetailTitle": "تفاصيل الرحلة",
```

Replace with:

```json
  "tripResultsFareLabel": "السعر",
  "bookingStepRoute": "المسار",
  "bookingStepSeat": "المقعد",
  "bookingStepConfirm": "التأكيد",
  "tripDetailTitle": "تفاصيل الرحلة",
```

Then find:

```json
  "tripDetailFareLiveHint": "يتغيّر السعر حسب المحطات التي تختارها",
  "tripDetailBoardAt": "الركوب من",
  "tripDetailDropOffAt": "النزول في",
  "amenityWifi": "واي فاي",
```

Replace with:

```json
  "tripDetailFareLiveHint": "يتغيّر السعر حسب المحطات التي تختارها",
  "tripDetailRouteSection": "مسار الرحلة",
  "tripDetailBoardHere": "تصعد هنا",
  "tripDetailDropOffHere": "تنزل هنا",
  "amenityWifi": "واي فاي",
```

Then find:

```json
  "confirmTitle": "تأكيد الحجز",
  "confirmBook": "تأكيد والدفع",
  "confirmPassengerSection": "المسافر",
```

Replace with:

```json
  "confirmTitle": "تأكيد الحجز",
  "confirmBook": "تأكيد والدفع",
  "confirmRouteSection": "رحلتك",
  "confirmDateLabel": "التاريخ",
  "confirmPassengerSection": "المسافر",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: completes with no errors; `lib/l10n/app_localizations*.dart` regenerate (gitignored, not committed) with the new getters (`bookingStepRoute`, `bookingStepSeat`, `bookingStepConfirm`, `tripDetailRouteSection`, `tripDetailBoardHere`, `tripDetailDropOffHere`, `confirmRouteSection`, `confirmDateLabel`) and without `tripDetailBoardAt`/`tripDetailDropOffAt`.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "feat(bus): add stepper and route-timeline localization keys"
```

---

## Task 2: `BusBookingStep` enum + `BookingStepBar` widget

**Files:**
- Create: `lib/features/bus/presentation/widgets/booking_step_bar.dart`
- Test: `test/features/bus/presentation/booking_step_bar_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/bus/presentation/booking_step_bar_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/features/bus/presentation/widgets/booking_step_bar.dart';
import 'package:rego/l10n/app_localizations.dart';

Future<GoRouter> _pumpTwoScreenRouter(
  WidgetTester tester,
  BusBookingStep secondScreenStep,
) async {
  final router = GoRouter(
    initialLocation: '/first',
    routes: [
      GoRoute(
        path: '/first',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('first screen'))),
      ),
      GoRoute(
        path: '/second',
        builder: (context, state) => Scaffold(
          body: BookingStepBar(current: secondScreenStep),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
  return router;
}

void main() {
  testWidgets('renders all three step labels', (tester) async {
    final router = await _pumpTwoScreenRouter(tester, BusBookingStep.seat);
    unawaited(router.push('/second'));
    await tester.pumpAndSettle();

    expect(find.text('Route'), findsOneWidget);
    expect(find.text('Seat'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
  });

  testWidgets('tapping a completed step pops back to it', (tester) async {
    final router = await _pumpTwoScreenRouter(tester, BusBookingStep.seat);
    unawaited(router.push('/second'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Route'));
    await tester.pumpAndSettle();

    expect(find.text('first screen'), findsOneWidget);
  });

  testWidgets('upcoming step is not tappable', (tester) async {
    final router = await _pumpTwoScreenRouter(tester, BusBookingStep.route);
    unawaited(router.push('/second'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // Still on the second screen — nothing to pop back to for an upcoming step.
    expect(find.text('first screen'), findsNothing);
    expect(find.text('Confirm'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/bus/presentation/booking_step_bar_test.dart`
Expected: FAIL — `package:rego/features/bus/presentation/widgets/booking_step_bar.dart` doesn't exist (`BusBookingStep`/`BookingStepBar` undefined).

- [ ] **Step 3: Implement `BookingStepBar`**

Create `lib/features/bus/presentation/widgets/booking_step_bar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/l10n/app_localizations.dart';

/// Ordered steps of the bus booking wizard, in flow order.
enum BusBookingStep { route, seat, confirm }

/// Shared progress header shown at the top of each booking screen: Route →
/// Seat → Confirm. Completed steps are tappable and pop the navigation stack
/// back to that screen; the current step is emphasized; upcoming steps are
/// muted and inert — forward movement is gated by each screen's own
/// call-to-action, never by this bar.
class BookingStepBar extends StatelessWidget {
  const BookingStepBar({super.key, required this.current});

  final BusBookingStep current;

  static const _steps = BusBookingStep.values;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 20),
                  color: i <= current.index
                      ? AppColors.primary
                      : AppColors.hairline,
                ),
              ),
            _StepNode(
              label: _labelFor(l10n, _steps[i]),
              icon: _iconFor(_steps[i]),
              isCompleted: i < current.index,
              isCurrent: i == current.index,
              onTap: i < current.index
                  ? () => _goToStep(context, _steps[i])
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  String _labelFor(AppLocalizations l10n, BusBookingStep step) {
    return switch (step) {
      BusBookingStep.route => l10n.bookingStepRoute,
      BusBookingStep.seat => l10n.bookingStepSeat,
      BusBookingStep.confirm => l10n.bookingStepConfirm,
    };
  }

  IconData _iconFor(BusBookingStep step) {
    return switch (step) {
      BusBookingStep.route => AppIcons.locationTo,
      BusBookingStep.seat => AppIcons.ticket,
      BusBookingStep.confirm => AppIcons.checkCircle,
    };
  }

  void _goToStep(BuildContext context, BusBookingStep target) {
    final hops = current.index - target.index;
    for (var i = 0; i < hops; i++) {
      if (!context.canPop()) return;
      context.pop();
    }
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.label,
    required this.icon,
    required this.isCompleted,
    required this.isCurrent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isCompleted;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final filled = isCompleted || isCurrent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? AppColors.primary : AppColors.bgElevated,
                border: filled
                    ? null
                    : Border.all(color: AppColors.hairline, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Icon(
                isCompleted ? AppIcons.check : icon,
                size: 15,
                color: filled ? AppColors.onPrimary : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: filled ? AppColors.primary : AppColors.textMuted,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/bus/presentation/booking_step_bar_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/bus/presentation/widgets/booking_step_bar.dart test/features/bus/presentation/booking_step_bar_test.dart
git commit -m "feat(bus): add BusBookingStep enum and BookingStepBar widget"
```

---

## Task 3: `RouteTimeline` widget

**Files:**
- Create: `lib/features/bus/presentation/widgets/route_timeline.dart`
- Test: `test/features/bus/presentation/route_timeline_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/bus/presentation/route_timeline_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/presentation/widgets/route_timeline.dart';
import 'package:rego/l10n/app_localizations.dart';

const _board1 = BusStop(
  locationId: 'b1',
  name: 'October',
  cityId: 1,
  cityName: '6th of October',
);
final _board2 = BusStop(
  locationId: 'b2',
  name: 'Zayed',
  cityId: 1,
  cityName: '6th of October',
  arrivalAt: DateTime(2026, 2, 10, 7, 25),
);
final _drop1 = BusStop(
  locationId: 'd1',
  name: 'Ras Shitan',
  cityId: 2,
  cityName: 'Nuweiba',
  arrivalAt: DateTime(2026, 2, 10, 14, 10),
  finalPrice: 200,
);
final _drop2 = BusStop(
  locationId: 'd2',
  name: 'Dahab',
  cityId: 2,
  cityName: 'South Sinai',
  arrivalAt: DateTime(2026, 2, 10, 15, 5),
  finalPrice: 220,
);

Future<void> _pump(
  WidgetTester tester, {
  required BusStop from,
  required BusStop to,
  required ValueChanged<BusStop> onBoard,
  required ValueChanged<BusStop> onDrop,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RouteTimeline(
          boardingStops: [_board1, _board2],
          dropoffStops: [_drop1, _drop2],
          selectedFrom: from,
          selectedTo: to,
          onBoardSelected: onBoard,
          onDropoffSelected: onDrop,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders every stop in order with the selected pair marked',
      (tester) async {
    await _pump(
      tester,
      from: _board1,
      to: _drop1,
      onBoard: (_) {},
      onDrop: (_) {},
    );

    expect(find.text('October'), findsOneWidget);
    expect(find.text('Zayed'), findsOneWidget);
    expect(find.text('Ras Shitan'), findsOneWidget);
    expect(find.text('Dahab'), findsOneWidget);
    expect(find.text('Board here'), findsOneWidget);
    expect(find.text('Drop off'), findsOneWidget);
  });

  testWidgets('tapping a boarding stop fires onBoardSelected', (tester) async {
    BusStop? tapped;
    await _pump(
      tester,
      from: _board1,
      to: _drop1,
      onBoard: (s) => tapped = s,
      onDrop: (_) {},
    );

    await tester.tap(find.text('Zayed'));
    await tester.pumpAndSettle();

    expect(tapped?.locationId, 'b2');
  });

  testWidgets('tapping a drop-off stop fires onDropoffSelected',
      (tester) async {
    BusStop? tapped;
    await _pump(
      tester,
      from: _board1,
      to: _drop1,
      onBoard: (_) {},
      onDrop: (s) => tapped = s,
    );

    await tester.tap(find.text('Dahab'));
    await tester.pumpAndSettle();

    expect(tapped?.locationId, 'd2');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/bus/presentation/route_timeline_test.dart`
Expected: FAIL — `package:rego/features/bus/presentation/widgets/route_timeline.dart` doesn't exist (`RouteTimeline` undefined).

- [ ] **Step 3: Implement `RouteTimeline`**

Create `lib/features/bus/presentation/widgets/route_timeline.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/l10n/app_localizations.dart';

/// Full ordered route for a trip, rendered as one vertical timeline: the
/// origin city's boarding stops (blue, tap to board) followed by the
/// destination city's drop-off stops (amber, tap to get off), each sorted by
/// arrival time. The segment between the chosen board and drop-off stop is
/// emphasized; stops outside it dim but stay tappable to re-pick.
class RouteTimeline extends StatelessWidget {
  const RouteTimeline({
    super.key,
    required this.boardingStops,
    required this.dropoffStops,
    required this.selectedFrom,
    required this.selectedTo,
    required this.onBoardSelected,
    required this.onDropoffSelected,
  });

  final List<BusStop> boardingStops;
  final List<BusStop> dropoffStops;
  final BusStop selectedFrom;
  final BusStop selectedTo;
  final ValueChanged<BusStop> onBoardSelected;
  final ValueChanged<BusStop> onDropoffSelected;

  /// Nulls sort first within their group — a missing `arrivalAt` means "no
  /// estimate yet", which the domain already treats as the earliest/base
  /// reference time (see `BusTripSummary.departTime`'s `?? dateTime`
  /// fallback). Real fixtures commonly have the *default* boarding stop with
  /// a null arrival, so pushing nulls to the end would wrongly bury the
  /// primary origin stop at the bottom of the timeline.
  static int _byArrival(BusStop a, BusStop b) {
    if (a.arrivalAt == null && b.arrivalAt == null) return 0;
    if (a.arrivalAt == null) return -1;
    if (b.arrivalAt == null) return 1;
    return a.arrivalAt!.compareTo(b.arrivalAt!);
  }

  List<_RouteEntry> _buildEntries() {
    final board = [...boardingStops]..sort(_byArrival);
    final drop = [...dropoffStops]..sort(_byArrival);
    return [
      for (final s in board) _RouteEntry(stop: s, isBoardCandidate: true),
      for (final s in drop) _RouteEntry(stop: s, isBoardCandidate: false),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = _buildEntries();
    final boardIndex = entries.indexWhere(
      (e) => e.isBoardCandidate && e.stop.locationId == selectedFrom.locationId,
    );
    final dropIndex = entries.indexWhere(
      (e) => !e.isBoardCandidate && e.stop.locationId == selectedTo.locationId,
    );
    final activeStart = boardIndex == -1 ? 0 : boardIndex;
    final activeEnd = dropIndex == -1 ? entries.length - 1 : dropIndex;

    return Material(
      color: AppColors.bgElevated,
      borderRadius: BorderRadius.circular(AppRadius.card),
      elevation: 3,
      shadowColor: AppColors.primary.withValues(alpha: 0.1),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tripDetailRouteSection,
              style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < entries.length; i++)
              _RouteRow(
                entry: entries[i],
                isSelected: i == boardIndex || i == dropIndex,
                isDimmed: i < activeStart || i > activeEnd,
                isLast: i == entries.length - 1,
                connectorColor: (i >= activeStart && i < activeEnd)
                    ? AppColors.primary
                    : AppColors.hairline,
                l10n: l10n,
                onTap: () => entries[i].isBoardCandidate
                    ? onBoardSelected(entries[i].stop)
                    : onDropoffSelected(entries[i].stop),
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteEntry {
  const _RouteEntry({required this.stop, required this.isBoardCandidate});
  final BusStop stop;
  final bool isBoardCandidate;
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.entry,
    required this.isSelected,
    required this.isDimmed,
    required this.isLast,
    required this.connectorColor,
    required this.l10n,
    required this.onTap,
  });

  final _RouteEntry entry;
  final bool isSelected;
  final bool isDimmed;
  final bool isLast;
  final Color connectorColor;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  Color get _accent =>
      entry.isBoardCandidate ? AppColors.primary : AppColors.secondary;

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = isDimmed ? AppColors.hairline : _accent;
    final nameColor = isDimmed ? AppColors.textMuted : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  width: isSelected ? 14 : 10,
                  height: isSelected ? 14 : 10,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? dotColor : AppColors.bgElevated,
                    border: Border.all(color: dotColor, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: connectorColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.stop.name,
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: nameColor,
                            ),
                          ),
                          if (entry.stop.cityName.isNotEmpty)
                            Text(
                              entry.stop.cityName,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          if (isSelected)
                            Text(
                              entry.isBoardCandidate
                                  ? l10n.tripDetailBoardHere
                                  : l10n.tripDetailDropOffHere,
                              style: AppTypography.caption.copyWith(
                                color: _accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (entry.stop.arrivalAt != null)
                      Text(
                        _formatTime(entry.stop.arrivalAt!),
                        style: AppTypography.caption.copyWith(
                          color: isDimmed
                              ? AppColors.textMuted
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/bus/presentation/route_timeline_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/bus/presentation/widgets/route_timeline.dart test/features/bus/presentation/route_timeline_test.dart
git commit -m "feat(bus): add RouteTimeline widget for full-route stop selection"
```

---

## Task 4: Integrate into `BusTripDetailsScreen`, remove `StopSelector`

**Files:**
- Modify: `lib/features/bus/presentation/trip_details_screen.dart`
- Modify: `test/features/bus/presentation/trip_details_screen_test.dart`
- Delete: `lib/features/bus/presentation/widgets/stop_selector.dart`

- [ ] **Step 1: Update the existing test to expect the route timeline instead of the two picker lists**

Replace the full contents of `test/features/bus/presentation/trip_details_screen_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/trip_details_screen.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../fake_bus_repository.dart';

BusTripSummary _buildTrip() {
  final board = BusStop(
    locationId: 'b1',
    name: 'Ramsis',
    cityId: 1,
    cityName: 'Cairo',
    arrivalAt: DateTime(2026, 2, 10, 8),
  );
  final dropDefault = BusStop(
    locationId: 'd1',
    name: 'Sidi Gaber',
    cityId: 2,
    cityName: 'Alexandria',
    arrivalAt: DateTime(2026, 2, 10, 11, 30),
    finalPrice: 180,
  );
  final dropAlt = BusStop(
    locationId: 'd2',
    name: 'Moharam Bek',
    cityId: 2,
    cityName: 'Alexandria',
    arrivalAt: DateTime(2026, 2, 10, 12),
    finalPrice: 150,
  );
  return BusTripSummary(
    id: 'trip-1',
    gatewayId: 'gw',
    operatorName: 'Go Bus',
    category: 'VIP',
    dateTime: DateTime(2026, 2, 10, 8),
    currency: 'EGP',
    availableSeats: 6,
    priceStartWith: 180,
    defaultBoardingStop: board,
    defaultDropoffStop: dropDefault,
    boardingStops: [board],
    dropoffStops: [dropDefault, dropAlt],
  );
}

Future<ProviderContainer> _pumpDetails(
  WidgetTester tester,
  BusTripSummary trip, {
  Locale locale = const Locale('en'),
}) async {
  final container = ProviderContainer(
    overrides: [
      busRepositoryProvider
          .overrideWithValue(FakeBusRepository(tripByIdResult: trip)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: const BusTripDetailsScreen(),
      ),
    ),
  );
  await container.read(busBookingProvider.notifier).selectTrip(trip);
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets(
    'renders the trip ticket, route timeline and footer fare',
    (tester) async {
      await _pumpDetails(tester, _buildTrip());

      expect(find.textContaining('Go Bus', findRichText: true), findsWidgets);
      expect(find.text('Trip route'), findsOneWidget);
      // Ramsis/Sidi Gaber are the selected pair, so they render both in the
      // ticket card's mini timeline and in the full RouteTimeline below.
      expect(find.text('Ramsis'), findsWidgets);
      expect(find.text('Sidi Gaber'), findsWidgets);
      // Moharam Bek is the unselected alternate drop-off, shown only in the
      // RouteTimeline.
      expect(find.text('Moharam Bek'), findsOneWidget);
      expect(find.text('Choose seats'), findsOneWidget);
      // Default segment fare (Sidi Gaber, 180) shown in ticket + footer.
      expect(find.textContaining('180', findRichText: true), findsWidgets);
    },
  );

  testWidgets(
    'selecting an alternate drop-off stop updates the live fare',
    (tester) async {
      await _pumpDetails(tester, _buildTrip());

      expect(find.textContaining('180', findRichText: true), findsWidgets);

      final altStop = find.text('Moharam Bek');
      await tester.ensureVisible(altStop);
      await tester.pumpAndSettle();
      await tester.tap(altStop);
      await tester.pumpAndSettle();

      expect(find.textContaining('150', findRichText: true), findsWidgets);
      expect(find.textContaining('180', findRichText: true), findsNothing);
    },
  );

  testWidgets('renders in RTL (Arabic)', (tester) async {
    await _pumpDetails(tester, _buildTrip(), locale: const Locale('ar'));

    expect(find.text('مسار الرحلة'), findsOneWidget); // Trip route
    expect(find.text('اختر المقاعد'), findsOneWidget); // Choose seats
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/bus/presentation/trip_details_screen_test.dart`
Expected: FAIL — `find.text('Trip route')` finds nothing (the screen still renders the old `StopSelector` lists).

- [ ] **Step 3: Update imports in `trip_details_screen.dart`**

In `lib/features/bus/presentation/trip_details_screen.dart`, find:

```dart
import 'package:rego/features/bus/presentation/widgets/amenity_chip.dart';
import 'package:rego/features/bus/presentation/widgets/amenity_icon.dart';
import 'package:rego/features/bus/presentation/widgets/amenity_icons_row.dart';
import 'package:rego/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:rego/features/bus/presentation/widgets/operator_avatar.dart';
import 'package:rego/features/bus/presentation/widgets/stop_selector.dart';
import 'package:rego/features/bus/presentation/widgets/ticket_border.dart';
```

Replace with:

```dart
import 'package:rego/features/bus/presentation/widgets/amenity_chip.dart';
import 'package:rego/features/bus/presentation/widgets/amenity_icon.dart';
import 'package:rego/features/bus/presentation/widgets/amenity_icons_row.dart';
import 'package:rego/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:rego/features/bus/presentation/widgets/booking_step_bar.dart';
import 'package:rego/features/bus/presentation/widgets/operator_avatar.dart';
import 'package:rego/features/bus/presentation/widgets/route_timeline.dart';
import 'package:rego/features/bus/presentation/widgets/ticket_border.dart';
```

- [ ] **Step 4: Add the step bar and swap the picker lists for `RouteTimeline`**

In the same file, find:

```dart
      // Section order mirrors the approved bus-flow-redesign spec: trip
      // identity + route + amenities first (so the user confirms this is the
      // trip they picked), then the boarding/drop-off pickers.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TripTicketCard(
              trip: trip,
              fromStop: fromStop,
              toStop: toStop,
              fare: state.segmentFare,
              l10n: l10n,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: Text(
                l10n.tripDetailFareLiveHint,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _AmenitiesSection(amenities: trip.amenities, l10n: l10n),
            const SizedBox(height: AppSpacing.lg),
            StopSelector(
              title: l10n.tripDetailBoardAt,
              stops: trip.boardingStops,
              selected: fromStop,
              onSelected: (stop) => ref
                  .read(busBookingProvider.notifier)
                  .setStops(from: stop, to: toStop),
            ),
            const SizedBox(height: AppSpacing.lg),
            StopSelector(
              title: l10n.tripDetailDropOffAt,
              stops: trip.dropoffStops,
              selected: toStop,
              onSelected: (stop) => ref
                  .read(busBookingProvider.notifier)
                  .setStops(from: fromStop, to: stop),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
```

Replace with:

```dart
      // Section order mirrors the approved bus-flow-redesign spec: trip
      // identity + route + amenities first (so the user confirms this is the
      // trip they picked), then the route timeline for stop selection.
      body: Column(
        children: [
          const BookingStepBar(current: BusBookingStep.route),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TripTicketCard(
                    trip: trip,
                    fromStop: fromStop,
                    toStop: toStop,
                    fare: state.segmentFare,
                    l10n: l10n,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      l10n.tripDetailFareLiveHint,
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _AmenitiesSection(amenities: trip.amenities, l10n: l10n),
                  const SizedBox(height: AppSpacing.lg),
                  RouteTimeline(
                    boardingStops: trip.boardingStops,
                    dropoffStops: trip.dropoffStops,
                    selectedFrom: fromStop,
                    selectedTo: toStop,
                    onBoardSelected: (stop) => ref
                        .read(busBookingProvider.notifier)
                        .setStops(from: stop, to: toStop),
                    onDropoffSelected: (stop) => ref
                        .read(busBookingProvider.notifier)
                        .setStops(from: fromStop, to: stop),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
```

- [ ] **Step 5: Delete the now-unused `StopSelector` widget**

Run: `git rm lib/features/bus/presentation/widgets/stop_selector.dart`
Expected: file removed; no other file in `lib/` or `test/` references `StopSelector` (already verified during design — only `trip_details_screen.dart`, just edited, referenced it).

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/bus/presentation/trip_details_screen_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 7: Run the full analyzer to catch any stale references**

Run: `flutter analyze`
Expected: no errors (in particular, no unresolved `StopSelector` or unused-import warnings).

- [ ] **Step 8: Commit**

```bash
git add lib/features/bus/presentation/trip_details_screen.dart test/features/bus/presentation/trip_details_screen_test.dart lib/features/bus/presentation/widgets/stop_selector.dart
git commit -m "feat(bus): show full-route timeline and step bar on trip details"
```

---

## Task 5: Integrate step bar into `SeatSelectionScreen`

**Files:**
- Modify: `lib/features/bus/presentation/seat_selection_screen.dart`
- Test: `test/features/bus/presentation/seat_selection_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/bus/presentation/seat_selection_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/seat_selection_screen.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../fake_bus_repository.dart';

void main() {
  testWidgets('shows the booking step bar with Seat as the current step',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        busRepositoryProvider.overrideWithValue(FakeBusRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: SeatSelectionScreen(),
        ),
      ),
    );
    await container
        .read(busBookingProvider.notifier)
        .selectTrip(FakeBusRepository.sampleTrip);
    await tester.pumpAndSettle();

    expect(find.text('Route'), findsOneWidget);
    expect(find.text('Seat'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/bus/presentation/seat_selection_screen_test.dart`
Expected: FAIL — `find.text('Route')` and `find.text('Confirm')` find nothing (only the seat legend/grid render today).

- [ ] **Step 3: Add the step bar to `SeatSelectionScreen`**

In `lib/features/bus/presentation/seat_selection_screen.dart`, find:

```dart
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:rego/features/bus/presentation/widgets/seat_grid.dart';
```

Replace with:

```dart
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:rego/features/bus/presentation/widgets/booking_step_bar.dart';
import 'package:rego/features/bus/presentation/widgets/seat_grid.dart';
```

Then find:

```dart
      body: Column(
        children: [
          _LegendRow(l10n: l10n),
```

Replace with:

```dart
      body: Column(
        children: [
          const BookingStepBar(current: BusBookingStep.seat),
          _LegendRow(l10n: l10n),
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/bus/presentation/seat_selection_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/bus/presentation/seat_selection_screen.dart test/features/bus/presentation/seat_selection_screen_test.dart
git commit -m "feat(bus): show booking step bar on seat selection"
```

---

## Task 6: Integrate step bar + full recap into `PassengerConfirmScreen`

**Files:**
- Modify: `lib/features/bus/presentation/passenger_confirm_screen.dart`
- Test: `test/features/bus/presentation/passenger_confirm_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/bus/presentation/passenger_confirm_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/domain/entities/bus_search_params.dart';
import 'package:rego/features/bus/presentation/passenger_confirm_screen.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../fake_bus_repository.dart';

Future<ProviderContainer> _pumpConfirm(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      busRepositoryProvider.overrideWithValue(FakeBusRepository()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: PassengerConfirmScreen(),
      ),
    ),
  );

  final notifier = container.read(busBookingProvider.notifier);
  await notifier.searchTrips(
    BusSearchParams(
      cityFromId: 1,
      cityToId: 2,
      date: DateTime(2026, 2, 10),
    ),
  );
  await notifier.selectTrip(FakeBusRepository.sampleTrip);
  notifier.toggleSeat('16');
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('shows the step bar and the full choice recap', (tester) async {
    await _pumpConfirm(tester);

    expect(find.text('Route'), findsOneWidget);
    expect(find.text('Seat'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);

    // Chosen stops from FakeBusRepository.sampleTrip's default pair.
    expect(find.text('القللي'), findsOneWidget);
    expect(find.text('محرم بك'), findsOneWidget);
    // Selected seat chip.
    expect(find.text('16'), findsOneWidget);
    // Trip date recap.
    expect(find.text('Date'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/bus/presentation/passenger_confirm_screen_test.dart`
Expected: FAIL — no `BookingStepBar` labels render, and the summary card shows only operator/class/times, not the chosen stop names, date, or seat chip.

- [ ] **Step 3: Replace `passenger_confirm_screen.dart` with the enriched version**

Replace the full contents of `lib/features/bus/presentation/passenger_confirm_screen.dart` with:

```dart
// lib/features/bus/presentation/passenger_confirm_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/core/utils/date_formatting.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:rego/features/bus/presentation/widgets/booking_step_bar.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class PassengerConfirmScreen extends ConsumerWidget {
  const PassengerConfirmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Side-effect navigation via ref.listen — never call context.go inside build.
    ref.listen<BusBookingState>(busBookingProvider, (prev, next) {
      if (next.status == BusBookingStatus.confirmed) {
        context.go(BusRoutes.ticket);
      } else if (next.status == BusBookingStatus.error && next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    final state = ref.watch(busBookingProvider);
    final isLoading = state.status == BusBookingStatus.confirming;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(title: l10n.confirmTitle),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: PrimaryButton(
            label: l10n.confirmBook,
            loading: isLoading,
            onPressed: isLoading
                ? null
                : () => ref.read(busBookingProvider.notifier).confirmBooking(),
          ),
        ),
      ),
      body: Column(
        children: [
          const BookingStepBar(current: BusBookingStep.confirm),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BusTripSummaryCard(state: state, l10n: l10n),
                  const SizedBox(height: AppSpacing.md),
                  _PassengerSection(state: state, l10n: l10n),
                  const SizedBox(height: AppSpacing.md),
                  _PaymentSection(state: state, l10n: l10n),
                  const SizedBox(height: AppSpacing.md),
                  _PriceBreakdown(state: state, l10n: l10n),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trip summary card ────────────────────────────────────────────────────────

class _BusTripSummaryCard extends StatelessWidget {
  const _BusTripSummaryCard({required this.state, required this.l10n});
  final BusBookingState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final trip = state.selectedTrip;
    final from = state.fromStop;
    final to = state.toStop;
    final seats = state.selectedSeats;
    final params = state.searchParams;
    final dateLabel = params == null
        ? ''
        : formatSearchDateCell(
            params.date,
            Localizations.localeOf(context).toString(),
          );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Operator code circle
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  trip?.operatorCode ?? 'R',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip?.operatorName ?? 'REGO Buses',
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (trip != null)
                      Text(
                        trip.serviceClass,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (from != null && to != null) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.hairline),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.confirmRouteSection,
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            _ConfirmRouteRow(from: from, to: to),
          ],
          if (dateLabel.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  l10n.confirmDateLabel,
                  style:
                      AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(width: 6),
                Text(
                  dateLabel,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.seatSelectionSeatsLabel,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          seats.isEmpty
              ? Text(
                  l10n.seatSelectionNoSeats,
                  style:
                      AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final seat in seats) _SeatChip(label: seat),
                  ],
                ),
        ],
      ),
    );
  }
}

class _ConfirmRouteRow extends StatelessWidget {
  const _ConfirmRouteRow({required this.from, required this.to});

  final BusStop from;
  final BusStop to;

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatTime(from.arrivalAt),
                style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                from.name,
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
              ),
              if (from.cityName.isNotEmpty)
                Text(
                  from.cityName,
                  style:
                      AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Icon(AppIcons.forward, size: 18, color: AppColors.textMuted),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTime(to.arrivalAt),
                style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                to.name,
                textAlign: TextAlign.end,
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
              ),
              if (to.cityName.isNotEmpty)
                Text(
                  to.cityName,
                  textAlign: TextAlign.end,
                  style:
                      AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SeatChip extends StatelessWidget {
  const _SeatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Passenger section ────────────────────────────────────────────────────────

class _PassengerSection extends StatelessWidget {
  const _PassengerSection({required this.state, required this.l10n});
  final BusBookingState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    const name = 'Ahmed Mohamed';
    const phone = '+20 10 1234 5678';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.confirmPassengerSection,
          style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _PassengerRow(
                label: l10n.confirmPassengerName,
                value: name,
                icon: AppIcons.user,
                editLabel: l10n.confirmEditComingSoon,
              ),
              const Divider(height: 1, color: AppColors.hairline),
              _PassengerRow(
                label: l10n.confirmPassengerPhone,
                value: phone,
                icon: AppIcons.phone,
                editLabel: l10n.confirmEditComingSoon,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PassengerRow extends StatelessWidget {
  const _PassengerRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.editLabel,
  });
  final String label;
  final String value;
  final IconData icon;
  final String editLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(editLabel)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted),
                    ),
                    Text(
                      value,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(AppIcons.forward,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Payment section ──────────────────────────────────────────────────────────

class _PaymentSection extends ConsumerWidget {
  const _PaymentSection({
    required this.state,
    required this.l10n,
  });
  final BusBookingState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisa = state.paymentMethod == PaymentMethod.visa;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.confirmPaymentSection,
          style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        _PaymentOption(
          icon: AppIcons.ticket,
          label: l10n.confirmPaymentCard,
          selected: isVisa,
          onTap: () {
            ref
                .read(busBookingProvider.notifier)
                .setPaymentMethod(PaymentMethod.visa);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        _PaymentOption(
          icon: AppIcons.wallet,
          label: l10n.confirmPaymentWallet,
          selected: false,
          enabled: false,
          subtitle: l10n.confirmCardComingSoon,
          onTap: () {},
        ),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final bg = !enabled
        ? AppColors.bgBase
        : selected
            ? AppColors.primary
            : AppColors.bgCard;
    final fg = !enabled
        ? AppColors.textMuted
        : selected
            ? AppColors.onPrimary
            : AppColors.textPrimary;
    final iconColor = !enabled
        ? AppColors.textMuted
        : selected
            ? AppColors.onPrimary
            : AppColors.primary;
    final borderColor = selected ? AppColors.primary : AppColors.border;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: enabled ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  AppIcons.check,
                  size: 20,
                  color: AppColors.onPrimary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Price breakdown ──────────────────────────────────────────────────────────

class _PriceBreakdown extends StatelessWidget {
  const _PriceBreakdown({required this.state, required this.l10n});
  final BusBookingState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final pricePerSeat = state.segmentFare.round();
    final seatCount = state.selectedSeats.length;
    final total = pricePerSeat * seatCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.confirmPriceSection,
          style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              _PriceRow(
                label: l10n.confirmPricePerSeat,
                value: '$pricePerSeat EGP',
                bold: false,
              ),
              const SizedBox(height: AppSpacing.sm),
              _PriceRow(
                label: l10n.seatSelectionSeatsLabel,
                value: '$seatCount',
                bold: false,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(color: AppColors.hairline),
              const SizedBox(height: AppSpacing.sm),
              _PriceRow(
                label: l10n.confirmTotal,
                value: '$total EGP',
                bold: true,
                valueColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    required this.bold,
    this.valueColor,
  });
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final valueStyle = bold
        ? AppTypography.title.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.textPrimary,
          )
        : AppTypography.body.copyWith(
            color: valueColor ?? AppColors.textSecondary,
          );
    final labelStyle = bold
        ? AppTypography.title.copyWith(fontWeight: FontWeight.w700)
        : AppTypography.body.copyWith(color: AppColors.textSecondary);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        Text(value, style: valueStyle),
      ],
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/bus/presentation/passenger_confirm_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/bus/presentation/passenger_confirm_screen.dart test/features/bus/presentation/passenger_confirm_screen_test.dart
git commit -m "feat(bus): recap chosen stops, date and seats on confirm screen"
```

---

## Task 7: Full-suite verification

**Files:** none (verification only)

- [ ] **Step 1: Run the analyzer across the whole project**

Run: `flutter analyze`
Expected: no errors, no warnings introduced by this feature (pre-existing warnings elsewhere, if any, are out of scope).

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: all tests PASS, including the pre-existing `bus_booking_notifier_test.dart`, `trip_card_test.dart`, `seat_grid_test.dart`, `trip_results_screen_test.dart`, `bus_dto_mapper_test.dart`, plus every test added/updated in Tasks 2–6.

- [ ] **Step 3: Manual verification in a running app**

Use the `/run` skill to launch the app, then walk the flow:

1. Search a bus trip, open trip details — confirm the "Route → Seat → Confirm" bar appears at top with **Route** highlighted, the ticket card + amenities render as before, and the full-route timeline lists every boarding stop (blue) then every drop-off stop (amber) in time order.
2. Tap a different boarding stop and a different drop-off stop — confirm the live fare in the ticket card and footer updates, and the tapped stops show their "Board here"/"Drop off" markers.
3. Tap "Choose seats" — confirm the step bar now highlights **Seat**, with **Route** shown completed (tappable).
4. Tap the completed **Route** node — confirm it navigates back to trip details with your stop choices intact.
5. Return to seat selection, pick a seat, tap "Continue" — confirm the step bar highlights **Confirm**, and the summary card shows the operator, your chosen boarding/drop-off stop names and times, the trip date, and your selected seat number(s).
6. Switch the device/simulator to Arabic — repeat steps 1–5 and confirm RTL layout (step bar, timeline connector column, route recap) mirrors correctly and all new labels are in Arabic.

- [ ] **Step 4: No commit for this task** (verification only; if any issue is found, fix it in the relevant task above and re-commit there).

---

## Notes for the executor

- `BusStop.locationId` is the stable identity used to match the selected stop against timeline/list entries — always compare by `locationId`, not object equality (Freezed gives value equality, but comparing by id is what the rest of the codebase already does, e.g. `StopSelector` did the same before removal).
- `setStops()` on `BusBookingNotifier` already clears `selectedSeats`/`seatMap` whenever the stop pair changes (see `lib/features/bus/presentation/providers/bus_booking_providers.dart:148-156`) — this is existing, correct behavior: changing stops re-keys the fare and seat map, so seats must be re-picked. Nothing in this plan needs to change that.
- Do not add a shared `_SeatChip`/timeline-row widget across `seat_selection_screen.dart` and `passenger_confirm_screen.dart` — the codebase's established convention is small private per-file widgets (see `_PriceRow`, `_PassengerRow`, `_StopInfo`, etc.); duplicating a ~15-line chip class matches that convention better than a premature shared extraction.
