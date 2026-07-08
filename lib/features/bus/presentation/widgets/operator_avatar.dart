import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';

/// Rounded-square operator mark (logo, falling back to initials) shared by
/// the results [TripCard] and the trip-details ticket so the same operator
/// identity reads consistently across both screens.
class OperatorAvatar extends StatelessWidget {
  const OperatorAvatar({super.key, required this.trip, this.size = 42});

  final BusTripSummary trip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool hasLogo = trip.operatorLogoUrl != null;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: hasLogo
          ? Image.network(
              trip.operatorLogoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initials(),
            )
          : _initials(),
    );
  }

  Widget _initials() => Text(
        trip.operatorCode,
        style: AppTypography.body.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.31,
        ),
      );
}
