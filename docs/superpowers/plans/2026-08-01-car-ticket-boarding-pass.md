# Car Boarding-Pass Ticket Cards Implementation Plan

> **For agentic workers:** Execute task-by-task on the **current branch**
> (do not create a new branch). Commits only if the user explicitly asks.

**Goal:** Make private-car search and My Tickets cards use a boarding-pass shell
matching bus look, via new car-local widgets (no bus imports).

**Architecture:** Independent `CarTicketBorder` under `car/presentation/widgets`,
new `CarTripTicketCard` for results, wrap `CarOrderCard` in the same border.
Bus untouched.

**Tech Stack:** Flutter, Material `OutlinedBorder`, Riverpod (screen wiring
only), `flutter_test`, existing l10n / design tokens.

## Global Constraints

- Package imports: `package:safaria/...` only.
- No imports from `features/bus/`.
- Icons: `PhosphorIconsLight.*` only.
- Tokens: `AppColors` / `AppSpacing` / `AppRadius` / `AppTypography`.
- All user strings via `AppLocalizations`.
- Directional insets (`EdgeInsetsDirectional`).
- Do not create a new git branch.
- Do not commit unless the user asks.

## File map

| File | Action |
|------|--------|
| `lib/features/car/presentation/widgets/car_ticket_shell.dart` | Create — `CarTicketBorder` |
| `lib/features/car/presentation/widgets/car_trip_ticket_card.dart` | Create — search card |
| `lib/features/car/presentation/widgets/car_order_card.dart` | Modify — use shell |
| `lib/features/car/presentation/car_tier_results_screen.dart` | Modify — use new card |
| `lib/features/car/presentation/widgets/car_tier_card.dart` | Delete after swap |
| `test/.../car_trip_ticket_card_test.dart` | Create (replaces tier card tests) |
| `test/.../car_tier_results_screen_test.dart` | Modify finder type |
| `test/.../car_order_card_test.dart` | Create |
| `test/.../car_tier_card_test.dart` | Delete with `CarTierCard` |

---

### Task 1: `CarTicketBorder`

**Files:**
- Create: `lib/features/car/presentation/widgets/car_ticket_shell.dart`
- Test: `test/features/car/presentation/widgets/car_ticket_shell_test.dart`

**Produces:**
- `class CarTicketBorder extends OutlinedBorder` with
  `radius`, `notchRadius`, `notchOffsetFromBottom`, `dashColor`, `side`

- [ ] **Step 1: Write failing smoke test**

```dart
testWidgets('CarTicketBorder paints as Material shape without throw',
    (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Material(
          color: Colors.white,
          shape: const CarTicketBorder(
            radius: 20,
            notchRadius: 10,
            notchOffsetFromBottom: 60,
          ),
          clipBehavior: Clip.antiAlias,
          child: const SizedBox(height: 160, width: 320),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: Implement `CarTicketBorder`**

Copy geometry from bus `TicketBorder` into a new class named `CarTicketBorder`
in `car_ticket_shell.dart`. Use `AppColors.border` as the default dash color
call site (constructor can take `Color`). Include `copyWith`, `scale`, `==`,
`hashCode`, path builder, and dashed tear `paint`.

- [ ] **Step 3: Run test — expect PASS**

```bash
flutter test test/features/car/presentation/widgets/car_ticket_shell_test.dart
```

---

### Task 2: `CarTripTicketCard` + results wiring

**Files:**
- Create: `lib/features/car/presentation/widgets/car_trip_ticket_card.dart`
- Modify: `lib/features/car/presentation/car_tier_results_screen.dart`
- Create: `test/features/car/presentation/widgets/car_trip_ticket_card_test.dart`
- Modify: `test/features/car/presentation/car_tier_results_screen_test.dart`
- Delete: `lib/features/car/presentation/widgets/car_tier_card.dart`
- Delete: `test/features/car/presentation/widgets/car_tier_card_test.dart`

**Consumes:** `CarTicketBorder`, `CarTripQuote`, `FakeCarRepository.sampleQuote`  
**Produces:** `CarTripTicketCard({quote, rounded, onTap})`

- [ ] **Step 1: Write failing widget tests**

Assert: company `Sky Travel`, locations `Cairo` / `Alexandria`, seats icon,
`bookingSelect` / `Select`, price containing `69.87`, tap increments callback,
Arabic locale shows `قابل للاسترداد` and still finds Select.

- [ ] **Step 2: Implement `CarTripTicketCard`**

Structure (mirror bus stub height 60):

1. `Material` + `CarTicketBorder(radius: AppRadius.xl, notchOffsetFromBottom: 60)`
2. Header row: 48–64 vehicle image | company + category·model + refundable badge
3. Route row: from name | Wrap of seats/bags/gear chips | to name  
   (empty name → `—`; no clock times)
4. Stub: `tripResultsFareLabel` + formatted price/currency | Select button
   (`l10n.bookingSelect`, primary filled like bus `_SelectButton`)
5. Select and optional body `InkWell` both call `onTap`

Reuse visual helpers privately in the file (image, chips, refundable badge) —
do not import deleted `CarTierCard`.

- [ ] **Step 3: Wire `CarTierResultsScreen`**

Replace `CarTierCard` with `CarTripTicketCard` (same props / navigation).

- [ ] **Step 4: Update results screen test finders; delete `CarTierCard` + old test**

- [ ] **Step 5: Run tests**

```bash
flutter test test/features/car/presentation/widgets/car_trip_ticket_card_test.dart test/features/car/presentation/car_tier_results_screen_test.dart
```

---

### Task 3: Wrap `CarOrderCard` in shell

**Files:**
- Modify: `lib/features/car/presentation/widgets/car_order_card.dart`
- Create: `test/features/car/presentation/widgets/car_order_card_test.dart`

**Consumes:** `CarTicketBorder`, existing `CarOrder` / `FakeCarRepository` samples

- [ ] **Step 1: Write failing test**

Pump `CarOrderCard` with `FakeCarRepository.sampleOrder` (or equivalent),
expect company, route text, pay button when pending.

- [ ] **Step 2: Refactor `CarOrderCard` chrome**

Follow `BusOrderCard` pattern:

- Compute stub height from visible actions (button height 40 + gaps + padding).
- `Material(shape: CarTicketBorder(...), color: AppColors.bgCard, clipBehavior: antiAlias)`
- Above tear: existing body (company, badge, route, date, price) in `InkWell(onTap)`
- Below tear: action buttons column
- Keep public API unchanged (`order`, `onPay`, `onOpenVoucher`, `onCancel`, `onTap`)

- [ ] **Step 3: Run tests + analyze**

```bash
flutter test test/features/car/presentation/
flutter analyze lib/features/car/presentation/widgets/ lib/features/car/presentation/car_tier_results_screen.dart
```

---

## Spec coverage check

| Spec requirement | Task |
|------------------|------|
| Independent shell, no bus import | 1 |
| Search card bus-like sections + Select → details | 2 |
| Results screen swap | 2 |
| Remove / stop using `CarTierCard` | 2 |
| Order card shell, content preserved | 3 |
| Tests updated | 2, 3 |
| Bus untouched | all |

## Execution note

User requested: write spec + plan + implement on the **same branch**. Execute
Tasks 1–3 inline in this session; skip branch creation and skip commits unless
asked.
