import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/shared/utils/order_review_mapping.dart';

void main() {
  group('parseOrderReviewRating', () {
    test('null → null', () {
      expect(parseOrderReviewRating(null), isNull);
    });

    test('int in range', () {
      expect(parseOrderReviewRating(4), 4);
    });

    test('string numeric', () {
      expect(parseOrderReviewRating('5'), 5);
    });

    test('map with rating', () {
      expect(parseOrderReviewRating({'rating': '3', 'comment': 'ok'}), 3);
    });

    test('out of range → null', () {
      expect(parseOrderReviewRating(0), isNull);
      expect(parseOrderReviewRating(6), isNull);
    });

    test('garbage → null', () {
      expect(parseOrderReviewRating('abc'), isNull);
      expect(parseOrderReviewRating(<String, dynamic>{}), isNull);
    });
  });
}
