import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Summary card for one [FlightOffer] on the results list. Only the first
/// journey is shown — one-way search always returns exactly one.
class FlightOfferCard extends StatelessWidget {
  const FlightOfferCard({super.key, required this.offer, required this.onTap});

  final FlightOffer offer;
  final VoidCallback onTap;

  // Hand-rolled like `TripCard._formatTime` — always 24-hour, independent of
  // locale/intl data initialization.
  static String _time(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _duration(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final journey = offer.journeys.first;
    final firstSegment = journey.segments.first;
    final lastSegment = journey.segments.last;
    final totalMinutes =
        journey.segments.fold<int>(0, (sum, s) => sum + s.flightTimeInMinutes);
    final stopsLabel = journey.numberOfStops == 0
        ? l10n.flightDirect
        : journey.numberOfStops == 1
            ? l10n.flightOneStop
            : l10n.flightStopsCount(journey.numberOfStops);

    return Material(
      color: AppColors.bgElevated,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      elevation: 2,
      shadowColor: AppColors.primary.withValues(alpha: 0.12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (firstSegment.operatingCarrierLogo != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.network(
                        firstSegment.operatingCarrierLogo!,
                        width: 28,
                        height: 28,
                        errorBuilder: (_, __, ___) => const Icon(
                          PhosphorIconsLight.airplane,
                          color: AppColors.textMuted,
                        ),
                      ),
                    )
                  else
                    const Icon(
                      PhosphorIconsLight.airplane,
                      color: AppColors.textMuted,
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    firstSegment.operatingCarrierName ??
                        firstSegment.operatingCarrierCode,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _time(firstSegment.departureDateTime),
                        style: AppTypography.title
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        journey.origin,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          _duration(totalMinutes),
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Transform.flip(
                          flipX: Directionality.of(context) == TextDirection.rtl,
                          child: const Icon(
                            PhosphorIconsLight.arrowRight,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stopsLabel,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _time(lastSegment.arrivalDateTime),
                        style: AppTypography.title
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        journey.destination,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: AppColors.hairline, height: AppSpacing.lg),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  '${offer.totalAmount.toStringAsFixed(0)} ${offer.currency}',
                  style: AppTypography.title.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
