import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/features/bus/presentation/widgets/amenity_icon.dart';

/// Compact row of amenity glyphs (max 4, no labels) shared by the results
/// `TripCard` header and the trip-details ticket header.
class AmenityIconsRow extends StatelessWidget {
  const AmenityIconsRow({super.key, required this.amenities, this.size = 15});

  final List<String> amenities;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icons = amenities.take(4).map(amenityIconFor).toList();
    if (icons.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final icon in icons)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
            child: Icon(icon, size: size, color: AppColors.textSecondary),
          ),
      ],
    );
  }
}
