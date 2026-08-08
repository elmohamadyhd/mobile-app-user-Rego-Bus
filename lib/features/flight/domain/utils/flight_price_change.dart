/// A re-price between the searched offer and the confirmed one.
class FlightPriceChange {
  const FlightPriceChange({
    required this.wasSearched,
    required this.nowConfirmed,
  });

  final double wasSearched;
  final double nowConfirmed;

  bool get isIncrease => nowConfirmed > wasSearched;
}

/// Providers re-price between search and confirm. Returns null when the fare
/// held.
///
/// Differences below one piastre are float noise from the round-trip through
/// JSON, not a re-price, and must not trigger the acceptance banner.
FlightPriceChange? flightPriceChange({
  required double searched,
  required double confirmed,
}) {
  if ((confirmed - searched).abs() < 0.01) return null;
  return FlightPriceChange(wasSearched: searched, nowConfirmed: confirmed);
}
