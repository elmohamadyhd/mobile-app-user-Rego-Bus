import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';

/// One [FlightSegment] on [FlightOfferDetailsScreen] — full breakdown, not
/// the summarized view [FlightOfferCard] shows.
class FlightSegmentRow extends StatelessWidget {
  const FlightSegmentRow({super.key, required this.segment});

  final FlightSegment segment;

  // Hand-rolled like `TripCard._formatTime` — always 24-hour, independent of
  // locale/intl data initialization.
  static String _time(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                PhosphorIconsLight.airplane,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${segment.marketingCarrierCode} ${segment.marketingFlightNumber}',
                style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
              ),
              if (segment.equipment != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  segment.equipment!,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_time(segment.departureDateTime)} · ${segment.origin}'
                '${segment.departureTerminal != null ? " T${segment.departureTerminal}" : ""}',
                style: AppTypography.body,
              ),
              Transform.flip(
                flipX: Directionality.of(context) == TextDirection.rtl,
                child: const Icon(
                  PhosphorIconsLight.arrowRight,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                '${_time(segment.arrivalDateTime)} · ${segment.destination}'
                '${segment.arrivalTerminal != null ? " T${segment.arrivalTerminal}" : ""}',
                style: AppTypography.body,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
