import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Inline adult-count stepper (1–9) on [FlightSearchForm].
class FlightPassengerCountField extends StatelessWidget {
  const FlightPassengerCountField({
    super.key,
    required this.count,
    required this.onChanged,
  });

  final int count;
  final ValueChanged<int> onChanged;

  static const _min = 1;
  static const _max = 9;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final valueLabel =
        count == 1 ? l10n.homeOnePax : l10n.flightPassengersCount(count);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 8, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.bgBase,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              PhosphorIconsLight.usersThree,
              color: AppColors.textMuted,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.flightPassengers,
                  style: AppTypography.overline.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  valueLabel,
                  style: AppTypography.title.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(PhosphorIconsLight.minus, size: 18),
            color: AppColors.textMuted,
            onPressed: count > _min ? () => onChanged(count - 1) : null,
          ),
          Text(
            '$count',
            style: AppTypography.title.copyWith(fontWeight: FontWeight.w800),
          ),
          IconButton(
            icon: const Icon(PhosphorIconsLight.plus, size: 18),
            color: AppColors.primary,
            onPressed: count < _max ? () => onChanged(count + 1) : null,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }
}
