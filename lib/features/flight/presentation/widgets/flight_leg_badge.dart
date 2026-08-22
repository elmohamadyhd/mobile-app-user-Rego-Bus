import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/ltr_icon.dart';

enum FlightLegKind { outbound, returning, numbered }

/// Null for a one-way offer (a pill would be noise).
FlightLegKind? flightJourneyBadgeKind({
  required int index,
  required int total,
}) {
  if (total < 2) return null;
  if (total == 2) {
    return index == 0 ? FlightLegKind.outbound : FlightLegKind.returning;
  }
  return FlightLegKind.numbered;
}

String? flightJourneyBadgeLabel(
  AppLocalizations l10n, {
  required int index,
  required int total,
}) {
  if (total < 2) return null;
  if (total == 2) {
    return index == 0 ? l10n.flightLegOutbound : l10n.flightLegReturn;
  }
  return l10n.flightLegLabel(index + 1);
}

/// Compact section mark. Blue outbound, amber return, neutral numbered.
class FlightLegBadge extends StatelessWidget {
  const FlightLegBadge({
    super.key,
    required this.label,
    required this.kind,
  });

  final String label;
  final FlightLegKind kind;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon) = switch (kind) {
      FlightLegKind.outbound => (
          AppColors.primaryTint,
          AppColors.primary,
          PhosphorIconsLight.airplaneTakeoff,
        ),
      FlightLegKind.returning => (
          AppColors.secondaryTint,
          AppColors.secondaryDeep,
          PhosphorIconsLight.airplaneLanding,
        ),
      FlightLegKind.numbered => (
          AppColors.inputFill,
          AppColors.textSecondary,
          PhosphorIconsLight.airplane,
        ),
    };

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LtrIcon(icon, size: 12, color: fg),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
