import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/ltr_text.dart';

/// Compact one-journey summary for the Review step.
class FlightTripSummaryCard extends StatelessWidget {
  const FlightTripSummaryCard({
    super.key,
    required this.journey,
    this.legLabel,
  });

  final FlightJourney journey;
  final String? legLabel;

  static String _time(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final first = journey.segments.first;
    final last = journey.segments.last;
    final dateText = DateFormat.MMMd(locale).format(first.departureDateTime);
    final stopsText = journey.numberOfStops == 0
        ? l10n.flightDirect
        : journey.numberOfStops == 1
            ? l10n.flightOneStop
            : l10n.flightStopsCount(journey.numberOfStops);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (legLabel != null) ...[
            Text(
              legLabel!,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  '${journey.origin} → ${journey.destination}',
                  style: AppTypography.title.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                dateText,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              LtrText(
                '${_time(first.departureDateTime)} – '
                '${_time(last.arrivalDateTime)}',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '· $stopsText',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
