# Wallet Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the Wallet bottom-nav tab and replace it with a real, API-backed wallet reached from the Profile menu — balance + transaction history from `GET /profile/wallet`, top-up via `POST /profile/wallet/:amount/charge` through a wallet-owned payment WebView.

**Architecture:** A standalone `lib/features/wallet/` feature slice (data/domain/presentation), mirroring `lib/features/bus/`'s layering exactly. No shared code is imported from `features/bus` — the payment WebView's redirect classifier and leave-confirmation dialog are small, deliberate duplicates rather than cross-slice imports, per the approved design spec.

**Tech Stack:** Flutter, Riverpod (manual `AsyncNotifier`, no codegen), go_router, Freezed (entities only, no `json_serializable`), Dio, `webview_flutter`.

**Spec:** `docs/superpowers/specs/2026-07-15-wallet-feature-design.md` — read it first; this plan implements it exactly and cross-references it throughout.

**Working branch:** `main`, directly — no worktree/feature branch for this work.

**Verification approach:** Every task ends with `flutter analyze` and/or the relevant `flutter test` run. There is no manual/device verification step in this plan — automated checks only.

---

### Task 1: Wallet domain entities and repository interface

**Files:**
- Create: `lib/features/wallet/domain/entities/wallet.dart`
- Create: `lib/features/wallet/domain/repositories/wallet_repository.dart`

- [ ] **Step 1: Write the domain entities**

```dart
// lib/features/wallet/domain/entities/wallet.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet.freezed.dart';

/// Backend vocabulary beyond `deposit` is inferred, not documented — see
/// `WalletDtoMapper`. Unrecognized values render as [unknown] rather than
/// being guessed into a signed direction, mirroring `BusOrderStatusKind`.
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

- [ ] **Step 2: Write the repository interface**

```dart
// lib/features/wallet/domain/repositories/wallet_repository.dart
abstract interface class WalletRepository {
  /// Fetches the signed-in rider's wallet balance and transaction history.
  Future<Wallet> getWallet();

  /// Starts a top-up charge for a whole-currency-unit [amount] — the amount
  /// is a URL path segment on the backend, so fractional values aren't
  /// accepted (enforced client-side in `WalletTopUpScreen`). Returns the
  /// hosted checkout URL to load in the payment WebView.
  Future<String> charge(int amount);
}
```

This needs one import — add it at the top of the file:

```dart
import 'package:rego/features/wallet/domain/entities/wallet.dart';
```

- [ ] **Step 3: Generate the Freezed code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Completes with `lib/features/wallet/domain/entities/wallet.freezed.dart` created (gitignored — do not edit it).

- [ ] **Step 4: Verify with the analyzer**

Run: `flutter analyze lib/features/wallet`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/wallet/domain
git commit -m "feat(wallet): add domain entities and repository interface"
```

---

### Task 2: WalletDtoMapper (envelope parsing) — TDD

**Files:**
- Create: `test/features/wallet/data/wallet_fixtures.dart`
- Create: `test/features/wallet/data/wallet_dto_mapper_test.dart`
- Create: `lib/features/wallet/data/wallet_dto_mapper.dart`

- [ ] **Step 1: Write the fixtures**

```dart
// test/features/wallet/data/wallet_fixtures.dart
const walletEnvelope = {
  'status': 200,
  'message': 'Wallet',
  'errors': {},
  'data': [
    {
      'id': 79,
      'balance': '25.00',
      'transactions': [
        {
          'id': 86,
          'description': 'تم إضافة 25 جنيه لمحفظتك ترحيبًا بك معنا. ',
          'type': 'deposit',
          'amount': '25.00',
        },
      ],
    },
  ],
};

const walletEmptyDataEnvelope = {
  'status': 200,
  'message': 'Wallet',
  'errors': {},
  'data': <Map<String, dynamic>>[],
};

const walletErrorEnvelope = {
  'status': 401,
  'message': 'Unauthenticated.',
  'errors': {},
  'data': <Map<String, dynamic>>[],
};

const chargeEnvelope = {
  'status': 200,
  'message': 'Payment link',
  'errors': {},
  'data': {
    'link': 'https://demo.MyFatoorah.com/KWT/ia/01072695205842-dee51cf8',
  },
};

const chargeMissingLinkEnvelope = {
  'status': 200,
  'message': 'Payment link',
  'errors': {},
  'data': <String, dynamic>{},
};
```

- [ ] **Step 2: Write the failing tests**

```dart
// test/features/wallet/data/wallet_dto_mapper_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/wallet/data/wallet_dto_mapper.dart';
import 'package:rego/features/wallet/domain/entities/wallet.dart';

import 'wallet_fixtures.dart';

void main() {
  group('WalletDtoMapper.walletFromEnvelope', () {
    test('maps a populated envelope to a wallet with balance and transactions',
        () {
      final wallet = WalletDtoMapper.walletFromEnvelope(walletEnvelope);

      expect(wallet.id, 79);
      expect(wallet.balance, 25.0);
      expect(wallet.currency, 'EGP');
      expect(wallet.transactions, hasLength(1));

      final tx = wallet.transactions.first;
      expect(tx.id, 86);
      expect(tx.description, 'تم إضافة 25 جنيه لمحفظتك ترحيبًا بك معنا. ');
      expect(tx.type, WalletTransactionType.deposit);
      expect(tx.amount, 25.0);
      expect(tx.createdAt, isNull);
    });

    test('an empty data list maps to a zero-balance wallet, not an error', () {
      final wallet =
          WalletDtoMapper.walletFromEnvelope(walletEmptyDataEnvelope);

      expect(wallet.id, 0);
      expect(wallet.balance, 0);
      expect(wallet.transactions, isEmpty);
    });

    test('a non-200 status throws ApiException', () {
      expect(
        () => WalletDtoMapper.walletFromEnvelope(walletErrorEnvelope),
        throwsA(isA<ApiException>()),
      );
    });

    test('transaction type strings map to the right enum value', () {
      WalletTransactionType typeOf(String raw) {
        final wallet = WalletDtoMapper.walletFromEnvelope({
          'status': 200,
          'message': 'Wallet',
          'errors': {},
          'data': [
            {
              'id': 1,
              'balance': '0.00',
              'transactions': [
                {'id': 1, 'description': 'x', 'type': raw, 'amount': '1.00'},
              ],
            },
          ],
        });
        return wallet.transactions.single.type;
      }

      expect(typeOf('deposit'), WalletTransactionType.deposit);
      expect(typeOf('withdraw'), WalletTransactionType.withdraw);
      expect(typeOf('debit'), WalletTransactionType.withdraw);
      expect(typeOf('payment'), WalletTransactionType.withdraw);
      expect(typeOf('something_else'), WalletTransactionType.unknown);
    });

    test('a transaction with no type field maps to unknown', () {
      final wallet = WalletDtoMapper.walletFromEnvelope({
        'status': 200,
        'message': 'Wallet',
        'errors': {},
        'data': [
          {
            'id': 1,
            'balance': '0.00',
            'transactions': [
              {'id': 1, 'description': 'x', 'amount': '1.00'},
            ],
          },
        ],
      });

      expect(wallet.transactions.single.type, WalletTransactionType.unknown);
    });

    test('created_at is parsed when present under created_at or date', () {
      Wallet walletWith(Map<String, dynamic> extra) =>
          WalletDtoMapper.walletFromEnvelope({
            'status': 200,
            'message': 'Wallet',
            'errors': {},
            'data': [
              {
                'id': 1,
                'balance': '0.00',
                'transactions': [
                  {
                    'id': 1,
                    'description': 'x',
                    'type': 'deposit',
                    'amount': '1.00',
                    ...extra,
                  },
                ],
              },
            ],
          });

      final withCreatedAt = walletWith({'created_at': '2026-06-24 19:02:00'});
      expect(
        withCreatedAt.transactions.single.createdAt,
        DateTime.parse('2026-06-24 19:02:00'),
      );

      final withDate = walletWith({'date': '2026-06-24 19:02:00'});
      expect(
        withDate.transactions.single.createdAt,
        DateTime.parse('2026-06-24 19:02:00'),
      );

      final withMalformed = walletWith({'created_at': 'not-a-date'});
      expect(withMalformed.transactions.single.createdAt, isNull);

      final withNeither = walletWith({});
      expect(withNeither.transactions.single.createdAt, isNull);
    });

    test('balance and amount strings parse defensively, defaulting to 0', () {
      final wallet = WalletDtoMapper.walletFromEnvelope({
        'status': 200,
        'message': 'Wallet',
        'errors': {},
        'data': [
          {
            'id': 1,
            'balance': 'not-a-number',
            'transactions': [
              {
                'id': 1,
                'description': 'x',
                'type': 'deposit',
                'amount': 'also-not-a-number',
              },
            ],
          },
        ],
      });

      expect(wallet.balance, 0);
      expect(wallet.transactions.single.amount, 0);
    });
  });

  group('WalletDtoMapper.checkoutUrlFromEnvelope', () {
    test('extracts the checkout link', () {
      final url = WalletDtoMapper.checkoutUrlFromEnvelope(chargeEnvelope);
      expect(
        url,
        'https://demo.MyFatoorah.com/KWT/ia/01072695205842-dee51cf8',
      );
    });

    test('throws when the response has no link', () {
      expect(
        () =>
            WalletDtoMapper.checkoutUrlFromEnvelope(chargeMissingLinkEnvelope),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/features/wallet/data/wallet_dto_mapper_test.dart`
Expected: FAIL — `Error: Target of URI doesn't exist: 'package:rego/features/wallet/data/wallet_dto_mapper.dart'` (the mapper doesn't exist yet).

- [ ] **Step 4: Write the mapper**

```dart
// lib/features/wallet/data/wallet_dto_mapper.dart
import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/wallet/domain/entities/wallet.dart';

/// Envelope → domain mapping for `/profile/wallet` and its charge endpoint.
/// Defensive parsing mirrors `BusDtoMapper`'s `_string`/`_int`/`_double`
/// helpers — the Wadeny API sends money fields as strings and is loose about
/// which fields are present.
abstract final class WalletDtoMapper {
  static Wallet walletFromEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    _ensureSuccess(envelope);

    final data = envelope['data'];
    if (data is! List || data.isEmpty) {
      return const Wallet(
        id: 0,
        balance: 0,
        currency: 'EGP',
        transactions: [],
      );
    }

    return _walletFromJson(data.first as Map<String, dynamic>);
  }

  static String checkoutUrlFromEnvelope(dynamic body) {
    final envelope = body as Map<String, dynamic>;
    _ensureSuccess(envelope);

    final data = envelope['data'];
    final link = data is Map<String, dynamic> ? _string(data['link']) : null;
    if (link == null || link.isEmpty) {
      throw const ApiException('No payment link returned', statusCode: 200);
    }
    return link;
  }

  static void _ensureSuccess(Map<String, dynamic> envelope) {
    final innerStatus = envelope['status'];
    if (innerStatus is num && innerStatus.toInt() != 200) {
      throw ApiException.fromEnvelope(envelope);
    }
  }

  static Wallet _walletFromJson(Map<String, dynamic> json) {
    final rawTransactions = json['transactions'];
    return Wallet(
      id: _int(json['id']) ?? 0,
      balance: _double(json['balance']) ?? 0,
      currency: _string(json['currency']) ?? 'EGP',
      transactions: rawTransactions is List
          ? rawTransactions
              .whereType<Map<String, dynamic>>()
              .map(_transactionFromJson)
              .toList()
          : const [],
    );
  }

  static WalletTransaction _transactionFromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: _int(json['id']) ?? 0,
      description: _string(json['description']) ?? '',
      type: _typeFromString(_string(json['type'])),
      amount: _double(json['amount']) ?? 0,
      createdAt: _dateTime(json['created_at']) ?? _dateTime(json['date']),
    );
  }

  static WalletTransactionType _typeFromString(String? raw) {
    switch (raw) {
      case 'deposit':
        return WalletTransactionType.deposit;
      case 'withdraw':
      case 'debit':
      case 'payment':
        return WalletTransactionType.withdraw;
      default:
        return WalletTransactionType.unknown;
    }
  }

  static String? _string(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static int? _int(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _double(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _dateTime(dynamic value) {
    final str = _string(value);
    if (str == null || str.isEmpty) return null;
    return DateTime.tryParse(str);
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/wallet/data/wallet_dto_mapper_test.dart`
Expected: All tests PASS (10 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/wallet/data/wallet_dto_mapper.dart test/features/wallet/data
git commit -m "feat(wallet): add WalletDtoMapper with defensive envelope parsing"
```

---

### Task 3: WalletApi and WalletRepositoryImpl

**Files:**
- Create: `lib/features/wallet/data/wallet_api.dart`
- Create: `lib/features/wallet/data/wallet_repository_impl.dart`

No dedicated test for this task — matches the existing precedent: `BusApi` and `BusRepositoryImpl` have no direct unit tests either (the mapper's tests cover the parsing logic; the repository's own logic is just Dio-call + guard + mapper-call, exercised indirectly through provider tests in Task 4).

- [ ] **Step 1: Write the API client**

```dart
// lib/features/wallet/data/wallet_api.dart
import 'package:dio/dio.dart';

/// Transport layer over `/profile/wallet*`. Returns raw decoded JSON bodies.
class WalletApi {
  WalletApi(this._dio);

  final Dio _dio;

  Future<dynamic> getWallet() async {
    final res = await _dio.get('/profile/wallet');
    return res.data;
  }

  /// [amount] must be a positive whole number — it's placed directly in the
  /// URL path by the backend contract.
  Future<dynamic> charge(int amount) async {
    final res = await _dio.post('/profile/wallet/$amount/charge');
    return res.data;
  }
}
```

- [ ] **Step 2: Write the repository implementation**

```dart
// lib/features/wallet/data/wallet_repository_impl.dart
import 'package:dio/dio.dart';

import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/wallet/data/wallet_api.dart';
import 'package:rego/features/wallet/data/wallet_dto_mapper.dart';
import 'package:rego/features/wallet/domain/entities/wallet.dart';
import 'package:rego/features/wallet/domain/repositories/wallet_repository.dart';

class WalletRepositoryImpl implements WalletRepository {
  WalletRepositoryImpl(this._api);

  final WalletApi _api;

  @override
  Future<Wallet> getWallet() {
    return _guard(() async {
      final body = await _api.getWallet();
      return WalletDtoMapper.walletFromEnvelope(body);
    });
  }

  @override
  Future<String> charge(int amount) {
    return _guard(() async {
      final body = await _api.charge(amount);
      return WalletDtoMapper.checkoutUrlFromEnvelope(body);
    });
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
```

- [ ] **Step 3: Verify with the analyzer**

Run: `flutter analyze lib/features/wallet`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/wallet/data/wallet_api.dart lib/features/wallet/data/wallet_repository_impl.dart
git commit -m "feat(wallet): add WalletApi and WalletRepositoryImpl"
```

---

### Task 4: Wallet providers — TDD

**Files:**
- Create: `test/features/wallet/fake_wallet_repository.dart`
- Create: `test/features/wallet/presentation/wallet_notifier_test.dart`
- Create: `lib/features/wallet/presentation/providers/wallet_providers.dart`

- [ ] **Step 1: Write the fake repository test double**

```dart
// test/features/wallet/fake_wallet_repository.dart
import 'package:rego/core/network/api_exception.dart';
import 'package:rego/features/wallet/domain/entities/wallet.dart';
import 'package:rego/features/wallet/domain/repositories/wallet_repository.dart';

/// In-memory repository for widget/notifier tests.
class FakeWalletRepository implements WalletRepository {
  FakeWalletRepository({this.walletResult});

  Wallet? walletResult;
  bool getWalletShouldThrow = false;
  int getWalletCallCount = 0;

  List<int> chargeCalls = [];
  String chargeResult = 'https://demo.MyFatoorah.com/pay';
  bool chargeShouldThrow = false;

  static const sampleWallet = Wallet(
    id: 79,
    balance: 25.0,
    currency: 'EGP',
    transactions: [
      WalletTransaction(
        id: 86,
        description: 'Welcome bonus',
        type: WalletTransactionType.deposit,
        amount: 25.0,
      ),
    ],
  );

  @override
  Future<Wallet> getWallet() async {
    getWalletCallCount++;
    if (getWalletShouldThrow) {
      throw const ApiException('Failed to load wallet', statusCode: 500);
    }
    return walletResult ?? sampleWallet;
  }

  @override
  Future<String> charge(int amount) async {
    chargeCalls.add(amount);
    if (chargeShouldThrow) {
      throw const ApiException('Charge failed', statusCode: 422);
    }
    return chargeResult;
  }
}
```

- [ ] **Step 2: Write the failing notifier tests**

```dart
// test/features/wallet/presentation/wallet_notifier_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/wallet/domain/entities/wallet.dart';
import 'package:rego/features/wallet/presentation/providers/wallet_providers.dart';

import '../fake_wallet_repository.dart';

void main() {
  ProviderContainer makeContainer(FakeWalletRepository repo) {
    final container = ProviderContainer(
      overrides: [walletRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('WalletNotifier', () {
    test('build loads the wallet from the repository', () async {
      final repo = FakeWalletRepository();
      final container = makeContainer(repo);

      final wallet = await container.read(walletProvider.future);

      expect(wallet.id, 79);
      expect(wallet.balance, 25.0);
      expect(repo.getWalletCallCount, 1);
    });

    test('refresh re-fetches and replaces the wallet', () async {
      final repo = FakeWalletRepository();
      final container = makeContainer(repo);
      await container.read(walletProvider.future);

      repo.walletResult = const Wallet(
        id: 79,
        balance: 225.0,
        currency: 'EGP',
        transactions: [],
      );
      await container.read(walletProvider.notifier).refresh();

      final wallet = container.read(walletProvider).value;
      expect(wallet, isNotNull);
      expect(wallet!.balance, 225.0);
    });

    test('a load failure surfaces as an AsyncError', () async {
      final repo = FakeWalletRepository()..getWalletShouldThrow = true;
      final container = makeContainer(repo);

      await expectLater(
        container.read(walletProvider.future),
        throwsA(isA<Exception>()),
      );
      expect(container.read(walletProvider).hasError, isTrue);
    });
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/features/wallet/presentation/wallet_notifier_test.dart`
Expected: FAIL — `Error: Target of URI doesn't exist: 'package:rego/features/wallet/presentation/providers/wallet_providers.dart'`.

- [ ] **Step 4: Write the providers**

```dart
// lib/features/wallet/presentation/providers/wallet_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/core/network/dio_client.dart';
import 'package:rego/features/wallet/data/wallet_api.dart';
import 'package:rego/features/wallet/data/wallet_repository_impl.dart';
import 'package:rego/features/wallet/domain/entities/wallet.dart';
import 'package:rego/features/wallet/domain/repositories/wallet_repository.dart';

final walletApiProvider =
    Provider<WalletApi>((ref) => WalletApi(ref.watch(dioProvider)));

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => WalletRepositoryImpl(ref.watch(walletApiProvider)),
);

/// Owns the signed-in rider's wallet (balance + transactions). Plain
/// (non-autoDispose) `AsyncNotifier`, matching `busOrdersProvider` — state
/// survives switching bottom-nav tabs and navigating to/from the wallet.
class WalletNotifier extends AsyncNotifier<Wallet> {
  @override
  Future<Wallet> build() {
    return ref.read(walletRepositoryProvider).getWallet();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(walletRepositoryProvider).getWallet(),
    );
  }
}

final walletProvider =
    AsyncNotifierProvider<WalletNotifier, Wallet>(WalletNotifier.new);
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/wallet/presentation/wallet_notifier_test.dart`
Expected: All 3 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/wallet/presentation/providers test/features/wallet/fake_wallet_repository.dart test/features/wallet/presentation/wallet_notifier_test.dart
git commit -m "feat(wallet): add WalletNotifier and wallet providers"
```

---

### Task 5: Localization keys

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ar.arb`

- [ ] **Step 1: Add the English keys**

In `lib/l10n/app_en.arb`, find this existing block near the end of the file:

```json
  "profileComingSoon": "Coming soon",
  "@profileComingSoon": {
    "description": "Snackbar shown when a profile menu row is not yet implemented."
  },

  "pressBackAgainToExit": "Press back again to exit",
```

Replace it with:

```json
  "profileComingSoon": "Coming soon",
  "@profileComingSoon": {
    "description": "Snackbar shown when a profile menu row is not yet implemented."
  },

  "walletTitle": "My Wallet",
  "walletBalanceLabel": "Available balance",
  "walletTopUpCta": "Top up",
  "walletHistoryTitle": "Recent activity",
  "walletEmptyTitle": "No activity yet",
  "walletEmptyBody": "Your wallet transactions will show up here.",
  "walletError": "Couldn't load your wallet",
  "walletTopUpTitle": "Top up wallet",
  "walletTopUpAmountLabel": "Enter amount",
  "walletTopUpSubmit": "Top up {amount} EGP",
  "@walletTopUpSubmit": {
    "description": "Submit button on the wallet top-up screen, e.g. \"Top up 200 EGP\".",
    "placeholders": {
      "amount": {
        "type": "int"
      }
    }
  },
  "walletTopUpInvalidAmount": "Enter an amount greater than zero",
  "walletPaymentSuccessToast": "Wallet topped up successfully",
  "walletPaymentFailedToast": "Payment failed. Please try again",
  "walletPaymentPendingToast": "We couldn't confirm the payment yet. It may take a moment",

  "pressBackAgainToExit": "Press back again to exit",
```

- [ ] **Step 2: Add the Arabic keys**

In `lib/l10n/app_ar.arb`, find this existing line near the end of the file:

```json
  "profileComingSoon": "قريباً",

  "pressBackAgainToExit": "اضغط رجوع مرة أخرى للخروج"
```

Replace it with:

```json
  "profileComingSoon": "قريباً",

  "walletTitle": "محفظتي",
  "walletBalanceLabel": "الرصيد المتاح",
  "walletTopUpCta": "شحن الرصيد",
  "walletHistoryTitle": "آخر العمليات",
  "walletEmptyTitle": "لا توجد عمليات بعد",
  "walletEmptyBody": "ستظهر عمليات محفظتك هنا.",
  "walletError": "تعذر تحميل المحفظة",
  "walletTopUpTitle": "شحن المحفظة",
  "walletTopUpAmountLabel": "أدخل المبلغ",
  "walletTopUpSubmit": "شحن {amount} جنيه",
  "walletTopUpInvalidAmount": "أدخل مبلغاً أكبر من صفر",
  "walletPaymentSuccessToast": "تم شحن المحفظة بنجاح",
  "walletPaymentFailedToast": "فشلت عملية الدفع، حاول مرة أخرى",
  "walletPaymentPendingToast": "لم نتمكن من تأكيد الدفع بعد، قد يستغرق الأمر بعض الوقت",

  "pressBackAgainToExit": "اضغط رجوع مرة أخرى للخروج"
```

- [ ] **Step 3: Regenerate the localization Dart files**

Run: `flutter gen-l10n`
Expected: Completes with no errors; `lib/l10n/app_localizations*.dart` regenerated (gitignored).

Do **not** run a bare `flutter pub get` for this — see the Android build note in `CLAUDE.md`. `flutter gen-l10n` alone is sufficient and doesn't touch the pub cache.

- [ ] **Step 4: Verify with the analyzer**

Run: `flutter analyze`
Expected: `No issues found!` (confirms both arb files parsed and every new key generated a valid getter).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_ar.arb
git commit -m "feat(wallet): add wallet localization strings"
```

---

### Task 6: WalletAppBar and wallet icons

**Files:**
- Modify: `lib/core/theme/app_icons.dart`
- Create: `lib/features/wallet/presentation/widgets/wallet_app_bar.dart`

`BookingAppBar` (the bus feature's pushed-screen app bar) is only ever imported from within `features/bus/presentation/` — it's bus-owned infrastructure, not a shared widget. Wallet gets its own small equivalent instead of importing across the slice boundary, per the design spec.

- [ ] **Step 1: Add two icon entries**

In `lib/core/theme/app_icons.dart`, find:

```dart
  // ── Misc ─────────────────────────────────────────────────────────────────
  static const IconData wallet = TablerIcons.wallet;
  static const IconData ticket = TablerIcons.ticket;
  static const IconData search = TablerIcons.search;
```

Replace it with:

```dart
  // ── Misc ─────────────────────────────────────────────────────────────────
  static const IconData wallet = TablerIcons.wallet;
  static const IconData walletDeposit = TablerIcons.arrowDownLeft;
  static const IconData walletWithdraw = TablerIcons.arrowUpRight;
  static const IconData ticket = TablerIcons.ticket;
  static const IconData search = TablerIcons.search;
```

- [ ] **Step 2: Verify the icon names exist in the package**

Run: `flutter analyze lib/core/theme/app_icons.dart`
Expected: `No issues found!` If this fails with an undefined-getter error, open the installed `tabler_icons_plus` package's icon list and swap in the closest correctly-named arrow glyphs (the intent is a down-left arrow for money in, an up-right arrow for money out) — this is a mechanical name lookup, not a design change.

- [ ] **Step 3: Write the wallet app bar**

```dart
// lib/features/wallet/presentation/widgets/wallet_app_bar.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';

/// Wallet-owned pushed-screen app bar: title, back arrow, optional trailing
/// action. Shape mirrors the bus feature's `BookingAppBar`, but wallet keeps
/// its own copy rather than importing across the feature-slice boundary —
/// see the wallet design spec's "Screen chrome" section.
class WalletAppBar extends StatelessWidget implements PreferredSizeWidget {
  const WalletAppBar({
    super.key,
    required this.title,
    this.action,
    this.onBack,
  });

  final String title;
  final Widget? action;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgElevated,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    AppTypography.title.copyWith(fontWeight: FontWeight.w700),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.xs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Transform.flip(
                        flipX:
                            Directionality.of(context) == TextDirection.rtl,
                        child: const Icon(
                          AppIcons.back,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      onPressed: onBack ?? () => context.pop(),
                    ),
                    const Spacer(),
                    if (action != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          top: AppSpacing.xs,
                          end: AppSpacing.xs,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: action!,
                        ),
                      )
                    else
                      const SizedBox(width: kMinInteractiveDimension),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Verify with the analyzer**

Run: `flutter analyze lib/features/wallet lib/core/theme/app_icons.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_icons.dart lib/features/wallet/presentation/widgets/wallet_app_bar.dart
git commit -m "feat(wallet): add WalletAppBar and wallet transaction icons"
```

---

### Task 7: WalletBalanceCard and WalletTransactionTile

**Files:**
- Create: `lib/features/wallet/presentation/widgets/wallet_balance_card.dart`
- Create: `lib/features/wallet/presentation/widgets/wallet_transaction_tile.dart`

These are small presentational widgets, exercised through `WalletScreen`'s own widget test in Task 8 rather than in isolation — matching how the bus feature's small presentational helpers (`operator_mark.dart`, `order_status_badge.dart`) have no dedicated test files of their own.

- [ ] **Step 1: Write the balance card**

```dart
// lib/features/wallet/presentation/widgets/wallet_balance_card.dart
import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

/// Balance display + "Top up" call to action at the top of the wallet screen.
class WalletBalanceCard extends StatelessWidget {
  const WalletBalanceCard({
    super.key,
    required this.balance,
    required this.currency,
    required this.onTopUp,
  });

  final double balance;
  final String currency;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.20),
            blurRadius: 40,
            spreadRadius: -18,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.walletBalanceLabel,
            style:
                AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${balance.toStringAsFixed(2)} $currency',
            style:
                AppTypography.display.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(label: l10n.walletTopUpCta, onPressed: onTopUp),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Write the transaction tile**

```dart
// lib/features/wallet/presentation/widgets/wallet_transaction_tile.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/wallet/domain/entities/wallet.dart';

/// One row in the wallet's transaction history: icon by type, description,
/// signed amount, and date when the backend sent one.
class WalletTransactionTile extends StatelessWidget {
  const WalletTransactionTile({super.key, required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isDeposit = transaction.type == WalletTransactionType.deposit;
    final isWithdraw = transaction.type == WalletTransactionType.withdraw;
    final amountColor = isDeposit
        ? AppColors.success
        : isWithdraw
            ? AppColors.error
            : AppColors.textPrimary;
    final sign = isDeposit ? '+' : (isWithdraw ? '−' : '');
    final createdAt = transaction.createdAt;
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDeposit
                  ? AppColors.success.withValues(alpha: 0.12)
                  : isWithdraw
                      ? AppColors.error.withValues(alpha: 0.12)
                      : AppColors.primaryTint,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              isDeposit
                  ? AppIcons.walletDeposit
                  : isWithdraw
                      ? AppIcons.walletWithdraw
                      : AppIcons.wallet,
              size: 20,
              color: isDeposit
                  ? AppColors.success
                  : isWithdraw
                      ? AppColors.error
                      : AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.title.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d MMM, HH:mm', locale).format(createdAt),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$sign${transaction.amount.toStringAsFixed(2)}',
            style: AppTypography.title.copyWith(
              fontWeight: FontWeight.w800,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Verify with the analyzer**

Run: `flutter analyze lib/features/wallet`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/wallet/presentation/widgets/wallet_balance_card.dart lib/features/wallet/presentation/widgets/wallet_transaction_tile.dart
git commit -m "feat(wallet): add WalletBalanceCard and WalletTransactionTile"
```

---

### Task 8: WalletScreen — TDD

**Files:**
- Create: `lib/features/wallet/presentation/wallet_routes.dart` (routes constants only for now — full route wiring lands in Task 11; this file is needed now so the screen and its test can reference `WalletRoutes.topUp`)
- Create: `lib/features/wallet/presentation/wallet_screen.dart`
- Create: `test/features/wallet/presentation/wallet_screen_test.dart`

- [ ] **Step 1: Write the route constants**

```dart
// lib/features/wallet/presentation/wallet_routes.dart
abstract final class WalletRoutes {
  static const wallet = '/profile/wallet';
  static const topUp = '/profile/wallet/top-up';
  static const pay = '/profile/wallet/pay';
}
```

- [ ] **Step 2: Write the failing widget tests**

```dart
// test/features/wallet/presentation/wallet_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/features/wallet/domain/entities/wallet.dart';
import 'package:rego/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:rego/features/wallet/presentation/wallet_routes.dart';
import 'package:rego/features/wallet/presentation/wallet_screen.dart';
import 'package:rego/l10n/app_localizations.dart';

import '../fake_wallet_repository.dart';

void main() {
  Future<void> pumpWallet(
    WidgetTester tester,
    FakeWalletRepository repo,
  ) async {
    final container = ProviderContainer(
      overrides: [walletRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: WalletRoutes.wallet,
      routes: [
        GoRoute(
          path: WalletRoutes.wallet,
          builder: (context, state) => const WalletScreen(),
        ),
        GoRoute(
          path: WalletRoutes.topUp,
          builder: (context, state) => const Text('TOPUP'),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the balance and transaction list', (tester) async {
    await pumpWallet(tester, FakeWalletRepository());

    expect(find.text('25.00 EGP'), findsOneWidget);
    expect(find.text('Welcome bonus'), findsOneWidget);
    expect(find.text('+25.00'), findsOneWidget);
  });

  testWidgets('tapping Top up navigates to the top-up screen', (tester) async {
    await pumpWallet(tester, FakeWalletRepository());

    await tester.tap(find.text('Top up'));
    await tester.pumpAndSettle();

    expect(find.text('TOPUP'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no transactions',
      (tester) async {
    final repo = FakeWalletRepository(
      walletResult: const Wallet(
        id: 1,
        balance: 0,
        currency: 'EGP',
        transactions: [],
      ),
    );
    await pumpWallet(tester, repo);

    expect(find.text('No activity yet'), findsOneWidget);
  });

  testWidgets('shows an error state with retry on load failure',
      (tester) async {
    final repo = FakeWalletRepository()..getWalletShouldThrow = true;
    await pumpWallet(tester, repo);

    expect(find.text("Couldn't load your wallet"), findsOneWidget);

    repo.getWalletShouldThrow = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('25.00 EGP'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/features/wallet/presentation/wallet_screen_test.dart`
Expected: FAIL — `Error: Target of URI doesn't exist: 'package:rego/features/wallet/presentation/wallet_screen.dart'`.

- [ ] **Step 4: Write the wallet screen**

```dart
// lib/features/wallet/presentation/wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:rego/features/wallet/presentation/wallet_routes.dart';
import 'package:rego/features/wallet/presentation/widgets/wallet_app_bar.dart';
import 'package:rego/features/wallet/presentation/widgets/wallet_balance_card.dart';
import 'package:rego/features/wallet/presentation/widgets/wallet_transaction_tile.dart';
import 'package:rego/l10n/app_localizations.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: WalletAppBar(title: l10n.walletTitle),
      body: RefreshIndicator(
        onRefresh: () => ref.read(walletProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: walletAsync.when(
            loading: () => const [
              SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, _) => [
              _WalletErrorState(onRetry: () => ref.invalidate(walletProvider)),
            ],
            data: (wallet) => [
              WalletBalanceCard(
                balance: wallet.balance,
                currency: wallet.currency,
                onTopUp: () => context.push(WalletRoutes.topUp),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.walletHistoryTitle, style: AppTypography.h2),
              const SizedBox(height: AppSpacing.sm),
              if (wallet.transactions.isEmpty)
                _WalletEmptyState(l10n: l10n)
              else
                for (final tx in wallet.transactions)
                  WalletTransactionTile(transaction: tx),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletEmptyState extends StatelessWidget {
  const _WalletEmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          const Icon(AppIcons.wallet, size: 40, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.walletEmptyTitle,
            style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.walletEmptyBody,
            textAlign: TextAlign.center,
            style:
                AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _WalletErrorState extends StatelessWidget {
  const _WalletErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          const Icon(AppIcons.error, size: 40, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.walletError,
            textAlign: TextAlign.center,
            style:
                AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            child: Text(l10n.tripResultsRetry),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/wallet/presentation/wallet_screen_test.dart`
Expected: All 4 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/wallet/presentation/wallet_routes.dart lib/features/wallet/presentation/wallet_screen.dart test/features/wallet/presentation/wallet_screen_test.dart
git commit -m "feat(wallet): add WalletScreen with balance, history, and empty/error states"
```

---

### Task 9: WalletTopUpScreen — TDD

**Files:**
- Create: `lib/features/wallet/presentation/wallet_topup_screen.dart`
- Create: `test/features/wallet/presentation/wallet_topup_screen_test.dart`

- [ ] **Step 1: Write the failing widget tests**

```dart
// test/features/wallet/presentation/wallet_topup_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:rego/features/wallet/presentation/wallet_routes.dart';
import 'package:rego/features/wallet/presentation/wallet_topup_screen.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

import '../fake_wallet_repository.dart';

void main() {
  Future<void> pumpTopUp(
    WidgetTester tester,
    FakeWalletRepository repo,
  ) async {
    final container = ProviderContainer(
      overrides: [walletRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: WalletRoutes.topUp,
      routes: [
        GoRoute(
          path: WalletRoutes.topUp,
          builder: (context, state) => const WalletTopUpScreen(),
        ),
        GoRoute(
          path: WalletRoutes.pay,
          builder: (context, state) => const Text('PAY'),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('submit is disabled until an amount is entered', (tester) async {
    await pumpTopUp(tester, FakeWalletRepository());

    final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('tapping a quick-pick chip fills the amount and enables submit',
      (tester) async {
    await pumpTopUp(tester, FakeWalletRepository());

    await tester.tap(find.text('200 EGP'));
    await tester.pumpAndSettle();

    final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(button.onPressed, isNotNull);
    expect(find.text('Top up 200 EGP'), findsOneWidget);
  });

  testWidgets('submitting charges the repository and pushes the pay route',
      (tester) async {
    final repo = FakeWalletRepository()
      ..chargeResult = 'https://demo.MyFatoorah.com/pay/xyz';
    await pumpTopUp(tester, repo);

    await tester.tap(find.text('200 EGP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top up 200 EGP'));
    await tester.pumpAndSettle();

    expect(repo.chargeCalls, [200]);
    expect(find.text('PAY'), findsOneWidget);
  });

  testWidgets('a charge failure shows an inline error and keeps the amount',
      (tester) async {
    final repo = FakeWalletRepository()..chargeShouldThrow = true;
    await pumpTopUp(tester, repo);

    await tester.tap(find.text('200 EGP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top up 200 EGP'));
    await tester.pumpAndSettle();

    expect(find.text('Charge failed'), findsOneWidget);
    expect(find.text('Top up 200 EGP'), findsOneWidget);
  });

  testWidgets('only digits can be typed into the amount field',
      (tester) async {
    await pumpTopUp(tester, FakeWalletRepository());

    await tester.enterText(find.byType(TextField), 'abc123.45xyz');
    await tester.pumpAndSettle();

    expect(find.text('Top up 123 EGP'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/wallet/presentation/wallet_topup_screen_test.dart`
Expected: FAIL — `Error: Target of URI doesn't exist: 'package:rego/features/wallet/presentation/wallet_topup_screen.dart'`.

- [ ] **Step 3: Write the top-up screen**

```dart
// lib/features/wallet/presentation/wallet_topup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/network/api_exception.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:rego/features/wallet/presentation/wallet_routes.dart';
import 'package:rego/features/wallet/presentation/widgets/wallet_app_bar.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class WalletTopUpScreen extends ConsumerStatefulWidget {
  const WalletTopUpScreen({super.key});

  @override
  ConsumerState<WalletTopUpScreen> createState() => _WalletTopUpScreenState();
}

class _WalletTopUpScreenState extends ConsumerState<WalletTopUpScreen> {
  static const _quickAmounts = [50, 100, 200, 500];

  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _amount => int.tryParse(_controller.text) ?? 0;

  Future<void> _submit() async {
    final amount = _amount;
    if (amount <= 0 || _submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final url = await ref.read(walletRepositoryProvider).charge(amount);
      if (!mounted) return;
      context.push(WalletRoutes.pay, extra: url);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final amount = _amount;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: WalletAppBar(title: l10n.walletTopUpTitle),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.walletTopUpAmountLabel,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTypography.h1,
                decoration: InputDecoration(
                  suffixText: 'EGP',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final quick in _quickAmounts)
                    ChoiceChip(
                      label: Text('$quick EGP'),
                      selected: amount == quick,
                      onSelected: (_) {
                        _controller.text = '$quick';
                        setState(() {});
                      },
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: AppTypography.body.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: amount > 0
                    ? l10n.walletTopUpSubmit(amount)
                    : l10n.walletTopUpInvalidAmount,
                loading: _submitting,
                onPressed: amount > 0 ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/wallet/presentation/wallet_topup_screen_test.dart`
Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/wallet/presentation/wallet_topup_screen.dart test/features/wallet/presentation/wallet_topup_screen_test.dart
git commit -m "feat(wallet): add WalletTopUpScreen with amount entry and quick-pick chips"
```

---

### Task 10: WalletPaymentWebViewScreen — TDD

**Files:**
- Create: `lib/features/wallet/presentation/wallet_payment_webview_screen.dart`
- Create: `test/features/wallet/presentation/wallet_payment_nav_classify_test.dart`
- Create: `test/features/wallet/presentation/wallet_leave_payment_dialog_test.dart`

The redirect classifier and the leave-confirmation dialog are deliberate, small duplicates of the bus feature's equivalents (not imports) — see the design spec's "Payment WebView (wallet-owned)" section for why. Both are named distinctly (`WalletPaymentNavResult`/`classifyWalletPaymentNav`/`confirmLeaveWalletPayment`) so they're never confused with the bus originals, and both stay public (not underscore-prefixed) so this task's tests — in a separate file — can call them: Dart privacy is per-file, so a private top-level function could never be unit-tested from outside its own file.

- [ ] **Step 1: Write the failing classifier test**

```dart
// test/features/wallet/presentation/wallet_payment_nav_classify_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/wallet/presentation/wallet_payment_webview_screen.dart';

void main() {
  WalletPaymentNavResult classify(String url) =>
      classifyWalletPaymentNav(Uri.parse(url));

  test('the success redirect is classified as success, regardless of locale',
      () {
    expect(
      classify('https://wdenytravel.com/ar/success-payment'),
      WalletPaymentNavResult.success,
    );
    expect(
      classify('https://wdenytravel.com/en/success-payment'),
      WalletPaymentNavResult.success,
    );
  });

  test('the failure redirect is classified as failure', () {
    expect(
      classify('https://wdenytravel.com/ar/failed-payment'),
      WalletPaymentNavResult.failure,
    );
  });

  test('the gateway hosted-checkout page is still pending', () {
    expect(
      classify('https://demo.MyFatoorah.com/KWT/ia/01072695205842-dee51cf8'),
      WalletPaymentNavResult.pending,
    );
  });

  test('unrelated and blank navigations are pending', () {
    expect(classify('https://google.com'), WalletPaymentNavResult.pending);
    expect(classify('about:blank'), WalletPaymentNavResult.pending);
  });
}
```

- [ ] **Step 2: Write the failing leave-dialog test**

```dart
// test/features/wallet/presentation/wallet_leave_payment_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rego/features/wallet/presentation/wallet_payment_webview_screen.dart';
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
          final leave = await confirmLeaveWalletPayment(context);
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
}
```

- [ ] **Step 3: Run both test files to verify they fail**

Run: `flutter test test/features/wallet/presentation/wallet_payment_nav_classify_test.dart test/features/wallet/presentation/wallet_leave_payment_dialog_test.dart`
Expected: FAIL — `Error: Target of URI doesn't exist: 'package:rego/features/wallet/presentation/wallet_payment_webview_screen.dart'`.

- [ ] **Step 4: Write the payment WebView screen**

```dart
// lib/features/wallet/presentation/wallet_payment_webview_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:rego/features/wallet/presentation/widgets/wallet_app_bar.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

/// Terminal outcome signalled by a wallet top-up WebView navigation — same
/// `success-payment`/`failed-payment` redirect targets as the bus payment
/// flow (both go through the MyFatoorah gateway). Copied rather than shared
/// with the bus feature; see the wallet design spec.
enum WalletPaymentNavResult { success, failure, pending }

/// Pure classifier for a wallet payment WebView navigation [uri].
WalletPaymentNavResult classifyWalletPaymentNav(Uri uri) {
  final path = uri.path.toLowerCase();
  if (path.contains('success-payment')) return WalletPaymentNavResult.success;
  if (path.contains('failed-payment')) return WalletPaymentNavResult.failure;
  return WalletPaymentNavResult.pending;
}

/// Shows the "leave payment?" confirmation when the rider tries to back out
/// of the top-up checkout before it's resolved. Returns true only if they
/// explicitly chose to leave.
Future<bool> confirmLeaveWalletPayment(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.45),
    builder: (dialogContext) => const _WalletLeavePaymentDialog(),
  );
  return leave ?? false;
}

class _WalletLeavePaymentDialog extends StatelessWidget {
  const _WalletLeavePaymentDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final maxWidth = MediaQuery.sizeOf(context).width * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.secondaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    AppIcons.wallet,
                    color: AppColors.secondary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.paymentLeaveTitle,
                  textAlign: TextAlign.center,
                  style:
                      AppTypography.h2.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.paymentLeaveBody,
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: l10n.paymentLeaveStay,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(height: AppSpacing.sm),
                PrimaryButton(
                  label: l10n.paymentLeaveConfirm,
                  variant: PrimaryButtonVariant.ghost,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _WalletTopUpOutcome { success, failed, pending }

/// Loads the top-up checkout in a WebView. There is no charge-status
/// endpoint, so a terminal redirect (or the rider tapping "Done") triggers a
/// wallet refresh and compares the new balance to the one captured on entry —
/// see the design spec's "Payment WebView" verification table.
class WalletPaymentWebViewScreen extends ConsumerStatefulWidget {
  const WalletPaymentWebViewScreen({super.key, required this.checkoutUrl});

  final String checkoutUrl;

  @override
  ConsumerState<WalletPaymentWebViewScreen> createState() =>
      _WalletPaymentWebViewScreenState();
}

class _WalletPaymentWebViewScreenState
    extends ConsumerState<WalletPaymentWebViewScreen> {
  WebViewController? _controller;
  bool _loading = true;
  bool _verifyTriggered = false;
  bool _leavePromptOpen = false;
  bool _verifying = false;
  double? _balanceBefore;

  @override
  void initState() {
    super.initState();
    _balanceBefore = ref.read(walletProvider).value?.balance;
    unawaited(_init());
  }

  Future<void> _init() async {
    final uri = Uri.parse(widget.checkoutUrl);

    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onNavigationRequest: (request) => _handleNavigation(request.url),
        onUrlChange: (change) {
          final url = change.url;
          if (url != null) _handleNavigation(url);
        },
      ),
    );
    await controller.loadRequest(uri);

    if (mounted) setState(() => _controller = controller);
  }

  NavigationDecision _handleNavigation(String url) {
    final uri = Uri.tryParse(url);
    final result = uri == null
        ? WalletPaymentNavResult.pending
        : classifyWalletPaymentNav(uri);
    if (result == WalletPaymentNavResult.pending) {
      return NavigationDecision.navigate;
    }
    unawaited(_verify(result));
    return NavigationDecision.prevent;
  }

  Future<void> _verify([WalletPaymentNavResult? redirectResult]) async {
    if (_verifyTriggered) return;
    _verifyTriggered = true;

    if (mounted) setState(() => _verifying = true);

    var outcome = _WalletTopUpOutcome.pending;
    if (redirectResult == WalletPaymentNavResult.failure) {
      outcome = _WalletTopUpOutcome.failed;
    } else {
      try {
        final before = _balanceBefore;
        await ref.read(walletProvider.notifier).refresh();
        final after = ref.read(walletProvider).value?.balance;
        if (before != null && after != null && after > before) {
          outcome = _WalletTopUpOutcome.success;
        }
      } catch (_) {
        // Refresh failure leaves `outcome` as pending — the balance is
        // simply unconfirmed, not a payment failure.
      }
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _verifying = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            switch (outcome) {
              _WalletTopUpOutcome.success => l10n.walletPaymentSuccessToast,
              _WalletTopUpOutcome.failed => l10n.walletPaymentFailedToast,
              _WalletTopUpOutcome.pending => l10n.walletPaymentPendingToast,
            },
          ),
        ),
      );
    if (context.mounted) context.pop();
  }

  Future<void> _handleBackRequest() async {
    if (_leavePromptOpen) return;
    _leavePromptOpen = true;
    final leave = await confirmLeaveWalletPayment(context);
    _leavePromptOpen = false;
    if (leave) {
      unawaited(_verify());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = _controller;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_handleBackRequest());
      },
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: WalletAppBar(
          title: l10n.paymentTitle,
          onBack: () => unawaited(_handleBackRequest()),
          action: TextButton(
            onPressed: _verifying ? null : () => unawaited(_verify()),
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
            if (controller == null || _loading || _verifying)
              ColoredBox(
                color: AppColors.bgBase.withValues(alpha: 0.72),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      if (_verifying) ...[
                        const SizedBox(height: 16),
                        Text(
                          l10n.paymentVerifying,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
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

- [ ] **Step 5: Run both test files to verify they pass**

Run: `flutter test test/features/wallet/presentation/wallet_payment_nav_classify_test.dart test/features/wallet/presentation/wallet_leave_payment_dialog_test.dart`
Expected: All 7 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/wallet/presentation/wallet_payment_webview_screen.dart test/features/wallet/presentation/wallet_payment_nav_classify_test.dart test/features/wallet/presentation/wallet_leave_payment_dialog_test.dart
git commit -m "feat(wallet): add WalletPaymentWebViewScreen with balance-diff verification"
```

---

### Task 11: Cutover — wire navigation, remove the old tab, fix broken tests

This is the one task that must land as a single commit: removing the wallet bottom-nav destination and the old `ComingSoonScreen` branch simultaneously breaks three existing test files, so the tree is only green again once every file below is updated together.

**Files:**
- Delete: `lib/features/shell/presentation/coming_soon_screen.dart` (becomes fully unused in production code once the wallet branch is removed — verified no other `lib/` file references it)
- Modify: `lib/features/wallet/presentation/wallet_routes.dart` (add the actual route list, `walletRoutes()`)
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/shell/presentation/widgets/main_nav_bar.dart`
- Modify: `lib/features/profile/presentation/profile_screen.dart`
- Modify: `test/features/shell/main_nav_bar_test.dart`
- Modify: `test/features/shell/main_shell_test.dart`
- Modify: `test/features/shell/home_shell_layout_test.dart`
- Modify: `test/features/profile/profile_screen_test.dart`

- [ ] **Step 1: Delete the now-dead ComingSoonScreen**

```bash
git rm lib/features/shell/presentation/coming_soon_screen.dart
```

- [ ] **Step 2: Add the route list to wallet_routes.dart**

Read the current file (from Task 8) and replace its entire contents with:

```dart
// lib/features/wallet/presentation/wallet_routes.dart
import 'package:go_router/go_router.dart';

import 'package:rego/features/wallet/presentation/wallet_payment_webview_screen.dart';
import 'package:rego/features/wallet/presentation/wallet_screen.dart';
import 'package:rego/features/wallet/presentation/wallet_topup_screen.dart';

abstract final class WalletRoutes {
  static const wallet = '/profile/wallet';
  static const topUp = '/profile/wallet/top-up';
  static const pay = '/profile/wallet/pay';
}

List<RouteBase> walletRoutes() => [
      GoRoute(
        path: WalletRoutes.wallet,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: WalletRoutes.topUp,
        builder: (context, state) => const WalletTopUpScreen(),
      ),
      GoRoute(
        path: WalletRoutes.pay,
        builder: (context, state) {
          final url = state.extra;
          return WalletPaymentWebViewScreen(
            checkoutUrl: url is String ? url : '',
          );
        },
      ),
    ];
```

- [ ] **Step 3: Edit app_router.dart**

Replace the imports block:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/features/auth/presentation/auth_flow_args.dart';
import 'package:rego/features/auth/presentation/forgot_password_screen.dart';
import 'package:rego/features/auth/presentation/login_screen.dart';
import 'package:rego/features/auth/presentation/new_password_screen.dart';
import 'package:rego/features/auth/presentation/onboarding_screen.dart';
import 'package:rego/features/auth/presentation/otp_verify_screen.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/auth/presentation/register_screen.dart';
import 'package:rego/features/auth/presentation/splash_screen.dart';
import 'package:rego/features/home/presentation/home_screen.dart';
import 'package:rego/features/profile/presentation/profile_screen.dart';
import 'package:rego/features/shell/presentation/coming_soon_screen.dart';
import 'package:rego/features/shell/presentation/main_shell.dart';
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/tickets/presentation/tickets_screen.dart';
import 'package:rego/l10n/app_localizations.dart';
```

with:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/features/auth/presentation/auth_flow_args.dart';
import 'package:rego/features/auth/presentation/forgot_password_screen.dart';
import 'package:rego/features/auth/presentation/login_screen.dart';
import 'package:rego/features/auth/presentation/new_password_screen.dart';
import 'package:rego/features/auth/presentation/onboarding_screen.dart';
import 'package:rego/features/auth/presentation/otp_verify_screen.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/auth/presentation/register_screen.dart';
import 'package:rego/features/auth/presentation/splash_screen.dart';
import 'package:rego/features/home/presentation/home_screen.dart';
import 'package:rego/features/profile/presentation/profile_screen.dart';
import 'package:rego/features/shell/presentation/main_shell.dart';
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/tickets/presentation/tickets_screen.dart';
import 'package:rego/features/wallet/presentation/wallet_routes.dart';
import 'package:rego/l10n/app_localizations.dart';
```

Replace the `AppRoutes` class:

```dart
abstract final class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const otp = '/otp';
  static const forgotPassword = '/forgot-password';
  static const newPassword = '/new-password';
  static const home = '/';
  static const tickets = '/tickets';
  static const wallet = '/wallet';
  static const profile = '/profile';
}
```

with:

```dart
abstract final class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const otp = '/otp';
  static const forgotPassword = '/forgot-password';
  static const newPassword = '/new-password';
  static const home = '/';
  static const tickets = '/tickets';
  static const profile = '/profile';
}
```

Replace the `StatefulShellRoute.indexedStack` branches list and the routes that follow it:

```dart
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.tickets,
                builder: (context, state) => const TicketsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.wallet,
                builder: (context, state) => ComingSoonScreen(
                  title: AppLocalizations.of(context).navWallet,
                  icon: AppIcons.wallet,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      ...busRoutes(),
    ],
```

with:

```dart
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.tickets,
                builder: (context, state) => const TicketsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      ...busRoutes(),
      ...walletRoutes(),
    ],
```

- [ ] **Step 4: Edit main_nav_bar.dart**

Replace:

```dart
    final destinations = <(IconData, String)>[
      (AppIcons.home, l10n.navHome),
      (AppIcons.ticket, l10n.navTickets),
      (AppIcons.wallet, l10n.navWallet),
      (AppIcons.user, l10n.navProfile),
    ];
```

with:

```dart
    final destinations = <(IconData, String)>[
      (AppIcons.home, l10n.navHome),
      (AppIcons.ticket, l10n.navTickets),
      (AppIcons.user, l10n.navProfile),
    ];
```

- [ ] **Step 5: Edit profile_screen.dart**

Add this import alongside the existing ones:

```dart
import 'package:rego/features/wallet/presentation/wallet_routes.dart';
```

Replace the Wallet menu item:

```dart
                _ProfileMenuItem(
                  icon: AppIcons.wallet,
                  label: l10n.profileMenuWallet,
                  onTap: () => _showComingSoon(context, l10n),
                ),
```

with:

```dart
                _ProfileMenuItem(
                  icon: AppIcons.wallet,
                  label: l10n.profileMenuWallet,
                  onTap: () => isGuest
                      ? context.go(
                          AppRoutes.login,
                          extra: const AuthGateArgs(
                            returnTo: WalletRoutes.wallet,
                          ),
                        )
                      : context.push(WalletRoutes.wallet),
                ),
```

- [ ] **Step 6: Rewrite main_nav_bar_test.dart for three destinations**

Replace these two tests:

```dart
  testWidgets('renders all four destination labels', (tester) async {
    await tester.pumpWidget(wrap(currentIndex: 0, onSelected: (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Tickets'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('tapping a destination reports its index', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      wrap(currentIndex: 0, onSelected: (i) => tapped = i),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wallet'));
    expect(tapped, 2);
  });
```

with:

```dart
  testWidgets('renders all three destination labels', (tester) async {
    await tester.pumpWidget(wrap(currentIndex: 0, onSelected: (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Tickets'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('tapping a destination reports its index', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      wrap(currentIndex: 0, onSelected: (i) => tapped = i),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    expect(tapped, 2);
  });
```

Leave the rest of the file (dark theme, RTL, semantics, text-scale tests) exactly as-is — they don't reference Wallet.

- [ ] **Step 7: Rewrite main_shell_test.dart for three branches**

Overwrite the full file with:

```dart
// test/features/shell/main_shell_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/features/shell/presentation/main_shell.dart';
import 'package:rego/l10n/app_localizations.dart';

void main() {
  GoRouter buildRouter() {
    GoRoute branch(String path) => GoRoute(
          path: path,
          builder: (_, __) => const SizedBox.shrink(),
        );

    return GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(routes: [branch('/')]),
            StatefulShellBranch(routes: [branch('/tickets')]),
            StatefulShellBranch(routes: [branch('/profile')]),
          ],
        ),
      ],
    );
  }

  Future<void> pumpShell(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
      ),
    );
    await tester.pumpAndSettle();
  }

  String currentLocation(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  testWidgets('starts on the home branch', (tester) async {
    final router = buildRouter();
    await pumpShell(tester, router);

    expect(currentLocation(router), '/');
  });

  testWidgets('tapping a tab switches to its branch', (tester) async {
    final router = buildRouter();
    await pumpShell(tester, router);

    await tester.tap(find.text('Tickets'));
    await tester.pumpAndSettle();
    expect(currentLocation(router), '/tickets');

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(currentLocation(router), '/profile');

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(currentLocation(router), '/');
  });

  testWidgets('back on a non-home tab switches to Home', (tester) async {
    final router = buildRouter();
    await pumpShell(tester, router);

    await tester.tap(find.text('Tickets'));
    await tester.pumpAndSettle();
    expect(currentLocation(router), '/tickets');

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(currentLocation(router), '/');
  });

  testWidgets('double back on Home shows exit snackbar', (tester) async {
    final router = buildRouter();
    await pumpShell(tester, router);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(currentLocation(router), '/');
  });
}
```

- [ ] **Step 8: Rewrite home_shell_layout_test.dart for three branches, without ComingSoonScreen**

Overwrite the full file with:

```dart
// test/features/shell/home_shell_layout_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/features/home/presentation/home_screen.dart';
import 'package:rego/features/shell/presentation/main_shell.dart';
import 'package:rego/features/shell/presentation/widgets/main_nav_bar.dart';
import 'package:rego/l10n/app_localizations.dart';

void main() {
  testWidgets('home fills the shell and the nav bar sits at the bottom', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532); // ~iPhone, 390x844 @3x
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    GoRoute stub(String path) => GoRoute(
          path: path,
          builder: (_, __) => const SizedBox.shrink(),
        );

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
              ],
            ),
            StatefulShellBranch(routes: [stub('/tickets')]),
            StatefulShellBranch(routes: [stub('/profile')]),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final screenH =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    final homeSize = tester.getSize(find.byType(HomeScreen));
    final navTop = tester.getTopLeft(find.byType(MainNavBar)).dy;

    // ignore: avoid_print
    print('screenH=$screenH homeHeight=${homeSize.height} navTop=$navTop');

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(homeSize.height, greaterThan(screenH * 0.5),
        reason: 'home body should fill most of the screen');
    expect(navTop, greaterThan(screenH * 0.7),
        reason: 'nav bar should sit near the bottom');
  });
}
```

- [ ] **Step 9: Add wallet-row tests to profile_screen_test.dart**

Add this import alongside the existing ones at the top of `test/features/profile/profile_screen_test.dart`:

```dart
import 'package:rego/features/wallet/presentation/wallet_routes.dart';
```

Add these two tests to the end of the `main()` body, before the final closing brace:

```dart
  testWidgets('tapping Wallet pushes the wallet screen for a signed-in user',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(
          () => _FakeSessionController(session),
        ),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: AppRoutes.profile,
      routes: [
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: WalletRoutes.wallet,
          builder: (context, state) => const Text('WALLET'),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final walletTile = find.text('Wallet');
    await tester.ensureVisible(walletTile);
    await tester.pumpAndSettle();
    await tester.tap(walletTile);
    await tester.pumpAndSettle();

    expect(find.text('WALLET'), findsOneWidget);
  });

  testWidgets('tapping Wallet as a guest opens Login with returnTo the wallet',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(
          () => _FakeSessionController(null),
        ),
        guestModeProvider.overrideWith(() => _FakeGuestController(true)),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: AppRoutes.profile,
      routes: [
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) {
            final args = state.extra;
            return Text(
              args is AuthGateArgs
                  ? 'LOGIN returnTo=${args.returnTo}'
                  : 'LOGIN no gate args',
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final walletTile = find.text('Wallet');
    await tester.ensureVisible(walletTile);
    await tester.pumpAndSettle();
    await tester.tap(walletTile);
    await tester.pumpAndSettle();

    expect(
      find.text('LOGIN returnTo=${WalletRoutes.wallet}'),
      findsOneWidget,
    );
  });
```

- [ ] **Step 10: Run the full test suite**

Run: `flutter test`
Expected: All tests PASS, zero failures.

- [ ] **Step 11: Run the analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
refactor(nav): remove Wallet bottom-nav tab, wire wallet from Profile

The Wallet tab is gone from the bottom nav; the wallet is now reached
from the Profile menu (signed-in users push straight to it, guests are
routed to Login with returnTo set). Also removes the now-fully-unused
ComingSoonScreen widget.
EOF
)"
```

---

### Task 12: Final verification

**Files:** none — this task only runs checks.

- [ ] **Step 1: Run code generation once more to confirm nothing is stale**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Completes with no new/changed output (everything was already generated in Task 1).

- [ ] **Step 2: Run the full analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: All tests PASS, zero failures, zero skips introduced by this work.

- [ ] **Step 4: Confirm the working tree is clean**

Run: `git status`
Expected: Nothing to commit (every task already committed its own changes) other than the pre-existing unrelated modification to `docs/wadeny-apis.md` noted at the start of this work, which this plan does not touch.

- [ ] **Step 5: Report**

Summarize for the user: wallet feature implemented across 11 commits on `main`, all automated checks green, no manual/device verification performed (per instruction) — recommend the user run the app themselves before considering this shippable, since no one has visually confirmed the screens render correctly.

---

## Notes for whoever executes this plan

- Every task after Task 1 depends on the ones before it — execute in order.
- Tasks 2, 4, 8, 9, and 10 follow TDD: the test is written and run-to-fail before the implementation exists. Don't skip the "verify it fails" steps — they confirm the test is actually exercising the new code, not passing by accident.
- Task 11 is the only task where the repository is briefly inconsistent mid-task (between deleting `coming_soon_screen.dart` and finishing the router/nav-bar/test edits) — do not stop partway through it or commit in the middle.
- If `flutter analyze` flags the two new `AppIcons` entries in Task 6, that's an icon-name mismatch in `tabler_icons_plus`, not a design problem — fix the name and continue.
