import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/bus/data/bus_api.dart';
import 'package:safaria/features/bus/data/bus_repository_impl.dart';

class _FakeBusApi extends BusApi {
  _FakeBusApi() : super(Dio());

  String? lastOrderId;
  int? lastRating;
  String? lastComment;
  Map<String, dynamic>? body;

  @override
  Future<dynamic> submitReview({
    required String orderId,
    required int rating,
    String? comment,
  }) async {
    lastOrderId = orderId;
    lastRating = rating;
    lastComment = comment;
    return body ??
        {
          'status': 200,
          'message': 'ok',
          'errors': <String, dynamic>{},
          'data': <String, dynamic>{},
        };
  }
}

void main() {
  test('submitReview posts rating and optional comment via API', () async {
    final api = _FakeBusApi();
    final repo = BusRepositoryImpl(api);

    await repo.submitReview(
      orderId: '1475',
      rating: 5,
      comment: 'great',
    );

    expect(api.lastOrderId, '1475');
    expect(api.lastRating, 5);
    expect(api.lastComment, 'great');
  });
}
