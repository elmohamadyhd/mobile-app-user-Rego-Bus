import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/date_formatting.dart';
import 'package:safaria/features/bus/domain/entities/bus_stop.dart';
import 'package:safaria/features/bus/domain/entities/bus_trip.dart';
import 'package:safaria/features/bus/domain/entities/trip_highlight.dart';
import 'package:safaria/features/bus/presentation/widgets/amenity_icons_row.dart';
import 'package:safaria/features/bus/presentation/widgets/operator_avatar.dart';
import 'package:safaria/features/bus/presentation/widgets/ticket_border.dart';
import 'package:safaria/features/bus/presentation/widgets/trip_stops_sheet.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/ltr_text.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Boarding-pass styled result card for a single [BusTripSummary].
///
/// The card is split by a perforated tear line: the trip info sits above it,
/// the fare stub below. See [TicketBorder] for the notch + dash geometry.
/// Local boarding/drop-off picks update the card until [onSelect] fires.
class TripCard extends StatefulWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.onSelect,
    this.loading = false,
    this.highlight,
  });

  final BusTripSummary trip;
  final void Function({required BusStop from, required BusStop to}) onSelect;

  /// Shows a spinner in the Select button and disables it.
  /// Other cards in the list stay fully interactive — see [_SelectButton].
  final bool loading;

  /// Optional cheapest / fastest marks for the header pills.
  final TripHighlights? highlight;

  /// Height of the fare stub (below the tear line). Drives the notch offset.
  static const double _stubHeight = 68;

  @override
  State<TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<TripCard> {
  late BusStop _from;
  late BusStop _to;

  @override
  void initState() {
    super.initState();
    _resetStops(widget.trip);
  }

  @override
  void didUpdateWidget(covariant TripCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip.id != widget.trip.id) {
      _resetStops(widget.trip);
    }
  }

  void _resetStops(BusTripSummary trip) {
    _from = trip.defaultBoardingStop;
    _to = trip.terminalDropoffStop;
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  DateTime get _departTime => _from.arrivalAt ?? widget.trip.dateTime;

  DateTime get _arriveTime => _to.arrivalAt ?? widget.trip.dateTime;

  String get _departLabel => _formatTime(_departTime);

  String get _arriveLabel => _formatTime(_arriveTime);

  String get _durationLabel {
    final diff = _arriveTime.difference(_departTime).inMinutes;
    final mins = diff > 0 ? diff : 0;
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  int get _fareEgp => _to.finalPrice.round();

  void _emitSelect() {
    if (widget.loading) return;
    widget.onSelect(from: _from, to: _to);
  }

  Future<void> _openStopsSheet() async {
    await showTripStopsSheet(
      context,
      trip: widget.trip,
      initialFrom: _from,
      initialTo: _to,
      onChanged: ({required from, required to}) {
        if (!mounted) return;
        setState(() {
          _from = from;
          _to = to;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toString();
    final departDateLabel = formatSearchDateCell(_departTime, localeName);
    final arriveDateLabel = isSameDay(_departTime, _arriveTime)
        ? null
        : formatSearchDateCell(_arriveTime, localeName);
    const shape = TicketBorder(
      radius: AppRadius.xl,
      notchRadius: 10,
      notchOffsetFromBottom: TripCard._stubHeight,
      dashColor: AppColors.border,
    );

    return Material(
      color: AppColors.bgElevated,
      shape: shape,
      elevation: 6,
      shadowColor: AppColors.primary.withValues(alpha: 0.22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(trip: widget.trip, highlight: widget.highlight),
                const SizedBox(height: AppSpacing.md),
                _Timeline(
                  trip: widget.trip,
                  l10n: l10n,
                  from: _from,
                  to: _to,
                  departLabel: _departLabel,
                  arriveLabel: _arriveLabel,
                  durationLabel: _durationLabel,
                  departDateLabel: departDateLabel,
                  arriveDateLabel: arriveDateLabel,
                  onStopsTap:
                      widget.trip.stopsCount > 0 ? _openStopsSheet : null,
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: TripCard._stubHeight),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Center(
                child: _FareStub(
                  fareEgp: _fareEgp,
                  currency: widget.trip.currency,
                  l10n: l10n,
                  onTap: _emitSelect,
                  loading: widget.loading,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.trip, this.highlight});

  final BusTripSummary trip;
  final TripHighlights? highlight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final marks = highlight;
    final serviceClass = trip.serviceClass.trim();
    // Name owns the flex; badges take intrinsic width only so dual
    // cheapest/fastest pills cannot crush the operator label.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OperatorAvatar(trip: trip),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                trip.operatorName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.title.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (serviceClass.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  serviceClass,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (trip.features.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                AmenityIconsRow(features: trip.features),
              ],
            ],
          ),
        ),
        if (marks != null && marks.hasAny) ...[
          const SizedBox(width: AppSpacing.sm),
          _HighlightBadges(highlight: marks, l10n: l10n),
        ],
      ],
    );
  }
}

class _HighlightBadges extends StatelessWidget {
  const _HighlightBadges({required this.highlight, required this.l10n});

  final TripHighlights highlight;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final pills = <Widget>[
      if (highlight.isCheapest)
        _HighlightBadge(
          label: l10n.tripResultsSortCheapest,
          bg: AppColors.secondaryTint,
          fg: AppColors.onSecondary,
        ),
      if (highlight.isFastest)
        _HighlightBadge(
          label: l10n.tripResultsHighlightFastest,
          bg: AppColors.success.withValues(alpha: 0.14),
          fg: AppColors.success,
        ),
    ];
    final semanticsLabel = [
      if (highlight.isCheapest) l10n.tripResultsSortCheapest,
      if (highlight.isFastest) l10n.tripResultsHighlightFastest,
    ].join(', ');

    return Semantics(
      label: semanticsLabel,
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: pills,
      ),
    );
  }
}

class _HighlightBadge extends StatelessWidget {
  const _HighlightBadge({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Timeline ──────────────────────────────────────────────────────────────────

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.trip,
    required this.l10n,
    required this.from,
    required this.to,
    required this.departLabel,
    required this.arriveLabel,
    required this.durationLabel,
    required this.departDateLabel,
    this.arriveDateLabel,
    this.onStopsTap,
  });

  final BusTripSummary trip;
  final AppLocalizations l10n;
  final BusStop from;
  final BusStop to;
  final String departLabel;
  final String arriveLabel;
  final String durationLabel;
  final String departDateLabel;
  final String? arriveDateLabel;
  final VoidCallback? onStopsTap;

  @override
  Widget build(BuildContext context) {
    // Stations first, then clocks — riders scan place then schedule.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: _StationCell(
                cityName: from.cityName,
                station: from.name,
                textAlign: TextAlign.start,
                accentColor: AppColors.primary,
              ),
            ),
            const Expanded(flex: 2, child: SizedBox.shrink()),
            Expanded(
              flex: 1,
              child: _StationCell(
                cityName: to.cityName,
                station: to.name,
                textAlign: TextAlign.end,
                accentColor: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 1,
              child: _TimeCell(
                time: departLabel,
                date: departDateLabel,
                alignment: AlignmentDirectional.centerStart,
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: _ConnectorWithDuration(duration: durationLabel),
              ),
            ),
            Expanded(
              flex: 1,
              child: _TimeCell(
                time: arriveLabel,
                date: arriveDateLabel,
                alignment: AlignmentDirectional.centerEnd,
              ),
            ),
          ],
        ),
        if (trip.stopsCount > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            child: _StopsChip(
              stopsCount: trip.stopsCount,
              l10n: l10n,
              onTap: onStopsTap,
            ),
          ),
        ],
      ],
    );
  }
}

/// Duration centered above the route connector line.
class _ConnectorWithDuration extends StatelessWidget {
  const _ConnectorWithDuration({required this.duration});

  final String duration;

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
      ],
    );
  }
}

/// Compact centered pill — tap opens the stops sheet.
class _StopsChip extends StatelessWidget {
  const _StopsChip({
    required this.stopsCount,
    required this.l10n,
    this.onTap,
  });

  final int stopsCount;
  final AppLocalizations l10n;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = l10n.tripResultsStopsCount(stopsCount);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.primaryTint,
        shape: StadiumBorder(
          side: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.28),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: AppTypography.overline.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                const Icon(
                  PhosphorIconsLight.caretDown,
                  size: 14,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.time,
    required this.alignment,
    this.date,
  });

  final String time;
  final String? date;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final isEnd = alignment == AlignmentDirectional.centerEnd;
    final label = date == null ? time : '$time, $date';
    return Align(
      alignment: alignment,
      child: Semantics(
        label: label,
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                isEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                time,
                style: AppTypography.title.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (date != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  date!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A route endpoint: the governorate/city sits above the stop name so riders
/// scan the macro destination first, then the specific stop below it.
class _StationCell extends StatelessWidget {
  const _StationCell({
    required this.cityName,
    required this.station,
    required this.textAlign,
    required this.accentColor,
  });

  final String cityName;
  final String station;
  final TextAlign textAlign;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final crossAlign = textAlign == TextAlign.start
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.end;

    return Column(
      crossAxisAlignment: crossAlign,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cityName.trim().isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIconsLight.mapPin, size: 11, color: accentColor),
              const SizedBox(width: AppSpacing.xxs),
              Flexible(
                child: Text(
                  cityName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.overline.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        if (cityName.trim().isNotEmpty) const SizedBox(height: AppSpacing.xs),
        Text(
          station,
          textAlign: textAlign,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(
            color: AppColors.textPrimary,
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
    // Phosphor carets set matchTextDirection — Icon already mirrors in RTL.
    // An extra Transform.flip would cancel that and point the wrong way.
    return const Row(
      children: [
        _ConnectorDot(AppColors.primary),
        Expanded(child: Divider(color: AppColors.hairline, height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Icon(
            PhosphorIconsLight.caretRight,
            size: 14,
            color: AppColors.primary,
          ),
        ),
        Expanded(child: Divider(color: AppColors.hairline, height: 1)),
        _ConnectorDot(AppColors.secondary),
      ],
    );
  }
}

class _ConnectorDot extends StatelessWidget {
  const _ConnectorDot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ── Fare stub ─────────────────────────────────────────────────────────────────

class _FareStub extends StatelessWidget {
  const _FareStub({
    required this.fareEgp,
    required this.currency,
    required this.l10n,
    required this.onTap,
    this.loading = false,
  });

  final int fareEgp;
  final String currency;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
              const SizedBox(height: AppSpacing.xxs),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$fareEgp',
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
        const SizedBox(width: AppSpacing.md),
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
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
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
                  style: AppTypography.body.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}
