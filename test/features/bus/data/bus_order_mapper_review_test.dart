import 'package:flutter_test/flutter_test.dart';

import 'package:safaria/features/bus/data/bus_dto_mapper.dart';

import 'bus_fixtures.dart';

void main() {
  group('BusDtoMapper order review fields', () {
    test('maps can_review and review rating from map', () {
      final json = Map<String, dynamic>.from(
        busOrderShowEnvelope['data'] as Map<String, dynamic>,
      );
      json['can_review'] = true;
      json['review'] = {'rating': '4'};
      json['status_code'] = 'success';
      json['is_confirmed'] = 1;

      final order = BusDtoMapper.orderFromJson(json);
      expect(order.canReview, isTrue);
      expect(order.reviewRating, 4);
    });

    test('defaults missing review keys', () {
      final json = Map<String, dynamic>.from(
        busOrderShowEnvelope['data'] as Map<String, dynamic>,
      );
      json.remove('can_review');
      json.remove('review');

      final order = BusDtoMapper.orderFromJson(json);
      expect(order.canReview, isFalse);
      expect(order.reviewRating, isNull);
    });
  });
}
