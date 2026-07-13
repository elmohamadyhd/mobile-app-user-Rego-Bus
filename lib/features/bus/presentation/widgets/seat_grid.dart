import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/seat_map.dart';

/// Shared square size for every grid cell — seats, icon markers (driver,
/// door, WC), and blank aisle fillers — so rows stay aligned regardless of
/// what each cell renders.
const double _cellSize = 36;

/// Bus-body card containing the seat grid: each row of [SeatMapCell]s.
/// `SeatMapCellKind.space` cells (the aisle) are rendered as blank filler —
/// rendered as blank filler — no icon, no fill — so the walkway reads as
/// genuinely empty space rather than a decorated tile.
class SeatGrid extends StatelessWidget {
  const SeatGrid({
    super.key,
    required this.seatMap,
    required this.selectedSeats,
    required this.onToggle,
  });

  final SeatMap seatMap;
  final List<String> selectedSeats;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final columns = seatMap.salon.columns > 0 ? seatMap.salon.columns : 1;
    final rows = <List<SeatMapCell>>[];
    for (var i = 0; i < seatMap.cells.length; i += columns) {
      final end = (i + columns) > seatMap.cells.length
          ? seatMap.cells.length
          : i + columns;
      rows.add(seatMap.cells.sublist(i, end));
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 26,
            spreadRadius: -16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        children: [
          for (final row in rows) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final cell in row)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _SeatCellView(
                      cell: cell,
                      selected:
                          cell.id != null && selectedSeats.contains(cell.id),
                      onTap: _tapHandler(cell),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  VoidCallback? _tapHandler(SeatMapCell cell) {
    if (cell.kind != SeatMapCellKind.available || cell.id == null) return null;
    return () => onToggle(cell.id!);
  }
}

class _SeatCellView extends StatelessWidget {
  const _SeatCellView({
    required this.cell,
    required this.selected,
    required this.onTap,
  });

  final SeatMapCell cell;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    switch (cell.kind) {
      case SeatMapCellKind.space:
        // The aisle — stays fully blank (no icon, no fill) so it reads as
        // walkable space rather than a UI element.
        return const SizedBox(width: _cellSize, height: _cellSize);
      case SeatMapCellKind.driver:
        return const _MarkerCell(icon: AppIcons.busFront);
      case SeatMapCellKind.door:
        return const _MarkerCell(icon: AppIcons.logout);
      case SeatMapCellKind.wc:
        return const _MarkerCell(icon: AppIcons.amenityWater);
      case SeatMapCellKind.available:
      case SeatMapCellKind.booked:
        return _SeatButton(cell: cell, selected: selected, onTap: onTap);
    }
  }
}

/// Non-seat informational marker (driver, door, WC) — a small tinted circle
/// so it reads clearly as "not a seat" without being mistaken for the aisle.
class _MarkerCell extends StatelessWidget {
  const _MarkerCell({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _cellSize,
      height: _cellSize,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.bgBase,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: AppColors.textMuted),
    );
  }
}

class _SeatButton extends StatelessWidget {
  const _SeatButton({
    required this.cell,
    required this.selected,
    required this.onTap,
  });

  final SeatMapCell cell;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final booked = cell.kind == SeatMapCellKind.booked;
    final Color bg;
    final Color? borderColor;
    final Color textColor;
    if (booked) {
      bg = const Color(0xFFDCE3F0);
      borderColor = null;
      textColor = AppColors.textMuted;
    } else if (selected) {
      bg = AppColors.primary;
      borderColor = null;
      textColor = AppColors.onPrimary;
    } else {
      bg = AppColors.bgElevated;
      borderColor = AppColors.hairline;
      textColor = AppColors.textSecondary;
    }

    final label = cell.seatNo ?? cell.id ?? '';
    final radius = BorderRadius.circular(AppRadius.md);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: _cellSize,
          height: _cellSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: borderColor != null ? Border.all(color: borderColor) : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
