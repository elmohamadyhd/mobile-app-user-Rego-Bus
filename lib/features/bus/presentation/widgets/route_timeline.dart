import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/l10n/app_localizations.dart';

/// Full ordered route for a trip, rendered as one vertical timeline: the
/// origin city's boarding stops (blue, tap to board) followed by the
/// destination city's drop-off stops (amber, tap to get off), each sorted by
/// arrival time. The segment between the chosen board and drop-off stop is
/// emphasized; stops outside it dim but stay tappable to re-pick.
class RouteTimeline extends StatelessWidget {
  const RouteTimeline({
    super.key,
    required this.boardingStops,
    required this.dropoffStops,
    required this.selectedFrom,
    required this.selectedTo,
    required this.onBoardSelected,
    required this.onDropoffSelected,
  });

  final List<BusStop> boardingStops;
  final List<BusStop> dropoffStops;
  final BusStop selectedFrom;
  final BusStop selectedTo;
  final ValueChanged<BusStop> onBoardSelected;
  final ValueChanged<BusStop> onDropoffSelected;

  /// Nulls sort first within their group — a missing `arrivalAt` means "no
  /// estimate yet", which the domain already treats as the earliest/base
  /// reference time (see `BusTripSummary.departTime`'s `?? dateTime`
  /// fallback). Real fixtures commonly have the *default* boarding stop with
  /// a null arrival, so pushing nulls to the end would wrongly bury the
  /// primary origin stop at the bottom of the timeline.
  static int _byArrival(BusStop a, BusStop b) {
    if (a.arrivalAt == null && b.arrivalAt == null) return 0;
    if (a.arrivalAt == null) return -1;
    if (b.arrivalAt == null) return 1;
    return a.arrivalAt!.compareTo(b.arrivalAt!);
  }

  List<_RouteEntry> _buildEntries() {
    final board = [...boardingStops]..sort(_byArrival);
    final drop = [...dropoffStops]..sort(_byArrival);
    return [
      for (final s in board) _RouteEntry(stop: s, isBoardCandidate: true),
      for (final s in drop) _RouteEntry(stop: s, isBoardCandidate: false),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = _buildEntries();
    final boardIndex = entries.indexWhere(
      (e) => e.isBoardCandidate && e.stop.locationId == selectedFrom.locationId,
    );
    final dropIndex = entries.indexWhere(
      (e) => !e.isBoardCandidate && e.stop.locationId == selectedTo.locationId,
    );
    final activeStart = boardIndex == -1 ? 0 : boardIndex;
    final activeEnd = dropIndex == -1 ? entries.length - 1 : dropIndex;

    return Material(
      color: AppColors.bgElevated,
      borderRadius: BorderRadius.circular(AppRadius.card),
      elevation: 3,
      shadowColor: AppColors.primary.withValues(alpha: 0.1),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tripDetailRouteSection,
              style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < entries.length; i++)
              _RouteRow(
                entry: entries[i],
                isSelected: i == boardIndex || i == dropIndex,
                isDimmed: i < activeStart || i > activeEnd,
                isLast: i == entries.length - 1,
                connectorColor: (i >= activeStart && i < activeEnd)
                    ? AppColors.primary
                    : AppColors.hairline,
                l10n: l10n,
                onTap: () => entries[i].isBoardCandidate
                    ? onBoardSelected(entries[i].stop)
                    : onDropoffSelected(entries[i].stop),
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteEntry {
  const _RouteEntry({required this.stop, required this.isBoardCandidate});
  final BusStop stop;
  final bool isBoardCandidate;
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.entry,
    required this.isSelected,
    required this.isDimmed,
    required this.isLast,
    required this.connectorColor,
    required this.l10n,
    required this.onTap,
  });

  final _RouteEntry entry;
  final bool isSelected;
  final bool isDimmed;
  final bool isLast;
  final Color connectorColor;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  Color get _accent =>
      entry.isBoardCandidate ? AppColors.primary : AppColors.secondary;

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = isDimmed ? AppColors.hairline : _accent;
    final nameColor = isDimmed ? AppColors.textMuted : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  width: isSelected ? 14 : 10,
                  height: isSelected ? 14 : 10,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? dotColor : AppColors.bgElevated,
                    border: Border.all(color: dotColor, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: connectorColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.stop.name,
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: nameColor,
                            ),
                          ),
                          if (entry.stop.cityName.isNotEmpty)
                            Text(
                              entry.stop.cityName,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          if (isSelected)
                            Text(
                              entry.isBoardCandidate
                                  ? l10n.tripDetailBoardHere
                                  : l10n.tripDetailDropOffHere,
                              style: AppTypography.caption.copyWith(
                                color: _accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (entry.stop.arrivalAt != null)
                      Text(
                        _formatTime(entry.stop.arrivalAt!),
                        style: AppTypography.caption.copyWith(
                          color: isDimmed
                              ? AppColors.textMuted
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
