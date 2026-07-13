# Bus Payment Resume + Pending Ticket Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the bus booking flow from creating a duplicate temporary order when the rider re-confirms after abandoning payment, warn them before they back out of the payment WebView, and make the existing pending screen read as a held ticket rather than a generic notice.

**Architecture:** All changes are additive/behavioral inside the existing `lib/features/bus` slice — one guard clause in `BusBookingNotifier.confirmBooking()`, one optional callback on the shared `BookingAppBar`, a `PopScope` + confirmation dialog on `PaymentWebViewScreen`, and a badge on `PaymentPendingScreen`. No new entities, routes, or backend calls.

**Tech Stack:** Flutter, Riverpod (`Notifier`/`ProviderContainer` in tests), go_router, `webview_flutter`, `flutter_localizations` (ARB-based codegen via `flutter gen-l10n`).

**Spec:** `docs/superpowers/specs/2026-07-13-bus-payment-resume-pending-ticket-design.md`

---

## Task 1: Reuse the held payment order instead of duplicating it

**Files:**
- Modify: `lib/features/bus/presentation/providers/bus_booking_providers.dart:204-261`
- Modify: `test/features/bus/fake_bus_repository.dart`
- Modify: `test/features/bus/bus_booking_notifier_test.dart`

- [ ] **Step 1: Add a call counter to the fake repository**

In `test/features/bus/fake_bus_repository.dart`, add a counter field and increment it inside `createTicket`:

```dart
  BusTripsPage? tripsPage;
  BusTripSummary? tripByIdResult;
  SeatMap? seatMapResult;
  BusTicket? ticketResult;
  BusOrderStatus? orderStatusResult;
  List<BusLocation>? locationsResult;
  int createTicketCallCount = 0;
```

```dart
  @override
  Future<BusTicket> createTicket(
    BusCreateTicketRequest request, {
    required BusTripSummary trip,
    required BusStop fromStop,
    required BusStop toStop,
  }) async {
    createTicketCallCount++;
    return ticketResult ??
        BusTicket(
          bookingRef: '000001',
          orderId: '1',
          trip: trip,
          fromStop: fromStop,
          toStop: toStop,
          seats: request.seats.map((s) => s.seatId).toList(),
          ticketLines: const [],
          total: '100 EGP',
          currency: 'EGP',
          issuedAt: DateTime(2026, 7, 10),
        );
  }
```

- [ ] **Step 2: Write the failing tests**

Append to the `group('BusBookingNotifier', ...)` block in
`test/features/bus/bus_booking_notifier_test.dart` (after the existing
`verifyPayment stays pending...` test, before the closing `});`):

```dart
    test(
        'confirmBooking reuses the held ticket for the same trip/stops/seats',
        () async {
      final repo = FakeBusRepository(ticketResult: _pendingTicket());
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);
      await _prepareBooking(notifier);

      await notifier.confirmBooking();
      expect(repo.createTicketCallCount, 1);

      // Rider backed out of payment and taps "Confirm & pay" again with the
      // exact same trip/stops/seats — must reuse the held order.
      await notifier.confirmBooking();

      expect(repo.createTicketCallCount, 1);
      expect(
        container.read(busBookingProvider).status,
        BusBookingStatus.awaitingPayment,
      );
    });

    test(
        'confirmBooking creates a new order when seats changed since the held ticket',
        () async {
      final repo = FakeBusRepository(ticketResult: _pendingTicket());
      final container = makeContainer(repo);
      final notifier = container.read(busBookingProvider.notifier);
      await _prepareBooking(notifier);
      await notifier.confirmBooking();
      expect(repo.createTicketCallCount, 1);

      // Rider goes back, picks a different seat, confirms again.
      notifier.toggleSeat('16');
      notifier.toggleSeat('17');
      await notifier.confirmBooking();

      expect(repo.createTicketCallCount, 2);
    });
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/features/bus/bus_booking_notifier_test.dart`
Expected: the two new tests FAIL — `createTicketCallCount` is 2 on the
first new test (no reuse guard exists yet, so the second `confirmBooking()`
call hits the repo again).

- [ ] **Step 4: Implement the reuse guard**

In `lib/features/bus/presentation/providers/bus_booking_providers.dart`,
add a private helper method inside `BusBookingNotifier` (just above
`confirmBooking`):

```dart
  /// Whether [ticket] already represents a gateway order held for exactly
  /// this trip/stop-pair/seat selection. If so, `confirmBooking` reuses its
  /// `payment_url` instead of creating a duplicate temporary booking.
  bool _ticketReusable(
    BusTicket ticket,
    BusTripSummary trip,
    BusStop from,
    BusStop to,
    List<String> seats,
  ) {
    if ((ticket.paymentUrl ?? '').isEmpty) return false;
    if (ticket.trip.id != trip.id) return false;
    if (ticket.fromStop.locationId != from.locationId) return false;
    if (ticket.toStop.locationId != to.locationId) return false;
    return ticket.seats.length == seats.length &&
        ticket.seats.toSet().containsAll(seats);
  }
```

Then change `confirmBooking` (replace the existing method body) to check it
right after the existing validation, before the `confirming` status is set:

```dart
  Future<void> confirmBooking() async {
    final trip = state.selectedTrip;
    final params = state.searchParams;
    final from = state.fromStop;
    final to = state.toStop;
    if (trip == null || params == null || from == null || to == null) {
      state = state.copyWith(
        status: BusBookingStatus.error,
        error: 'No trip selected',
      );
      return;
    }
    if (state.selectedSeats.isEmpty) {
      state = state.copyWith(
        status: BusBookingStatus.error,
        error: 'No seats selected',
      );
      return;
    }

    final heldTicket = state.ticket;
    if (heldTicket != null &&
        _ticketReusable(heldTicket, trip, from, to, state.selectedSeats)) {
      state = state.copyWith(status: BusBookingStatus.awaitingPayment);
      return;
    }

    state = state.copyWith(status: BusBookingStatus.confirming, error: null);
    try {
      final ticket = await _repo.createTicket(
        BusCreateTicketRequest(
          tripId: trip.id,
          fromCityId: params.cityFromId,
          toCityId: params.cityToId,
          fromLocationId: from.locationId,
          toLocationId: to.locationId,
          date: toIsoDate(params.date),
          currency: params.currency,
          seats: state.selectedSeats
              .map((id) => BusSeatSelection(seatId: id, seatTypeId: id))
              .toList(),
        ),
        trip: trip,
        fromStop: from,
        toStop: to,
      );
      // The order is created in a `pending` state with a gateway payment_url.
      // Hand off to the payment WebView; the booking is only `confirmed` once
      // `verifyPayment` reads back a paid status. If no payment_url came back
      // (unexpected for the card path), fall through to confirmed so the rider
      // isn't stranded.
      final hasPaymentUrl = (ticket.paymentUrl ?? '').isNotEmpty;
      state = state.copyWith(
        status: hasPaymentUrl
            ? BusBookingStatus.awaitingPayment
            : BusBookingStatus.confirmed,
        ticket: ticket,
      );
    } catch (e) {
      state = state.copyWith(
        status: BusBookingStatus.error,
        error: e.toString(),
      );
    }
  }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/bus/bus_booking_notifier_test.dart`
Expected: PASS — all tests in the file green, including the two new ones.

- [ ] **Step 6: Commit**

```bash
git add lib/features/bus/presentation/providers/bus_booking_providers.dart test/features/bus/fake_bus_repository.dart test/features/bus/bus_booking_notifier_test.dart
git commit -m "fix(bus): reuse held payment order instead of duplicating on re-confirm"
```

---

## Task 2: Let `BookingAppBar` override the back action

**Files:**
- Modify: `lib/features/bus/presentation/widgets/booking_app_bar.dart`
- Test: `test/features/bus/presentation/widgets/booking_app_bar_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `test/features/bus/presentation/widgets/booking_app_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/presentation/widgets/booking_app_bar.dart';

void main() {
  testWidgets('invokes onBack instead of popping when provided',
      (tester) async {
    var backTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: BookingAppBar(
          title: 'Title',
          onBack: () => backTapped = true,
        ),
      ),
    );

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    expect(backTapped, isTrue);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/bus/presentation/widgets/booking_app_bar_test.dart`
Expected: FAIL to compile — `onBack` is not a defined parameter of
`BookingAppBar` yet.

- [ ] **Step 3: Add the `onBack` parameter**

In `lib/features/bus/presentation/widgets/booking_app_bar.dart`, replace the
constructor and fields:

```dart
class BookingAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BookingAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final VoidCallback? onBack;
```

Then update the back `IconButton`'s `onPressed`:

```dart
              IconButton(
                icon: Transform.flip(
                  flipX: Directionality.of(context) == TextDirection.rtl,
                  child:
                      const Icon(AppIcons.back, color: AppColors.textPrimary),
                ),
                onPressed: onBack ?? () => context.pop(),
              ),
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/bus/presentation/widgets/booking_app_bar_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the full bus widget test suite to confirm no regression**

Run: `flutter test test/features/bus/presentation/`
Expected: PASS — every screen using `BookingAppBar` without `onBack` still
falls back to `context.pop()`.

- [ ] **Step 6: Commit**

```bash
git add lib/features/bus/presentation/widgets/booking_app_bar.dart test/features/bus/presentation/widgets/booking_app_bar_test.dart
git commit -m "feat(bus): let BookingAppBar override the back action"
```

---

## Task 3: Add localization keys for the leave-payment prompt and pending badge

**Files:**
- Modify: `lib/l10n/app_en.arb:237`
- Modify: `lib/l10n/app_ar.arb:175`

- [ ] **Step 1: Add the English keys**

In `lib/l10n/app_en.arb`, after line 237
(`"paymentPendingBackHome": "Back to home",`) and before the blank line that
precedes `"profileGuest"`, insert:

```json
  "paymentPendingBadge": "Pending payment",
  "paymentLeaveTitle": "Leave payment?",
  "paymentLeaveBody": "Your seat is held, but payment isn't finished yet. You can complete it later from your booking.",
  "paymentLeaveStay": "Stay",
  "paymentLeaveConfirm": "Leave",
```

- [ ] **Step 2: Add the Arabic keys**

In `lib/l10n/app_ar.arb`, after line 175
(`"paymentPendingBackHome": "العودة للرئيسية",`) and before the blank line
that precedes `"profileGuest"`, insert:

```json
  "paymentPendingBadge": "بانتظار الدفع",
  "paymentLeaveTitle": "مغادرة صفحة الدفع؟",
  "paymentLeaveBody": "مقعدك لا يزال محجوزاً، لكن الدفع لم يكتمل بعد. يمكنك إكمال الدفع لاحقاً من حجزك.",
  "paymentLeaveStay": "البقاء",
  "paymentLeaveConfirm": "مغادرة",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: exits with no output/errors; `lib/l10n/app_localizations.dart`,
`app_localizations_en.dart`, `app_localizations_ar.dart` are rewritten
(these are gitignored — do not `git add` them).

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "feat(bus): add l10n strings for leave-payment prompt and pending badge"
```

---

## Task 4: Pending-payment badge on the pending ticket screen

**Files:**
- Modify: `lib/features/bus/presentation/payment_pending_screen.dart`
- Modify: `test/features/bus/presentation/payment_pending_screen_test.dart`

- [ ] **Step 1: Write the failing test assertions**

In `test/features/bus/presentation/payment_pending_screen_test.dart`, update
the first test to also check the new badge, and the Arabic test to check
its translation:

```dart
  testWidgets('shows the 15-minute hold message and both CTAs', (tester) async {
    await _pump(tester);

    expect(find.text('Pending payment'), findsOneWidget);
    expect(find.text('Payment pending'), findsOneWidget);
    expect(find.textContaining('15 minutes'), findsOneWidget);
    expect(find.text('Complete payment'), findsOneWidget);
    expect(find.text('Back to home'), findsOneWidget);
  });
```

```dart
  testWidgets('renders in Arabic (RTL)', (tester) async {
    await _pump(tester, locale: const Locale('ar'));

    expect(find.text('بانتظار الدفع'), findsOneWidget);
    expect(find.text('في انتظار الدفع'), findsOneWidget);
    expect(find.text('أكمل الدفع'), findsOneWidget);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/bus/presentation/payment_pending_screen_test.dart`
Expected: FAIL — `find.text('Pending payment')` (and the Arabic
equivalent) find zero widgets; the badge doesn't exist yet.

- [ ] **Step 3: Add the badge to `_PendingHero`**

In `lib/features/bus/presentation/payment_pending_screen.dart`, replace the
`_PendingHero` widget's `build` method:

```dart
class _PendingHero extends StatelessWidget {
  const _PendingHero({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: AppColors.secondaryTint,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            AppIcons.calendar,
            color: AppColors.secondary,
            size: 36,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.secondaryTint,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            l10n.paymentPendingBadge,
            style: AppTypography.caption.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.paymentPendingTitle,
          textAlign: TextAlign.center,
          style: AppTypography.h1,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.paymentPendingBody,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/bus/presentation/payment_pending_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bus/presentation/payment_pending_screen.dart test/features/bus/presentation/payment_pending_screen_test.dart
git commit -m "feat(bus): add pending-payment badge to the pending ticket screen"
```

---

## Task 5: Warn before leaving the payment WebView

**Files:**
- Modify: `lib/features/bus/presentation/payment_webview_screen.dart`
- Test: `test/features/bus/presentation/payment_webview_screen_test.dart` (new)

This task extracts the confirmation dialog into a standalone, testable
top-level function (`confirmLeavePayment`) — the same pattern this file
already uses for `classifyPaymentNav`, which is tested in isolation in
`payment_nav_classify_test.dart` without mounting the full screen. The full
`PaymentWebViewScreen` is not pumped in tests because `WebViewController()`
requires a real platform webview implementation that isn't registered under
`flutter_test`; the integrated back-button → dialog → verify → navigate
flow is covered by the manual verification pass instead (see the spec's
Verification section).

- [ ] **Step 1: Write the failing tests**

Create `test/features/bus/presentation/payment_webview_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/bus/presentation/payment_webview_screen.dart';
import 'package:rego/l10n/app_localizations.dart';

Widget _harness({
  required Locale locale,
  required ValueChanged<bool> onResult,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () async {
          final leave = await confirmLeavePayment(context);
          onResult(leave);
        },
        child: const Text('trigger'),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the leave-payment prompt with Stay and Leave',
      (tester) async {
    await tester.pumpWidget(
      _harness(locale: const Locale('en'), onResult: (_) {}),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.text('Leave payment?'), findsOneWidget);
    expect(find.text('Stay'), findsOneWidget);
    expect(find.text('Leave'), findsOneWidget);
  });

  testWidgets('Stay dismisses and reports the rider did not leave',
      (tester) async {
    bool? result;
    await tester.pumpWidget(
      _harness(locale: const Locale('en'), onResult: (v) => result = v),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(find.text('Leave payment?'), findsNothing);
  });

  testWidgets('Leave reports the rider chose to leave', (tester) async {
    bool? result;
    await tester.pumpWidget(
      _harness(locale: const Locale('en'), onResult: (v) => result = v),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('renders in Arabic (RTL)', (tester) async {
    await tester.pumpWidget(
      _harness(locale: const Locale('ar'), onResult: (_) {}),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.text('مغادرة صفحة الدفع؟'), findsOneWidget);
    expect(find.text('البقاء'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/bus/presentation/payment_webview_screen_test.dart`
Expected: FAIL to compile — `confirmLeavePayment` doesn't exist yet.

- [ ] **Step 3: Add the required import**

In `lib/features/bus/presentation/payment_webview_screen.dart`, add to the
imports (needed for `AppRadius` in the dialog's rounded border):

```dart
import 'package:rego/core/theme/app_spacing.dart';
```

- [ ] **Step 4: Add the `confirmLeavePayment` function**

In `lib/features/bus/presentation/payment_webview_screen.dart`, add this
top-level function directly below `classifyPaymentNav`:

```dart
/// Shows the "leave payment?" confirmation the rider sees when they try to
/// back out of the checkout WebView before it's resolved. Returns true only
/// if they explicitly chose to leave; false (including a dismissed dialog)
/// means stay on the checkout page.
Future<bool> confirmLeavePayment(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final leave = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      title: Text(l10n.paymentLeaveTitle, style: AppTypography.h2),
      content: Text(
        l10n.paymentLeaveBody,
        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            l10n.paymentLeaveConfirm,
            style: AppTypography.title.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            l10n.paymentLeaveStay,
            style: AppTypography.title.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  return leave ?? false;
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/bus/presentation/payment_webview_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Wire the dialog into back handling**

In `lib/features/bus/presentation/payment_webview_screen.dart`, add a guard
field to `_PaymentWebViewScreenState` (next to the existing
`_verifyTriggered` field):

```dart
  bool _leavePromptOpen = false;
```

Add a handler method (below `_verify`):

```dart
  Future<void> _handleBackRequest() async {
    if (_leavePromptOpen) return;
    _leavePromptOpen = true;
    final leave = await confirmLeavePayment(context);
    _leavePromptOpen = false;
    if (leave) {
      unawaited(_verify());
    }
  }
```

Then replace the `build` method's `return Scaffold(...)` with a
`PopScope`-wrapped version, and pass `onBack` to `BookingAppBar`:

```dart
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    ref.listen<BusBookingState>(busBookingProvider, (prev, next) {
      if (next.status == BusBookingStatus.confirmed) {
        context.pushReplacement(BusRoutes.ticket);
      } else if (next.status == BusBookingStatus.paymentPending) {
        context.pushReplacement(BusRoutes.pending);
      }
    });

    final isVerifying = ref.watch(busBookingProvider).status ==
        BusBookingStatus.verifyingPayment;
    final controller = _controller;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_handleBackRequest());
      },
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: BookingAppBar(
          title: l10n.paymentTitle,
          onBack: () => unawaited(_handleBackRequest()),
          action: TextButton(
            onPressed: isVerifying ? null : () => unawaited(_verify()),
            child: Text(
              l10n.paymentDone,
              style: AppTypography.body.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            if (controller != null)
              WebViewWidget(controller: controller)
            else
              const SizedBox.shrink(),
            if (controller == null || _loading || isVerifying)
              _LoadingOverlay(
                label: isVerifying ? l10n.paymentVerifying : null,
              ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 7: Run the full bus test suite**

Run: `flutter test test/features/bus/`
Expected: PASS — no regressions in any bus feature test.

- [ ] **Step 8: Commit**

```bash
git add lib/features/bus/presentation/payment_webview_screen.dart test/features/bus/presentation/payment_webview_screen_test.dart
git commit -m "feat(bus): warn before leaving the payment WebView"
```

---

## Task 6: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Static analysis**

Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: all tests PASS.

- [ ] **Step 3: Manual verification on a mobile emulator/device**

REGO is mobile-only (no web preview). Launch the app
(`flutter run`), sign in or continue as guest, and:

1. Search a bus trip → pick a trip → pick a seat → Confirm screen → tap
   **Confirm & pay**.
2. In the payment WebView, press the hardware back button (or the app-bar
   arrow) → confirm the **Leave payment?** dialog appears with **Stay** /
   **Leave**.
3. Tap **Stay** → dialog dismisses, WebView still showing the checkout page.
4. Press back again → tap **Leave** → land on the pending ticket screen;
   confirm the amber **Pending payment** badge is visible above the
   "Payment pending" heading, along with the booking recap (ref, seats,
   total).
5. Tap **Complete payment** → confirm the WebView reopens the *same*
   checkout session (not a freshly created order — e.g. check the gateway
   page doesn't ask to re-enter trip details from scratch) → complete the
   test payment → confirm you land on the confirmed e-ticket screen.
6. Separately, trigger the existing failed-payment gateway redirect path
   and confirm it still lands on the same pending ticket screen with the
   badge.
7. Repeat steps 2-4 once with the device language set to Arabic and confirm
   the dialog and badge render correctly in RTL.

- [ ] **Step 4: Report results**

If all steps pass, the feature is complete — no further commit needed for
this task (verification-only).
