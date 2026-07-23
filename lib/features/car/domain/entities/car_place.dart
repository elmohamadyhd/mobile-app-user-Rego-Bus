import 'package:rego/l10n/app_localizations.dart';

final class CarPlace {
  const CarPlace({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final String label;

  static final _coordinatesLabel = RegExp(
    r'^\s*-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?\s*$',
  );

  static bool looksLikeCoordinates(String text) =>
      _coordinatesLabel.hasMatch(text);

  /// User-facing label — never shows raw lat/lng.
  String displayLabel(AppLocalizations l10n) {
    if (label.isEmpty || looksLikeCoordinates(label)) {
      return l10n.carPlaceSelectedLocation;
    }
    return label;
  }

  bool sameCoordinates(CarPlace other) {
    const epsilon = 0.00001;
    return (latitude - other.latitude).abs() < epsilon &&
        (longitude - other.longitude).abs() < epsilon;
  }
}
