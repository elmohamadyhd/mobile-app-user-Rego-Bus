# Wallet feature — design

**Date:** 2026-07-15
**Status:** Approved (pending spec review)

## Goal

Remove the Wallet bottom-nav tab (currently a `ComingSoonScreen` stub) and replace it
with a real, API-backed wallet accessible from the Profile menu: view balance and
transaction history, and top up via the hosted MyFatoorah checkout.

## Current state

- `MainNavBar` renders 4 destinations: Home, Tickets, Wallet, Profile
  (`lib/features/shell/presentation/widgets/main_nav_bar.dart:60-65`).
- `AppRoutes.wallet` (`/wallet`) is a `StatefulShellBranch` rendering
  `ComingSoonScreen` (`lib/core/router/app_router.dart:117-127`).
- `ProfileScreen`'s Wallet menu row shows a "coming soon" snackbar
  (`lib/features/profile/presentation/profile_screen.dart:48-52`).
- No `lib/features/wallet/` slice exists.
- A V1 visual design exists for "My Wallet" and "Top-up" screens in
  `design/V1/REGO Buses - Batch 1+2.dc.html` (screens 22–23), including a Transfer
  action and a saved-card picker — neither has a backing API and both are **out of
  scope** (see Non-goals).

## Backend APIs (`docs/wadeny-apis.md:1290-1375`)

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/profile/wallet` | Balance + transaction list |
| `POST` | `/profile/wallet/:amount/charge` | Returns a hosted payment link |

```json
// GET /profile/wallet
{
  "status": 200, "message": "Wallet", "errors": {},
  "data": [
    { "id": 79, "balance": "25.00", "transactions": [
      { "id": 86, "description": "تم إضافة 25 جنيه لمحفظتك ترحيبًا بك معنا. ",
        "type": "deposit", "amount": "25.00" }
    ] }
  ]
}
```

```json
// POST /profile/wallet/:amount/charge
{ "status": 200, "message": "Payment link", "errors": {},
  "data": { "link": "https://demo.MyFatoorah.com/KWT/ia/…" } }
```

Notable gaps versus the V1 design and versus the bus payment flow:
- No timestamp on transactions (design shows one).
- No saved-card list / card-management endpoint.
- No transfer endpoint.
- No dedicated charge-verification endpoint (same shape as the existing bus
  payment gap noted in project memory) — verification has to be inferred from
  re-fetching the wallet.

## Non-goals

- Transfer-to-another-user.
- Saved-card management (add/remove/select a card). The MyFatoorah hosted page
  collects card details itself.
- Transaction timestamps beyond what the API happens to send (see Data mapping).
- Any changes to the bus feature's payment flow or shared extraction from it —
  the wallet gets its own WebView screen, matching the existing preference for
  isolated feature slices over shared cores.

## Architecture

New standalone slice, following the same layering as `features/bus`:

```
lib/features/wallet/
├── data/
│   ├── wallet_api.dart              # Dio calls, raw JSON in/out
│   ├── wallet_dto_mapper.dart       # envelope → domain, defensive parsing
│   └── wallet_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── wallet.dart              # Wallet, WalletTransaction (Freezed)
│   └── repositories/
│       └── wallet_repository.dart
└── presentation/
    ├── wallet_routes.dart
    ├── wallet_screen.dart           # balance + transaction list
    ├── wallet_topup_screen.dart     # amount entry
    ├── wallet_payment_webview_screen.dart
    ├── providers/
    │   └── wallet_providers.dart
    └── widgets/
        ├── wallet_app_bar.dart
        ├── wallet_balance_card.dart
        └── wallet_transaction_tile.dart
```

## Navigation changes

**`main_nav_bar.dart`** — drop the wallet entry from the `destinations` list
(`lib/features/shell/presentation/widgets/main_nav_bar.dart:60-65`), leaving Home,
Tickets, Profile. No index is hardcoded elsewhere — `MainShell` reads
`navigationShell.currentIndex` generically — so removing the branch is safe.

**`app_router.dart`** — delete the wallet `StatefulShellBranch`
(lines 117-127) and the `AppRoutes.wallet` constant. Add
`...walletRoutes()` to the root route list (same pattern as `...busRoutes()`),
so the wallet lives on the root navigator as a full-screen flow — bottom nav
hides while it's open, matching how booking screens already behave and how the
V1 design draws it.

**`wallet_routes.dart`**:

```dart
abstract final class WalletRoutes {
  static const wallet = '/profile/wallet';
  static const topUp = '/profile/wallet/top-up';
  static const pay = '/profile/wallet/pay';
}
```

**`profile_screen.dart`** — the Wallet menu row (`lib/features/profile/presentation/profile_screen.dart:48-52`)
changes from `_showComingSoon` to:
- Signed-in: `context.push(WalletRoutes.wallet)`.
- Guest: `context.go(AppRoutes.login, extra: AuthGateArgs(returnTo: WalletRoutes.wallet))` —
  identical pattern to the existing `_ProfileSignInCard` guest CTA
  (`profile_screen.dart:71-78`). Guests have no wallet server-side, so gating at
  the menu tap (rather than rendering an empty/error wallet screen) avoids a
  round trip that's guaranteed to fail.

`navWallet` / the wallet nav icon stay in `app_icons.dart` and the onboarding
slide (`onboarding_screen.dart:61`, purely illustrative) — only the bottom-nav
destination is removed.

## Domain layer

```dart
// wallet.dart
enum WalletTransactionType { deposit, withdraw, unknown }

@freezed
abstract class WalletTransaction with _$WalletTransaction {
  const factory WalletTransaction({
    required int id,
    required String description,
    required WalletTransactionType type,
    required double amount,
    DateTime? createdAt,
  }) = _WalletTransaction;
}

@freezed
abstract class Wallet with _$Wallet {
  const factory Wallet({
    required int id,
    required double balance,
    required String currency,
    required List<WalletTransaction> transactions,
  }) = _Wallet;
}
```

```dart
// wallet_repository.dart
abstract interface class WalletRepository {
  Future<Wallet> getWallet();

  /// Starts a top-up charge for a whole-currency-unit [amount] (see Top-up
  /// flow for why fractional amounts are rejected client-side). Returns the
  /// hosted checkout URL to load in the payment WebView.
  Future<String> charge(int amount);
}
```

`getWallet()` doubles as both the initial load and the post-payment
re-verification read (see Top-up flow) — one method, two call sites, no
separate "verify" concept invented on top of an API that doesn't have one.

## Data layer

**`wallet_api.dart`** — thin Dio wrapper, mirrors `bus_api.dart`:

```dart
class WalletApi {
  WalletApi(this._dio);
  final Dio _dio;

  Future<dynamic> getWallet() async =>
      (await _dio.get('/profile/wallet')).data;

  Future<dynamic> charge(int amount) async =>
      (await _dio.post('/profile/wallet/$amount/charge')).data;
}
```

**`wallet_dto_mapper.dart`** — defensive parsing, following
`bus_dto_mapper.dart`'s `_string`/`_int`-style helpers:

- `data` is a **list**; take `.first`. An **empty list maps to a zero-balance
  wallet** (`id: 0, balance: 0, transactions: []`), not an error — a brand-new
  account plausibly has no wallet row yet, and surfacing that as an error page
  would be misleading.
- `balance` and transaction `amount` are strings (`"25.00"`) → parsed with
  `double.tryParse(...) ?? 0`.
- `type`: `"deposit"` → `WalletTransactionType.deposit`; `"withdraw"` / `"debit"`
  / `"payment"` → `.withdraw`; anything else (including missing) →
  `.unknown`. Unknown types render **unsigned** (no `+`/`−`, neutral color) —
  see `BusOrderStatusKind.unknown` in `bus_order.dart:10` for the same
  don't-guess principle already established in this codebase.
- `createdAt`: probe `created_at` then `date`; parse with `DateTime.tryParse`;
  `null` when absent or unparseable. Never invented.
- `currency`: not present in the payload; default to `'EGP'`, matching the
  existing fallback in `bus_dto_mapper.dart:102`.
- Reuse `ApiException.fromEnvelope` / `BusDtoMapper.ensureSuccess`'s pattern for
  a shared `ensureSuccess(envelope)` check (status != 200 → throw) local to
  this mapper — not extracted to a shared module, per the isolation preference.

**`wallet_repository_impl.dart`** — same `_guard` wrapping pattern as
`BusRepositoryImpl` (catches `DioException` → `ApiException.fromDio`, lets
`ApiException` from the mapper pass through).

## Top-up flow

`wallet_topup_screen.dart`: `Scaffold` with `WalletAppBar` (see Screen chrome
above), body holds an amount entry field + 50/100/200/500 quick-pick chips
(visual only — the design's chips, no new component needed beyond a simple
`ChoiceChip`-style row) + a submit button reading
`l10n.walletTopUpCta(amount)` (e.g. "Top up 200 EGP").

**Amount is restricted to positive whole numbers.** `POST
/profile/wallet/:amount/charge` puts the amount directly in the URL path;
sending `25.50` would either 404 or get silently truncated server-side —
neither is acceptable, so the input field only accepts digits
(`FilteringTextInputFormatter.digitsOnly`) and submission is disabled for
`amount <= 0`.

On submit: `walletRepository.charge(amount)` → `context.push(WalletRoutes.pay,
extra: checkoutUrl)`, where `checkoutUrl` is the raw `String` returned by
`charge()`. No `PaymentFlowArgs`-style wrapper class is needed — unlike the bus
flow, wallet top-up has no "resume an existing order" mode to distinguish, so a
bare URL is enough.

## Payment WebView (wallet-owned)

A wallet-scoped copy of the bus flow's WebView pattern
(`bus/presentation/payment_webview_screen.dart`), **fully duplicated, not
imported** — consistent with the isolation preference and with how this was
scoped and approved (a wallet-owned screen, not a wallet screen that reaches
into `features/bus`). Concretely, `wallet_payment_webview_screen.dart` defines
its own:

- `Scaffold` + `WalletAppBar` (title, no back-arrow default action — back is
  intercepted by `PopScope`, same as the bus screen — plus a "Done" trailing
  action) wrapping a `WebViewController` with the same `NavigationDelegate`
  shape as the bus screen.
- A local top-level `classifyWalletPaymentNav(Uri) → WalletPaymentNavResult` —
  same `success-payment` / `failed-payment` path-segment logic as the bus
  feature's `classifyPaymentNav`/`PaymentNavResult`, copied rather than
  imported, and named distinctly to avoid any confusion with the bus copy when
  searching the codebase. Public (not underscore-prefixed), matching the bus
  original — both are top-level functions in their screen file, public
  specifically so a same-directory test file can call them directly (Dart
  privacy is per-file, so a private function couldn't be unit-tested from a
  separate test file at all). It's a five-line pure function; the cost of
  duplication is trivial next to the cost of a `features/wallet →
  features/bus` import that would make wallet undeletable without touching bus.
- A local top-level `confirmLeaveWalletPayment(BuildContext) → Future<bool>` +
  private `_WalletLeavePaymentDialog` widget, mirroring the bus feature's
  public `confirmLeavePayment` + private `_LeavePaymentDialog` split (public
  function for the same testability reason above; the dialog widget itself
  has no reason to be public). Shown when the rider tries to back out before
  the payment resolves.

The accepted tradeoff, matching prior decisions in this codebase: if the bus
team later tightens `classifyPaymentNav`'s redirect detection, the wallet copy
doesn't inherit the fix automatically. Both copies are small enough that this
is cheap to live with and cheap to fix by hand if it ever matters.

**Verification** — there is no charge-status endpoint, so on a terminal
redirect (or the rider tapping "Done"), the screen re-fetches
`walletRepository.getWallet()` and compares the new balance to the balance
captured when the top-up screen was entered:

| Redirect | Balance vs. before | Outcome |
|---|---|---|
| `failed-payment` | — | Failure toast |
| `success-payment` | increased | Success toast, show new balance |
| `success-payment` | unchanged | "Still confirming" toast (not failure — the gateway webhook may not have landed yet) |
| rider taps "Done" mid-flow | unchanged | Same as above — treated as pending, never as failure |

After any terminal outcome, invalidate the wallet provider so the wallet
screen reflects the re-fetched state when the rider lands back on it.

## Presentation / state

`wallet_providers.dart`:

```dart
final walletApiProvider = Provider<WalletApi>((ref) => WalletApi(ref.watch(dioProvider)));
final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => WalletRepositoryImpl(ref.watch(walletApiProvider)),
);

class WalletNotifier extends AsyncNotifier<Wallet> {
  @override
  Future<Wallet> build() => ref.read(walletRepositoryProvider).getWallet();

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => ref.read(walletRepositoryProvider).getWallet());
  }
}

final walletProvider = AsyncNotifierProvider<WalletNotifier, Wallet>(WalletNotifier.new);
```

Plain (non-autoDispose) `AsyncNotifier`, matching `busOrdersProvider` — state
should survive the rider navigating away and back within a session.

**Screen chrome.** The wallet screens are pushed full-screen routes with a back
arrow — not shell-tab bodies — so `ShellTabScrollView` / `SkylineTabHero`
(no back button by design; built for the persistent Home/Tickets/Profile tabs)
don't fit here. The bus feature's `BookingAppBar` is the right *shape* (title,
back arrow, optional trailing action) but it lives in
`features/bus/presentation/widgets/` and is only ever imported by bus screens
— it's bus-owned infrastructure, not a shared widget under `lib/shared/`.
Wallet gets its own small equivalent, `wallet/presentation/widgets/wallet_app_bar.dart`
(title + back + optional trailing action; no subtitle variant — wallet never
needs one). All three wallet screens use it inside a plain `Scaffold` with
`backgroundColor: AppColors.bgBase`, matching the bus feature's own pushed
screens (`trip_details_screen.dart`, `passenger_confirm_screen.dart`, etc.).

`wallet_screen.dart` body:
- `WalletBalanceCard` — balance, currency, "Top up" CTA → `WalletRoutes.topUp`.
- Transaction list — `WalletTransactionTile` per entry (icon by type, description,
  signed amount, date when present).
- Empty state when `transactions.isEmpty` (new account / no activity yet).
- Standard `AsyncValue` loading/error handling (spinner / retry), matching how
  `busOrdersProvider` is consumed elsewhere (e.g. `BusOrdersSection`'s
  `.when(loading:, error:, data:)`).

## Localization

New keys in `app_en.arb` / `app_ar.arb` (existing `navWallet` /
`profileMenuWallet` are reused as-is):

`walletTitle`, `walletBalanceLabel`, `walletTopUpCta`, `walletHistoryTitle`,
`walletEmptyTitle`, `walletEmptyBody`, `walletTopUpTitle`,
`walletTopUpAmountLabel`, `walletTopUpSubmit`, `walletTopUpInvalidAmount`,
`walletPaymentSuccessToast`, `walletPaymentFailedToast`,
`walletPaymentPendingToast`.

## Error handling

- Wallet load failure: standard error state with retry, no special casing.
- Charge failure (`ApiException` from `POST .../charge`): inline error /
  snackbar on the top-up screen; amount and chip selection preserved so the
  rider can retry without re-entering.
- WebView load failure: falls through the existing `_loading` overlay pattern
  from the bus screen (adapted, not shared).

## Testing

- `wallet_dto_mapper` unit tests: empty `data` list → zero-balance wallet;
  string→double parsing for balance/amount; each `type` string → enum branch
  including unknown fallback; `created_at` present/absent/malformed.
- `classifyWalletPaymentNav` unit test in the wallet slice (same cases as the
  bus feature's existing test for its copy: success path, failed path,
  anything else → pending) — small but not free, since it's now a separate
  copy.
- Widget-level smoke test for `WalletScreen` loading/data/empty/error states
  via `walletProvider` overrides, matching existing provider-override test
  patterns in the bus feature.
- Manual verification (per `/verify`): nav bar shows 3 tabs, Profile → Wallet
  navigates for a signed-in user and gates for a guest, top-up opens the
  MyFatoorah page, and a completed/failed/cancelled payment each resolve to the
  right toast and balance.

## Assumptions flagged as unverified

These are inferred, not confirmed against a live backend, and isolated enough
to be cheap to fix once real traffic is observed:

1. Wallet charge redirects use the same `success-payment` / `failed-payment`
   path segments as bus payments (confirmed for bus; assumed here since both
   go through MyFatoorah).
2. The non-`deposit` transaction type string is `"withdraw"` (or similar) —
   only `"deposit"` appears in the documented example response.
