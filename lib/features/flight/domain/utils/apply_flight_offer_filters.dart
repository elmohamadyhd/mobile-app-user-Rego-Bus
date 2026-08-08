import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer_filters.dart';

/// Refundability values that count as refundable. `UnKnown` is deliberately
/// excluded — showing it under a "refundable only" filter promises something
/// the provider has not confirmed.
const _refundableValues = {'FullyRefundable', 'PartiallyRefundable'};

Set<String> _carrierCodesOf(FlightOffer offer) => offer.journeys
    .expand((journey) => journey.segments)
    .map((segment) => segment.operatingCarrierCode)
    .toSet();

/// Distinct operating carriers across [offers], most offers first. Name and
/// logo come from the first segment that carries them — older responses omit
/// both, so either may be null.
List<FlightCarrierOption> flightCarrierOptions(List<FlightOffer> offers) {
  final counts = <String, int>{};
  final names = <String, String>{};
  final logos = <String, String>{};

  for (final offer in offers) {
    for (final code in _carrierCodesOf(offer)) {
      counts[code] = (counts[code] ?? 0) + 1;
    }
    for (final segment in offer.journeys.expand((j) => j.segments)) {
      final name = segment.operatingCarrierName;
      if (name != null) {
        names.putIfAbsent(segment.operatingCarrierCode, () => name);
      }
      final logo = segment.operatingCarrierLogo;
      if (logo != null) {
        logos.putIfAbsent(segment.operatingCarrierCode, () => logo);
      }
    }
  }

  final options = counts.entries
      .map(
        (entry) => FlightCarrierOption(
          code: entry.key,
          name: names[entry.key],
          logoUrl: logos[entry.key],
          offerCount: entry.value,
        ),
      )
      .toList();

  options.sort((a, b) {
    final byCount = b.offerCount.compareTo(a.offerCount);
    return byCount != 0 ? byCount : a.code.compareTo(b.code);
  });
  return options;
}

/// Cheapest and dearest total across [offers]. Returns `(0, 0)` when empty.
(double min, double max) flightPriceBounds(List<FlightOffer> offers) {
  if (offers.isEmpty) return (0, 0);
  var min = offers.first.totalAmount;
  var max = min;
  for (final offer in offers.skip(1)) {
    if (offer.totalAmount < min) min = offer.totalAmount;
    if (offer.totalAmount > max) max = offer.totalAmount;
  }
  return (min, max);
}

List<FlightOffer> applyFlightOfferFilters(
  List<FlightOffer> offers,
  FlightOfferFilters filters,
) {
  if (filters.isEmpty) return offers;
  return offers.where((offer) {
    if (filters.refundableOnly &&
        !_refundableValues.contains(offer.refundability)) {
      return false;
    }
    final min = filters.minPrice;
    if (min != null && offer.totalAmount < min) return false;
    final max = filters.maxPrice;
    if (max != null && offer.totalAmount > max) return false;
    if (filters.carrierCodes.isNotEmpty &&
        _carrierCodesOf(offer).intersection(filters.carrierCodes).isEmpty) {
      return false;
    }
    return true;
  }).toList();
}

/// Re-points [filters] at a fresh [offers] list after a server-side control
/// changed and the search re-ran.
///
/// Carriers the rider chose that no longer appear are dropped silently. A
/// price range they never touched (both bounds null) stays untouched so it
/// re-derives from the new bounds; one they did touch is clamped rather than
/// discarded, so their intent survives.
FlightOfferFilters preserveFlightFilters({
  required FlightOfferFilters filters,
  required List<FlightOffer> offers,
}) {
  final available = offers.expand(_carrierCodesOf).toSet();
  final (low, high) = flightPriceBounds(offers);
  return filters.copyWith(
    carrierCodes: filters.carrierCodes.intersection(available),
    minPrice: filters.minPrice?.clamp(low, high).toDouble(),
    maxPrice: filters.maxPrice?.clamp(low, high).toDouble(),
  );
}
