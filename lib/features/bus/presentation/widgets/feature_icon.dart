import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/features/bus/domain/entities/bus_feature.dart';
import 'package:safaria/features/bus/presentation/widgets/amenity_icon.dart';

IconData _fallbackIcon(BusFeature feature) {
  final fromId = amenityIconFor(feature.id);
  if (feature.id.isNotEmpty && fromId != PhosphorIconsLight.check) {
    return fromId;
  }
  if (feature.name.isNotEmpty) {
    return amenityIconFor(feature.name);
  }
  return fromId;
}

class FeatureIcon extends StatelessWidget {
  const FeatureIcon({
    super.key,
    required this.feature,
    this.size = 15,
    this.color = AppColors.textSecondary,
  });

  final BusFeature feature;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      _fallbackIcon(feature),
      size: size,
      color: color,
    );
    final url = feature.iconUrl;
    if (url == null || url.isEmpty) return fallback;

    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(width: size, height: size, child: fallback);
      },
    );
  }
}
