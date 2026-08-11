import 'package:dio/dio.dart';

/// Transport layer over `/flights/*`. Returns raw decoded JSON bodies.
class FlightApi {
  FlightApi(this._dio);

  final Dio _dio;

  Future<dynamic> searchIata({required String search, int page = 1}) async {
    final res = await _dio.get(
      '/flights/iata',
      queryParameters: {'search': search, 'page': page},
    );
    return res.data;
  }

  Future<dynamic> searchAirports({required String term}) async {
    final res = await _dio.get(
      '/flights/airports/search',
      queryParameters: {'term': term},
    );
    return res.data;
  }

  Future<dynamic> search(Map<String, dynamic> body) async {
    final res = await _dio.post('/flights/search', data: body);
    return res.data;
  }

  /// `GET /settings` — booking currency and the single payment gateway.
  Future<dynamic> settings() async {
    final res = await _dio.get('/settings');
    return res.data;
  }

  Future<dynamic> confirmOrder(String offerId) async {
    final res = await _dio.post('/flights/${_encodeOfferId(offerId)}/confirm');
    return res.data;
  }

  /// `GET /flights/{offer_id}/bundles`.
  ///
  /// Must be called with the offer id returned by **confirm**, not the one
  /// from search. Passing the searched id is what produces
  /// `400 "offer id is not valid or expired"` — the errors recorded here
  /// previously were that mistake, not a broken endpoint.
  Future<dynamic> bundles(String offerId) async {
    final res = await _dio.get('/flights/${_encodeOfferId(offerId)}/bundles');
    return res.data;
  }

  /// `GET /countries` — the source for nationality, residence, and dial codes.
  Future<dynamic> countries() async {
    final res = await _dio.get('/countries');
    return res.data;
  }

  /// `POST /flights/{offer_id}/passengers`.
  /// [body] matches the documented request: `{"passengers": [...]}`.
  Future<dynamic> addPassengers({
    required String offerId,
    required Map<String, dynamic> body,
  }) async {
    final res = await _dio.post(
      '/flights/${_encodeOfferId(offerId)}/passengers',
      data: body,
    );
    return res.data;
  }

  /// `POST /flights/{offer_id}/hold` — response shape unconfirmed.
  /// [body] matches the documented request:
  /// `{"_selectedBundles": [{"journeyKey": ..., "selectedBundleCode": ...}]}`.
  Future<dynamic> hold({
    required String offerId,
    required Map<String, dynamic> body,
  }) async {
    final res = await _dio.post(
      '/flights/${_encodeOfferId(offerId)}/hold',
      data: body,
    );
    return res.data;
  }

  /// `POST /flights/{offer_id}` — creates the order and returns it with a
  /// payment transaction.
  ///
  /// [offerId] must be the id returned by adding passengers. The 404 recorded
  /// here previously came from sending an earlier id in the relay.
  Future<dynamic> pending({
    required String offerId,
    required Map<String, dynamic> body,
  }) async {
    final res = await _dio.post('/flights/${_encodeOfferId(offerId)}', data: body);
    return res.data;
  }

  /// `GET /profile/flights/orders`
  Future<dynamic> orders() async {
    final res = await _dio.get('/profile/flights/orders');
    return res.data;
  }

  /// `GET /profile/flights/orders/{id}` — the source of truth for whether an
  /// order was actually paid. Never trust the WebView redirect alone.
  Future<dynamic> order(String id) async {
    final res = await _dio.get('/profile/flights/orders/$id');
    return res.data;
  }

  Future<dynamic> submitReview({
    required String orderId,
    required int rating,
    String? comment,
  }) async {
    final body = <String, dynamic>{'rating': '$rating'};
    final trimmed = comment?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      body['comment'] = trimmed;
    }
    final res = await _dio.post(
      '/profile/flights/orders/$orderId/review',
      data: body,
    );
    return res.data;
  }

  static String _encodeOfferId(String offerId) => Uri.encodeComponent(offerId);
}
