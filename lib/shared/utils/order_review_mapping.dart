/// Extracts a 1–5 rating from Wadeny `review` field variants.
int? parseOrderReviewRating(dynamic review) {
  if (review == null) return null;
  if (review is num) return _inRange(review.toInt());
  if (review is String) {
    final parsed = int.tryParse(review.trim());
    return parsed == null ? null : _inRange(parsed);
  }
  if (review is Map) {
    return parseOrderReviewRating(review['rating']);
  }
  return null;
}

int? _inRange(int value) => (value >= 1 && value <= 5) ? value : null;
