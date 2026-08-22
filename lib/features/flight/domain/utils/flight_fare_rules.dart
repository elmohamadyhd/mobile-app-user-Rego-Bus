import 'package:safaria/features/flight/domain/entities/flight_offer.dart';

/// First-seen unique fare-rule lines from [priceClasses].
///
/// Search payloads often repeat the class name (e.g. three "Optima"
/// bullets). Review should not look like a broken list.
List<String> uniqueFlightFareRules(
  Iterable<FlightPriceClass> priceClasses,
) {
  final seen = <String>{};
  final out = <String>[];
  for (final priceClass in priceClasses) {
    for (final rule in priceClass.rulesAndPenalties ?? const <String>[]) {
      final trimmed = rule.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) continue;
      out.add(trimmed);
    }
  }
  return out;
}
