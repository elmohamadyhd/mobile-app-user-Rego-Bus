import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/features/bus/domain/entities/bus_feature.dart';
import 'package:safaria/features/bus/presentation/widgets/feature_icon.dart';

/// Compact row of amenity glyphs (max 4, no labels) shared by the results
/// `TripCard` header and the trip-details ticket header.
class AmenityIconsRow extends StatelessWidget {
  const AmenityIconsRow({super.key, required this.features, this.size = 15});

  final List<BusFeature> features;
  final double size;

  @override
  Widget build(BuildContext context) {
    final items = features.take(4).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final f in items)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
            child: FeatureIcon(feature: f, size: size),
          ),
      ],
    );
  }
}
