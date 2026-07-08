import 'package:freezed_annotation/freezed_annotation.dart';

part 'bus_location.freezed.dart';

@freezed
abstract class BusLocation with _$BusLocation {
  const factory BusLocation({
    required int id,
    required String name,
    String? nameAr,
    String? nameEn,
  }) = _BusLocation;

  const BusLocation._();

  String displayName(String languageCode) {
    if (languageCode == 'en' && nameEn != null && nameEn!.isNotEmpty) {
      return nameEn!;
    }
    if (languageCode == 'ar' && nameAr != null && nameAr!.isNotEmpty) {
      return nameAr!;
    }
    return name;
  }

  bool matchesQuery(String query, String languageCode) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return true;
    final q = trimmed.toLowerCase();
    return displayName(languageCode).toLowerCase().contains(q) ||
        name.toLowerCase().contains(q) ||
        (nameEn?.toLowerCase().contains(q) ?? false) ||
        (nameAr?.contains(trimmed) ?? false);
  }
}

/// Default seeds until the cached API list resolves ids 1 and 2.
abstract final class BusLocationDefaults {
  static const from = BusLocation(
    id: 1,
    name: 'القاهره',
    nameAr: 'القاهره',
    nameEn: 'Cairo',
  );

  static const to = BusLocation(
    id: 2,
    name: 'الاسكندريه',
    nameAr: 'الاسكندريه',
    nameEn: 'Alexandria',
  );

  static BusLocation? byId(List<BusLocation> locations, int id) {
    for (final location in locations) {
      if (location.id == id) return location;
    }
    return null;
  }
}
