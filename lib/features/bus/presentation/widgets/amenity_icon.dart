import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_icons.dart';

/// Maps a free-text amenity label (English or Arabic, placeholder or live
/// API data) to its display icon. Contains-based matching so partial or
/// localized variants ("A/C", "تكييف", "aircon") still resolve, unlike an
/// exact-string switch.
IconData amenityIconFor(String amenity) {
  final s = amenity.toLowerCase();
  if (s.contains('wifi') || s.contains('wi-fi') || s.contains('واي')) {
    return AppIcons.amenityWifi;
  }
  if (s.contains('a/c') ||
      s.contains('air') ||
      s.contains('تكييف') ||
      s.contains('مكي')) {
    return AppIcons.amenityAC;
  }
  if (s.contains('sock') ||
      s.contains('plug') ||
      s.contains('power') ||
      s.contains('كهرب') ||
      s.contains('شحن')) {
    return AppIcons.amenitySockets;
  }
  if (s.contains('water') || s.contains('مياه') || s.contains('ماء')) {
    return AppIcons.amenityWater;
  }
  return AppIcons.check;
}
