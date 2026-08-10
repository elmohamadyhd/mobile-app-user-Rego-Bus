/// Builds private-order stop names from Google Places / Geocoding parts.
abstract final class PlaceNameResolver {
  /// Prefer [knownName] (e.g. Places `displayName`); else `"Street, City"`.
  static String resolve({
    String? knownName,
    String? street,
    String? city,
  }) {
    final known = knownName?.trim() ?? '';
    if (known.isNotEmpty) return known;

    final s = street?.trim() ?? '';
    final c = city?.trim() ?? '';
    if (s.isNotEmpty && c.isNotEmpty) return '$s, $c';
    if (s.isNotEmpty) return s;
    if (c.isNotEmpty) return c;
    return '';
  }
}
