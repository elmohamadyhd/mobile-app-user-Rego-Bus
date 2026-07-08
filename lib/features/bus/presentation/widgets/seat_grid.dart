import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/seat_map.dart';

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

    return Column(
      children: [
        const Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Icon(AppIcons.busFront, color: AppColors.textMuted, size: 28),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final row in rows) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final cell in row)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _SeatCellView(
                    cell: cell,
                    selected: cell.id != null && selectedSeats.contains(cell.id),
                    onTap: _tapHandler(cell),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
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
    if (_isNonSeat(cell.kind)) {
      return SizedBox(
        width: 34,
        height: 34,
        child: Icon(
          _iconFor(cell.kind),
          size: 18,
          color: AppColors.textMuted,
        ),
      );
    }

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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: borderColor != null ? Border.all(color: borderColor) : null,
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }

  bool _isNonSeat(SeatMapCellKind kind) {
    return kind == SeatMapCellKind.driver ||
        kind == SeatMapCellKind.space ||
        kind == SeatMapCellKind.door ||
        kind == SeatMapCellKind.wc;
  }

  IconData _iconFor(SeatMapCellKind kind) {
    return switch (kind) {
      SeatMapCellKind.driver => AppIcons.busFront,
      SeatMapCellKind.wc => AppIcons.amenityWater,
      SeatMapCellKind.door => AppIcons.logout,
      _ => AppIcons.spaceBar,
    };
  }
}
