import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/date_formatting.dart';
import 'package:safaria/features/flight/domain/entities/flight_airport_suggestion.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_airport_field.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// One multi-city leg: origin, destination, date, and an optional remove.
class FlightLegRow extends StatelessWidget {
  const FlightLegRow({
    super.key,
    required this.index,
    required this.origin,
    required this.destination,
    required this.date,
    required this.onPickOrigin,
    required this.onPickDestination,
    required this.onPickDate,
    required this.onSwap,
    this.onRemove,
  });

  final int index;
  final FlightAirportSuggestion? origin;
  final FlightAirportSuggestion? destination;
  final DateTime date;
  final VoidCallback onPickOrigin;
  final VoidCallback onPickDestination;
  final VoidCallback onPickDate;
  final VoidCallback onSwap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.flightLegLabel(index + 1),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onRemove != null)
              IconButton(
                key: Key('flight-leg-remove-$index'),
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                onPressed: onRemove,
                icon: const Icon(
                  PhosphorIconsLight.trash,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.hairline),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                children: [
                  FlightAirportField(
                    label: l10n.homeFrom,
                    airport: origin,
                    placeholder: l10n.homeCitySelectPlaceholder,
                    icon: PhosphorIconsLight.airplaneTakeoff,
                    iconBg: AppColors.primaryTint,
                    iconColor: AppColors.primary,
                    onTap: onPickOrigin,
                  ),
                  const Divider(
                    color: AppColors.hairline,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  FlightAirportField(
                    label: l10n.homeTo,
                    airport: destination,
                    placeholder: l10n.homeCitySelectPlaceholder,
                    icon: PhosphorIconsLight.airplaneLanding,
                    iconBg: AppColors.secondaryTint,
                    iconColor: AppColors.secondary,
                    onTap: onPickDestination,
                  ),
                ],
              ),
            ),
            PositionedDirectional(
              end: 14,
              top: 0,
              bottom: 0,
              child: Center(
                child: _LegSwapButton(onTap: onSwap),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPickDate,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
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
                        PhosphorIconsLight.calendarBlank,
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
                            l10n.homeDepart,
                            style: AppTypography.overline.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            formatSearchDateCell(date, localeName),
                            style: AppTypography.title.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      PhosphorIconsLight.caretDown,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegSwapButton extends StatelessWidget {
  const _LegSwapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            PhosphorIconsLight.arrowsDownUp,
            color: AppColors.onPrimary,
            size: 20,
          ),
        ),
      ),
    );
  }
}
