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
