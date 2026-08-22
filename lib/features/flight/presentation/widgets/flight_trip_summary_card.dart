import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_leg_badge.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/ltr_text.dart';

/// Compact one-journey summary for the Review step.
class FlightTripSummaryCard extends StatelessWidget {
  const FlightTripSummaryCard({
    super.key,
    required this.journey,
    this.originLabel,
    this.destinationLabel,
    this.legLabel,
    this.legKind,
  });

  final FlightJourney journey;
  final String? originLabel;
  final String? destinationLabel;
  final String? legLabel;
  final FlightLegKind? legKind;

  static String _time(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _place(String? name, String iataCode) {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return iataCode;
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
    final flightNos = [
      for (final segment in journey.segments)
        '${segment.marketingCarrierCode}${segment.marketingFlightNumber}',
    ].where((code) => code.trim().isNotEmpty).join(' · ');
    final flightMeta = flightNos.isEmpty ? '' : ' · $flightNos';
    final origin = _place(originLabel, journey.origin);
    final destination = _place(destinationLabel, journey.destination);
    final placeStyle = AppTypography.caption.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    );

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
          Row(
            children: [
              if (legLabel != null && legKind != null)
                FlightLegBadge(label: legLabel!, kind: legKind!),
              const Spacer(),
              FlightDateChip(dateText),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  origin,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: placeStyle,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                ),
                child: Icon(
                  PhosphorIconsLight.caretRight,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              Expanded(
                child: Text(
                  destination,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: placeStyle,
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
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  '· $stopsText$flightMeta',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
