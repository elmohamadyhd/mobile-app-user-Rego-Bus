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
