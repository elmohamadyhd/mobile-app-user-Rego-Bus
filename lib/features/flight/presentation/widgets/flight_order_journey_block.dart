import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_order.dart';
import 'package:safaria/features/flight/domain/utils/flight_airport_labels.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_leg_badge.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/ltr_text.dart';

/// One grouped journey (outbound, return, or a connecting chain) as shown
/// on My Tickets cards and the ticket details page.
class FlightOrderJourneyBlock extends StatelessWidget {
  const FlightOrderJourneyBlock({
    super.key,
    required this.hops,
    required this.index,
    required this.total,
    required this.airportNames,
    required this.localeName,
    this.trailing,
  });

  final List<FlightOrderSegment> hops;
  final int index;
  final int total;
  final Map<String, String> airportNames;
  final String localeName;
  final Widget? trailing;

  static String _time(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final first = hops.first;
    final last = hops.last;
    final origin = flightAirportDisplayName(
      iataCode: first.origin,
      namesByIata: airportNames,
    );
    final destination = flightAirportDisplayName(
      iataCode: last.destination,
      namesByIata: airportNames,
    );
    final badgeLabel = flightJourneyBadgeLabel(
      l10n,
      index: index,
      total: total,
    );
    final badgeKind = flightJourneyBadgeKind(index: index, total: total);
    final departure = first.departureDateTime;
    final arrival = last.arrivalDateTime;
    final stops = hops.length - 1;
    final stopsText = stops == 0
        ? l10n.flightDirect
        : stops == 1
            ? l10n.flightOneStop
            : l10n.flightStopsCount(stops);
    final flightNos = [
      for (final hop in hops)
        '${hop.marketingCarrierCode ?? ''}${hop.marketingFlightNumber ?? ''}',
    ].where((code) => code.trim().isNotEmpty).join(' · ');
    final flightMeta = flightNos.isEmpty ? '' : ' · $flightNos';
    final placeStyle = AppTypography.caption.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (badgeLabel != null && badgeKind != null)
              FlightLegBadge(label: badgeLabel, kind: badgeKind),
            if (departure != null) ...[
              if (badgeLabel != null) const SizedBox(width: AppSpacing.xs),
              FlightDateChip(DateFormat.MMMd(localeName).format(departure)),
            ],
            const Spacer(),
            if (trailing != null) trailing!,
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
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
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
        if (departure != null && arrival != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              LtrText(
                '${_time(departure)} – ${_time(arrival)}',
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
      ],
    );
  }
}
