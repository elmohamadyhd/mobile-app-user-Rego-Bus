import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/utils/flight_price_change.dart';

void main() {
  test('an unchanged price reports no change', () {
    expect(flightPriceChange(searched: 15825.55, confirmed: 15825.55), isNull);
  });

  test('sub-piastre drift is not a price change', () {
    expect(flightPriceChange(searched: 15825.55, confirmed: 15825.554), isNull);
  });

  test('an increase is reported with both amounts', () {
    final change = flightPriceChange(searched: 15825.55, confirmed: 16200);
    expect(change, isNotNull);
    expect(change!.wasSearched, 15825.55);
    expect(change.nowConfirmed, 16200);
    expect(change.isIncrease, isTrue);
  });

  test('a decrease is still reported — the rider should see it', () {
    final change = flightPriceChange(searched: 16200, confirmed: 15825.55);
    expect(change!.isIncrease, isFalse);
  });
}
