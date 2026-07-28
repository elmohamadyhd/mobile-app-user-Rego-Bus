import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Maps a free-text amenity label to a Phosphor Light icon.
IconData amenityIconFor(String amenity) {
  final s = amenity.toLowerCase();
  if (s.contains('wifi') || s.contains('wi-fi') || s.contains('واي')) {
    return PhosphorIconsLight.wifiHigh;
  }
  if (s.contains('a/c') ||
      s.contains('air') ||
      s.contains('تكييف') ||
      s.contains('مكي')) {
    return PhosphorIconsLight.wind;
  }
  if (s.contains('sock') ||
      s.contains('plug') ||
      s.contains('power') ||
      s.contains('كهرب') ||
      s.contains('شحن')) {
    return PhosphorIconsLight.plug;
  }
  if (s.contains('wc') ||
      s.contains('w.c') ||
      s.contains('toilet') ||
      s.contains('bath') ||
      s.contains('restroom') ||
      s.contains('water') ||
      s.contains('مياه') ||
      s.contains('ماء') ||
      s.contains('حمام') ||
      s.contains('مرحاض')) {
    return PhosphorIconsLight.toilet;
  }
  return PhosphorIconsLight.check;
}
