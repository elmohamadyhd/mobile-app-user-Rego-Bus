import 'package:safaria/features/flight/domain/entities/flight_bundle.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';

/// What adding [bundle] costs for the whole party.
///
/// Prices are treated as **per passenger** and multiplied by the head count
/// of their type. When a type in the party has no price of its own, the adult
/// price applies — providers that quote a single `ADT` figure mean it for
/// everyone travelling on a seat. Infants get nothing unless priced
/// explicitly, since they occupy no seat and carry no baggage allowance.
///
/// Live spike (2026-08-08, 2 ADT + 1 CHD): `bundle_prices` stayed a single
/// ADT object whose upgrade deltas matched 1-ADT samples — confirming the
/// per-passenger reading, not a party total.
double flightBundleDelta(FlightBundle bundle, FlightPassengerCounts counts) {
  if (bundle.prices.isEmpty) return 0;

  double rateFor(String code) {
    for (final price in bundle.prices) {
      if (price.passengerTypeCode == code) return price.totalAmount;
    }
    return 0;
  }

  final adultRate = rateFor('ADT');
  final childRate = _hasPriceFor(bundle, 'CHD') ? rateFor('CHD') : adultRate;
  final infantRate = _hasPriceFor(bundle, 'INF') ? rateFor('INF') : 0.0;

  return adultRate * counts.adults +
      childRate * counts.children +
      infantRate * counts.infants;
}

bool _hasPriceFor(FlightBundle bundle, String code) =>
    bundle.prices.any((price) => price.passengerTypeCode == code);

/// Confirmed fare plus every chosen bundle, one per leg.
double flightBundlesTotal({
  required double baseAmount,
  required List<FlightBundle> selected,
  required FlightPassengerCounts counts,
}) {
  return selected.fold<double>(
    baseAmount,
    (sum, bundle) => sum + flightBundleDelta(bundle, counts),
  );
}
