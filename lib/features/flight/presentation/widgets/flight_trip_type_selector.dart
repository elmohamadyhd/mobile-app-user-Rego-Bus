import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Segmented one-way / round-trip / multi-city control. The search form body
/// morphs beneath it.
class FlightTripTypeSelector extends StatelessWidget {
  const FlightTripTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final FlightTripType value;
  final ValueChanged<FlightTripType> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgBase,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (final type in FlightTripType.values)
            Expanded(
              child: GestureDetector(
                key: Key('flight-trip-${type.wireValue}'),
                onTap: () => onChanged(type),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: type == value
                        ? AppColors.bgElevated
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    switch (type) {
                      FlightTripType.oneWay => l10n.flightTripOneWay,
                      FlightTripType.roundTrip => l10n.flightTripRound,
                      FlightTripType.multiCity => l10n.flightTripMulti,
                    },
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: type == value
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight:
                          type == value ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
