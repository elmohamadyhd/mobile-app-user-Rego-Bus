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
