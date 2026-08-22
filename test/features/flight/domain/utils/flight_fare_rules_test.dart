import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/utils/flight_fare_rules.dart';

void main() {
  test('drops duplicate and blank fare rules, keeps first order', () {
    const classes = [
      FlightPriceClass(
        classId: 'a',
        priceClassName: 'Optima',
        fareType: 'PUBLIC',
        rulesAndPenalties: ['Optima', 'Optima', '  '],
      ),
      FlightPriceClass(
        classId: 'b',
        priceClassName: 'Optima',
        fareType: 'PUBLIC',
        rulesAndPenalties: ['Optima', 'Non-refundable'],
      ),
    ];

    expect(uniqueFlightFareRules(classes), ['Optima', 'Non-refundable']);
  });

  test('returns empty when every class has no rules', () {
    const classes = [
      FlightPriceClass(
        classId: 'a',
        priceClassName: 'Optima',
        fareType: 'PUBLIC',
      ),
    ];
    expect(uniqueFlightFareRules(classes), isEmpty);
  });
}
