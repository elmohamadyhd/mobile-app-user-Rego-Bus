import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/shared/widgets/ltr_text.dart';

/// Label/value row shared by [BusOrderCard] and the order detail sheet:
/// label on the leading edge, value on the trailing edge. [valueLtr] forces
/// LTR layout for money/reference values inside RTL text. [emphasized] bumps
/// the value to `title` weight for total-style rows.
class OrderInfoRow extends StatelessWidget {
  const OrderInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueLtr = false,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool valueLtr;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final baseStyle = emphasized ? AppTypography.title : AppTypography.body;
    final valueStyle = baseStyle.copyWith(
      color: AppColors.textPrimary,
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: valueLtr
                ? LtrText(value, style: valueStyle, textAlign: TextAlign.end)
                : Text(
                    value,
                    textAlign: TextAlign.end,
                    style: valueStyle,
                  ),
          ),
        ),
      ],
    );
  }
}
