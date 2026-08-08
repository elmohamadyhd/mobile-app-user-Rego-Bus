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

  /// `POST /flights/{offer_id}/passengers` — response shape unconfirmed.
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

  /// `POST /flights/{offer_id}` — response shape unconfirmed, and the route
  /// as documented in Postman 404'd ("no url matched") against the demo
  /// backend even with a valid, unencoded offer id. Confirm the real path
  /// and method with the backend team before relying on this.
  Future<dynamic> pending({
    required String offerId,
    required Map<String, dynamic> body,
  }) async {
    final res = await _dio.post('/flights/${_encodeOfferId(offerId)}', data: body);
    return res.data;
  }

  static String _encodeOfferId(String offerId) => Uri.encodeComponent(offerId);
}
