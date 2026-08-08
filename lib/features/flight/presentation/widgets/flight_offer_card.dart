import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_ticket_border.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/ltr_text.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Boarding-pass styled summary card for one [FlightOffer] on the results list.
/// Every journey on the offer is shown — round-trip and multi-city are one
/// priced unit, so all legs belong on the same card.
class FlightOfferCard extends StatelessWidget {
  const FlightOfferCard({
    super.key,
    required this.offer,
    required this.onTap,
    required this.onSelect,
    this.originLabel,
    this.destinationLabel,
  });

  final FlightOffer offer;

  /// Opens the read-only preview. No network call, no commitment — a rider
  /// can compare several offers in detail without burning confirm calls.
  final VoidCallback onTap;

  /// Enters the booking wizard, which confirms the offer.
  final VoidCallback onSelect;

  /// Full airport name for the origin (falls back to the IATA code).
  final String? originLabel;

  /// Full airport name for the destination (falls back to the IATA code).
  final String? destinationLabel;

  /// Height of the fare stub (below the tear line). Drives the notch offset.
  static const double _stubHeight = 72;

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

  static String _placeLabel(String? name, String iataCode) {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return iataCode;
  }

  /// Single-leg offers get no label. Two legs read as outbound and return;
  /// more than two is a multi-city itinerary, so legs are simply numbered.
  static String? _legLabel(AppLocalizations l10n, int index, int total) {
    if (total < 2) return null;
    if (total == 2) {
      return index == 0 ? l10n.flightLegOutbound : l10n.flightLegReturn;
    }
    return l10n.flightLegLabel(index + 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final headerSegment = offer.journeys.first.segments.first;
    final priceText = offer.totalAmount.toStringAsFixed(0);

    const shape = FlightTicketBorder(
      radius: AppRadius.xl,
      notchRadius: 10,
      notchOffsetFromBottom: _stubHeight,
      dashColor: AppColors.border,
    );

    return Material(
      color: AppColors.bgElevated,
      shape: shape,
      elevation: 6,
      shadowColor: AppColors.primary.withValues(alpha: 0.22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(segment: headerSegment),
                  const SizedBox(height: AppSpacing.md),
                  for (var i = 0; i < offer.journeys.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.sm),
                    _JourneyBlock(
                      journey: offer.journeys[i],
                      label: _legLabel(l10n, i, offer.journeys.length),
                      originLabel: i == 0 ? originLabel : null,
                      destinationLabel: i == 0 ? destinationLabel : null,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              height: _stubHeight,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  0,
                ),
                child: Center(
                  child: _FareStub(
                    fareLabel: l10n.tripResultsFareLabel,
                    priceText: priceText,
                    currency: offer.currency,
                    detailsLabel: l10n.flightViewDetails,
                    selectLabel: l10n.flightSelectThisFlight,
                    onDetails: onTap,
                    onSelect: onSelect,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One leg of an offer: its route row, duration and stops. Repeated per
/// journey — an offer is priced as a whole trip, so all of its legs belong on
/// the same card.
class _JourneyBlock extends StatelessWidget {
  const _JourneyBlock({
    required this.journey,
    required this.label,
    this.originLabel,
    this.destinationLabel,
  });

  final FlightJourney journey;

  /// Null for a single-leg offer, where a label would be noise.
  final String? label;
  final String? originLabel;
  final String? destinationLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final firstSegment = journey.segments.first;
    final lastSegment = journey.segments.last;
    final totalMinutes =
        journey.segments.fold<int>(0, (sum, s) => sum + s.flightTimeInMinutes);
    final stopsLabel = journey.numberOfStops == 0
        ? l10n.flightDirect
        : journey.numberOfStops == 1
            ? l10n.flightOneStop
            : l10n.flightStopsCount(journey.numberOfStops);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
            child: Text(
              label!,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        _Timeline(
          departTime: FlightOfferCard._time(firstSegment.departureDateTime),
          arriveTime: FlightOfferCard._time(lastSegment.arrivalDateTime),
          origin: FlightOfferCard._placeLabel(originLabel, journey.origin),
          destination: FlightOfferCard._placeLabel(
            destinationLabel,
            journey.destination,
          ),
          duration: FlightOfferCard._duration(totalMinutes),
          stopsLabel: stopsLabel,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.segment});

  final FlightSegment segment;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (segment.operatingCarrierLogo != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image.network(
              segment.operatingCarrierLogo!,
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
        Expanded(
          child: Text(
            segment.operatingCarrierName ?? segment.operatingCarrierCode,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.title.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.departTime,
    required this.arriveTime,
    required this.origin,
    required this.destination,
    required this.duration,
    required this.stopsLabel,
  });

  final String departTime;
  final String arriveTime;
  final String origin;
  final String destination;
  final String duration;
  final String stopsLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 1,
              child: _TimeCell(
                time: departTime,
                alignment: AlignmentDirectional.centerStart,
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: _ConnectorWithDuration(
                  duration: duration,
                  stopsLabel: stopsLabel,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: _TimeCell(
                time: arriveTime,
                alignment: AlignmentDirectional.centerEnd,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: Text(
                origin,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Expanded(flex: 2, child: SizedBox.shrink()),
            Expanded(
              flex: 1,
              child: Text(
                destination,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.time,
    required this.alignment,
  });

  final String time;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Text(
        time,
        style: AppTypography.title.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ConnectorWithDuration extends StatelessWidget {
  const _ConnectorWithDuration({
    required this.duration,
    required this.stopsLabel,
  });

  final String duration;
  final String stopsLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LtrText(
          duration,
          style: AppTypography.caption.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        const _ConnectorLine(),
        const SizedBox(height: AppSpacing.xs),
        Text(
          stopsLabel,
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ConnectorLine extends StatelessWidget {
  const _ConnectorLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _dot(AppColors.primary),
        const Expanded(child: Divider(color: AppColors.hairline, height: 1)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Icon(
            PhosphorIconsLight.caretRight,
            size: 14,
            color: AppColors.primary,
          ),
        ),
        const Expanded(child: Divider(color: AppColors.hairline, height: 1)),
        _dot(AppColors.secondary),
      ],
    );
  }

  Widget _dot(Color color) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _FareStub extends StatelessWidget {
  const _FareStub({
    required this.fareLabel,
    required this.priceText,
    required this.currency,
    required this.detailsLabel,
    required this.selectLabel,
    required this.onDetails,
    required this.onSelect,
  });

  final String fareLabel;
  final String priceText;
  final String currency;
  final String detailsLabel;
  final String selectLabel;
  final VoidCallback onDetails;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fareLabel,
                style: AppTypography.overline.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: priceText,
                      style: AppTypography.h2.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: ' $currency',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        TextButton(
          onPressed: onDetails,
          child: Text(
            detailsLabel,
            style: AppTypography.caption
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
        Flexible(
          child: PrimaryButton(
            label: selectLabel,
            compact: true,
            onPressed: onSelect,
          ),
        ),
      ],
    );
  }
}
