import 'package:flutter_test/flutter_test.dart';
import 'package:safaria/features/flight/domain/entities/flight_bundle.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/utils/flight_bundle_pricing.dart';

const _adultOnly = FlightBundle(
  code: 'RCAI',
  name: 'Light',
  prices: [FlightBundlePrice(passengerTypeCode: 'ADT', totalAmount: 250)],
);

const _perType = FlightBundle(
  code: 'VCAI',
  name: 'Flex',
  prices: [
    FlightBundlePrice(passengerTypeCode: 'ADT', totalAmount: 250),
    FlightBundlePrice(passengerTypeCode: 'CHD', totalAmount: 125),
  ],
);

void main() {
  test('a per-type bundle charges each type its own rate', () {
    const counts = FlightPassengerCounts(adults: 2, children: 1);
    expect(flightBundleDelta(_perType, counts), 625);
  });

  test('infants are free unless priced explicitly', () {
    const counts = FlightPassengerCounts(adults: 1, infants: 1);
    expect(flightBundleDelta(_perType, counts), 250);
  });

  test('an adult-only price applies to children too', () {
    const counts = FlightPassengerCounts(adults: 2, children: 1);
    expect(flightBundleDelta(_adultOnly, counts), 750);
  });

  test('a bundle with no prices is free', () {
    const bundle = FlightBundle(code: 'X', name: 'Basic', prices: []);
    expect(flightBundleDelta(bundle, const FlightPassengerCounts()), 0);
  });

  test('the running total adds every selected leg to the confirmed fare', () {
    final total = flightBundlesTotal(
      baseAmount: 10000,
      selected: [_perType, _adultOnly],
      counts: const FlightPassengerCounts(adults: 2, children: 1),
    );
    expect(total, 10000 + 625 + 750);
  });
}
