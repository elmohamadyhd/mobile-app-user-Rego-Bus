import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/presentation/widgets/amenity_icons_row.dart';
import 'package:rego/features/bus/presentation/widgets/operator_avatar.dart';
import 'package:rego/features/bus/presentation/widgets/ticket_border.dart';
import 'package:rego/l10n/app_localizations.dart';

/// Boarding-pass styled result card for a single [BusTripSummary].
///
/// The card is split by a perforated tear line: the trip info sits above it,
/// the fare stub below. See [TicketBorder] for the notch + dash geometry.
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.onTap,
    this.loading = false,
  });

  final BusTripSummary trip;
  final VoidCallback onTap;

  /// Shows a spinner in the Select button and disables this card's tap.
  /// Other cards in the list stay fully interactive — see [_SelectButton].
  final bool loading;

  /// Height of the fare stub (below the tear line). Drives the notch offset.
  static const double _stubHeight = 64;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const shape = TicketBorder(
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
        customBorder: shape,
        onTap: loading ? null : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(trip: trip, l10n: l10n),
                  const SizedBox(height: AppSpacing.md),
                  _Timeline(trip: trip),
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
                child: _FareStub(
                  trip: trip,
                  l10n: l10n,
                  onTap: onTap,
                  loading: loading,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.trip, required this.l10n});

  final BusTripSummary trip;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final bool lowSeats = trip.seatsLeft < 3;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OperatorAvatar(trip: trip),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: trip.operatorName,
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (trip.serviceClass.trim().isNotEmpty)
                      TextSpan(
                        text: '  ·  ${trip.serviceClass}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              AmenityIconsRow(amenities: trip.amenities),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _SeatsPill(seatsLeft: trip.seatsLeft, lowSeats: lowSeats, l10n: l10n),
      ],
    );
  }
}

class _SeatsPill extends StatelessWidget {
  const _SeatsPill({
    required this.seatsLeft,
    required this.lowSeats,
    required this.l10n,
  });

  final int seatsLeft;
  final bool lowSeats;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: lowSeats
            ? AppColors.error.withValues(alpha: 0.12)
            : AppColors.secondaryTint,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        l10n.bookingSeatsLeft(seatsLeft),
        style: AppTypography.caption.copyWith(
          color: lowSeats ? AppColors.error : AppColors.onSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Timeline ──────────────────────────────────────────────────────────────────

class _Timeline extends StatelessWidget {
  const _Timeline({required this.trip});

  final BusTripSummary trip;

  @override
  Widget build(BuildContext context) {
    final int boardingExtra = trip.boardingStops.length - 1;
    final int dropoffExtra = trip.dropoffStops.length - 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: _Endpoint(
            time: trip.departLabel,
            station: trip.defaultBoardingStop.name,
            extra: boardingExtra,
            alignment: CrossAxisAlignment.start,
            textAlign: TextAlign.start,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: _Connector(durationLabel: trip.durationLabel),
          ),
        ),
        Flexible(
          child: _Endpoint(
            time: trip.arriveLabel,
            station: trip.defaultDropoffStop.name,
            extra: dropoffExtra,
            alignment: CrossAxisAlignment.end,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({
    required this.time,
    required this.station,
    required this.extra,
    required this.alignment,
    required this.textAlign,
  });

  final String time;
  final String station;
  final int extra;
  final CrossAxisAlignment alignment;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          time,
          style: AppTypography.h2.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                station,
                textAlign: textAlign,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
            ),
            if (extra > 0) ...[
              const SizedBox(width: 5),
              _StationCountChip(extra: extra),
            ],
          ],
        ),
      ],
    );
  }
}

/// Small pill showing how many alternative boarding/drop-off stations exist
/// beyond the default one (e.g. `+3`).
class _StationCountChip extends StatelessWidget {
  const _StationCountChip({required this.extra});

  final int extra;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '+$extra',
        style: AppTypography.overline.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.durationLabel});

  final String durationLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            _dot(AppColors.primary),
            const Expanded(child: Divider(color: AppColors.hairline, height: 1)),
            _dot(AppColors.secondary),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          durationLabel,
          style: AppTypography.caption.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _dot(Color color) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

// ── Fare stub ─────────────────────────────────────────────────────────────────

class _FareStub extends StatelessWidget {
  const _FareStub({
    required this.trip,
    required this.l10n,
    required this.onTap,
    this.loading = false,
  });

  final BusTripSummary trip;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.tripResultsFareLabel,
                style: AppTypography.overline.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 1),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${trip.priceEgp}',
                      style: AppTypography.h1.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: ' ${trip.currency}',
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
        const SizedBox(width: AppSpacing.sm),
        _SelectButton(l10n: l10n, onTap: onTap, loading: loading),
      ],
    );
  }
}

class _SelectButton extends StatelessWidget {
  const _SelectButton({
    required this.l10n,
    required this.onTap,
    this.loading = false,
  });

  final AppLocalizations l10n;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.input),
      elevation: 4,
      shadowColor: AppColors.primary.withValues(alpha: 0.5),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.input),
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation(AppColors.onPrimary),
                  ),
                )
              : Text(
                  l10n.bookingSelect,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    );
  }
}
