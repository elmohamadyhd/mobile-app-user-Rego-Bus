import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/seat.dart';

class SeatGrid extends StatelessWidget {
  const SeatGrid({
    super.key,
    required this.rows,
    required this.selectedSeats,
    required this.onToggle,
  });

  final List<SeatRow> rows;
  final List<String> selectedSeats;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerRight,
          child: Icon(AppIcons.busFront, color: AppColors.textMuted, size: 28),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final row in rows) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final cell in row.cells)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: cell == null
                      ? const SizedBox(width: 24)
                      : _SeatCellView(
                          cell: cell,
                          selected: selectedSeats.contains(cell.id),
                          onTap: cell.status == SeatStatus.available
                              ? () => onToggle(cell.id)
                              : null,
                        ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _SeatCellView extends StatelessWidget {
  const _SeatCellView({
    required this.cell,
    required this.selected,
    required this.onTap,
  });

  final SeatCell cell;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final booked = cell.status == SeatStatus.booked;

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
            cell.id,
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
}
