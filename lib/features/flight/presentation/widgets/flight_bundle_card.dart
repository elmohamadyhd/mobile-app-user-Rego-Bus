import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_bundle.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// One selectable bundle. A zero delta reads as "included" rather than
/// "+ 0" — the rider is picking what they get, not paying nothing.
class FlightBundleCard extends StatelessWidget {
  const FlightBundleCard({
    super.key,
    required this.bundle,
    required this.delta,
    required this.currency,
    required this.isSelected,
    required this.onTap,
  });

  final FlightBundle bundle;
  final double delta;
  final String currency;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryTint : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.hairline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    bundle.name,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  delta == 0
                      ? l10n.flightBundleIncluded
                      : '+ ${delta.toStringAsFixed(0)} $currency',
                  style: AppTypography.body.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            for (final service in bundle.includedServices) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    PhosphorIconsLight.check,
                    size: 14,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      service,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
