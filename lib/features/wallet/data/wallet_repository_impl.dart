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
