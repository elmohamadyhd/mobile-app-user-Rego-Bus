import 'package:flutter_test/flutter_test.dart';
import 'package:rego/features/bus/domain/entities/bus_location.dart';

void main() {
  const cairo = BusLocation(
    id: 1,
    name: 'القاهره',
    nameAr: 'القاهره',
    nameEn: 'Cairo',
  );

  test('displayName prefers locale-specific field', () {
    expect(cairo.displayName('en'), 'Cairo');
    expect(cairo.displayName('ar'), 'القاهره');
  });

  test('matchesQuery filters by English and Arabic names', () {
    expect(cairo.matchesQuery('cai', 'en'), isTrue);
    expect(cairo.matchesQuery('القاه', 'ar'), isTrue);
    expect(cairo.matchesQuery('luxor', 'en'), isFalse);
    expect(cairo.matchesQuery('', 'en'), isTrue);
  });
}
