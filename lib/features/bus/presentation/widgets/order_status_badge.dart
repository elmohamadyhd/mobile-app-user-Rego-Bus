import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/l10n/app_localizations.dart';

/// Colored status pill for a [BusOrder] — amber pending, green confirmed,
/// grey cancelled/unknown.
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.statusKind});

  final BusOrderStatusKind statusKind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, bg, fg) = switch (statusKind) {
      BusOrderStatusKind.pending => (
          l10n.ticketStatusPending,
          AppColors.secondaryTint,
          AppColors.onSecondary,
        ),
      BusOrderStatusKind.confirmed => (
          l10n.ticketStatusConfirmed,
          AppColors.success.withValues(alpha: 0.14),
          AppColors.success,
        ),
      BusOrderStatusKind.cancelled => (
          l10n.ticketStatusCancelled,
          AppColors.hairline,
          AppColors.textMuted,
        ),
      BusOrderStatusKind.unknown => (
          l10n.ticketStatusUnknown,
          AppColors.hairline,
          AppColors.textMuted,
        ),
    };

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppTypography.caption
            .copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}
