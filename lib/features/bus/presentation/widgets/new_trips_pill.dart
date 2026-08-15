import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Offers trips that arrived while the rider was reading further down the
/// list. Inserting them silently would move the card under their finger, so
/// the reveal is theirs to trigger.
class NewTripsPill extends StatelessWidget {
  const NewTripsPill({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.input),
      elevation: 3,
      shadowColor: AppColors.cardShadowSoft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            l10n.tripResultsNewTrips(count),
            style: AppTypography.caption.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
