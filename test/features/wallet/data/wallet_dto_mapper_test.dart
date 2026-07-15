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
