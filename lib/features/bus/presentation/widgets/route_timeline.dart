import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/l10n/app_localizations.dart';

/// Vertical route timeline split into two labeled, single-tap zones: board
/// candidates (origin city) on top, drop-off candidates (destination city)
/// below. Replaces the winding-road picker — a single tap on a row in its
/// zone both focuses and selects it (no long-press / role menu), and
/// drop-off rows show their own fare so the fare-per-stop relationship stays
/// visible while choosing.
class RouteTimeline extends StatelessWidget {
  const RouteTimeline({
    super.key,
    required this.boardingStops,
    required this.dropoffStops,
    required this.selectedFrom,
    required this.selectedTo,
    required this.currency,
    required this.onBoardSelected,
    required this.onDropoffSelected,
  });

  final List<BusStop> boardingStops;
  final List<BusStop> dropoffStops;
  final BusStop selectedFrom;
  final BusStop selectedTo;
  final String currency;
  final ValueChanged<BusStop> onBoardSelected;
  final ValueChanged<BusStop> onDropoffSelected;

  /// Nulls sort first — a missing `arrivalAt` is treated as the
  /// earliest/base time (same convention used across the bus feature), so
  /// the default stop isn't buried at the end of its zone.
  static int _byArrival(BusStop a, BusStop b) {
    if (a.arrivalAt == null && b.arrivalAt == null) return 0;
    if (a.arrivalAt == null) return -1;
    if (b.arrivalAt == null) return 1;
    return a.arrivalAt!.compareTo(b.arrivalAt!);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final board = [...boardingStops]..sort(_byArrival);
    final drop = [...dropoffStops]..sort(_byArrival);

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
            _ZoneHeader(
                label: l10n.tripDetailBoardAt, color: AppColors.primary),
            for (var i = 0; i < board.length; i++)
              _TimelineRow(
                stop: board[i],
                accent: AppColors.primary,
                isSelected: board[i].locationId == selectedFrom.locationId,
                isDimmed: board[i].locationId != selectedFrom.locationId,
                selectedPill: l10n.tripDetailBoardHere,
                showLine: i < board.length - 1 || drop.isNotEmpty,
                onTap: () => onBoardSelected(board[i]),
              ),
            const SizedBox(height: AppSpacing.md),
            _ZoneHeader(
              label: l10n.tripDetailDropOffAt,
              color: AppColors.secondary,
            ),
            for (var i = 0; i < drop.length; i++)
              _TimelineRow(
                stop: drop[i],
                accent: AppColors.secondary,
                isSelected: drop[i].locationId == selectedTo.locationId,
                isDimmed: drop[i].locationId != selectedTo.locationId,
                selectedPill: l10n.tripDetailDropOffHere,
                showLine: i < drop.length - 1,
                fareLabel: '${drop[i].finalPrice.round()} $currency',
                onTap: () => onDropoffSelected(drop[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _ZoneHeader extends StatelessWidget {
  const _ZoneHeader({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Text(
        label,
        style: AppTypography.overline.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.stop,
    required this.accent,
    required this.isSelected,
    required this.isDimmed,
    required this.selectedPill,
    required this.showLine,
    required this.onTap,
    this.fareLabel,
  });

  final BusStop stop;
  final Color accent;
  final bool isSelected;
  final bool isDimmed;
  final String selectedPill;
  final bool showLine;
  final String? fareLabel;
  final VoidCallback onTap;

  String? _formatTime(DateTime? dt) {
    if (dt == null) return null;
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final time = _formatTime(stop.arrivalAt);
    final textColor = isSelected
        ? accent
        : (isDimmed ? AppColors.textMuted : AppColors.textPrimary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  Container(
                    width: isSelected ? 14 : 10,
                    height: isSelected ? 14 : 10,
                    decoration: BoxDecoration(
                      color: isSelected ? accent : AppColors.bgElevated,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? accent
                            : (isDimmed ? AppColors.hairline : accent),
                        width: 2,
                      ),
                    ),
                  ),
                  if (showLine)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isSelected
                            ? accent.withValues(alpha: 0.4)
                            : AppColors.hairline,
                        margin: const EdgeInsets.symmetric(vertical: 2),
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
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    stop.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.body.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: AppSpacing.sm),
                                  _SelectedPill(
                                    label: selectedPill,
                                    color: accent,
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              stop.cityName,
                              style: AppTypography.caption.copyWith(
                                color: isDimmed
                                    ? AppColors.textMuted
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (time != null)
                            Text(
                              time,
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDimmed
                                    ? AppColors.textMuted
                                    : AppColors.textSecondary,
                              ),
                            ),
                          if (fareLabel != null)
                            Text(
                              fareLabel!,
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ],
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

class _SelectedPill extends StatelessWidget {
  const _SelectedPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTypography.overline.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
