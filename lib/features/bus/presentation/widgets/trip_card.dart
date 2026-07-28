import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_icons.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/domain/entities/bus_stop.dart';
import 'package:safaria/features/bus/domain/entities/bus_trip.dart';
import 'package:safaria/features/bus/presentation/widgets/amenity_icons_row.dart';
import 'package:safaria/features/bus/presentation/widgets/operator_avatar.dart';
import 'package:safaria/features/bus/presentation/widgets/ticket_border.dart';
import 'package:safaria/features/bus/presentation/widgets/trip_stops_sheet.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/ltr_text.dart';

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
  });

  final BusTripSummary trip;
  final void Function({required BusStop from, required BusStop to}) onSelect;

  /// Shows a spinner in the Select button and disables this card's tap.
  /// Other cards in the list stay fully interactive — see [_SelectButton].
  final bool loading;

  /// Operator row block — matches [OperatorAvatar] default size.
  static const double _headerHeight = 42;

  /// Slot for [AppTypography.h2] departure/arrival times.
  static const double _timeRowHeight = 28;

  /// Duration label row under the connector.
  static const double _durationRowHeight = 20;

  /// Governorate/city label pinned above the stop name.
  static const double _cityRowHeight = 16;

  /// Two-line station name.
  static const double _stationRowHeight = 34;

  /// Height of the fare stub (below the tear line). Drives the notch offset.
  static const double _stubHeight = 64;

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
      child: InkWell(
        customBorder: shape,
        onTap: widget.loading ? null : _emitSelect,
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
                  _Header(trip: widget.trip),
                  const SizedBox(height: AppSpacing.md),
                  _Timeline(
                    trip: widget.trip,
                    l10n: l10n,
                    from: _from,
                    to: _to,
                    departLabel: _departLabel,
                    arriveLabel: _arriveLabel,
                    durationLabel: _durationLabel,
                    onStopsTap:
                        widget.trip.stopsCount > 0 ? _openStopsSheet : null,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: TripCard._stubHeight,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  0,
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
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.trip});

  final BusTripSummary trip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TripCard._headerHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          OperatorAvatar(trip: trip),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        trip.operatorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.title.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (trip.serviceClass.trim().isNotEmpty) ...[
                      Text(
                        '  ·  ',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          trip.serviceClass,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                AmenityIconsRow(amenities: trip.amenities),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
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
    this.onStopsTap,
  });

  final BusTripSummary trip;
  final AppLocalizations l10n;
  final BusStop from;
  final BusStop to;
  final String departLabel;
  final String arriveLabel;
  final String durationLabel;
  final VoidCallback? onStopsTap;

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
                time: departLabel,
                alignment: AlignmentDirectional.topStart,
              ),
            ),
            const Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: SizedBox(
                  height: TripCard._timeRowHeight,
                  child: Center(child: _ConnectorLine()),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: _TimeCell(
                time: arriveLabel,
                alignment: AlignmentDirectional.topEnd,
              ),
            ),
          ],
        ),
        SizedBox(
          height: TripCard._durationRowHeight,
          child: Row(
            children: [
              const Expanded(flex: 1, child: SizedBox.shrink()),
              Expanded(
                flex: 2,
                child: Center(
                  child: _DurationStopsLabel(
                    duration: durationLabel,
                    stopsCount: trip.stopsCount,
                    l10n: l10n,
                    onStopsTap: onStopsTap,
                  ),
                ),
              ),
              const Expanded(flex: 1, child: SizedBox.shrink()),
            ],
          ),
        ),
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
      ],
    );
  }
}

/// Duration (Latin) and stops count as separate widgets so BiDi does not
/// reorder Arabic around the LTR duration run (e.g. `6 · 3h 45m محطات`).
class _DurationStopsLabel extends StatelessWidget {
  const _DurationStopsLabel({
    required this.duration,
    required this.stopsCount,
    required this.l10n,
    this.onStopsTap,
  });

  final String duration;
  final int stopsCount;
  final AppLocalizations l10n;
  final VoidCallback? onStopsTap;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.caption.copyWith(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w600,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: LtrText(
            duration,
            style: style,
            textAlign: TextAlign.center,
          ),
        ),
        if (stopsCount > 0) ...[
          Text(' · ', style: style),
          Flexible(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onStopsTap,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xxs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          l10n.tripResultsStopsCount(stopsCount),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: style,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      const Icon(
                        AppIcons.chevronDown,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({required this.time, required this.alignment});

  final String time;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TripCard._timeRowHeight,
      child: Align(
        alignment: alignment,
        child: Text(
          time,
          style: AppTypography.h2.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
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
      children: [
        SizedBox(
          height: TripCard._cityRowHeight,
          child: cityName.trim().isEmpty
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.locationTo, size: 11, color: accentColor),
                    const SizedBox(width: AppSpacing.xxs),
                    Flexible(
                      child: Text(
                        cityName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        SizedBox(
          height: TripCard._stationRowHeight,
          child: Text(
            station,
            textAlign: textAlign,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.overline.copyWith(color: AppColors.textMuted),
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
              const SizedBox(height: 1),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$fareEgp',
                      style: AppTypography.h1.copyWith(
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
