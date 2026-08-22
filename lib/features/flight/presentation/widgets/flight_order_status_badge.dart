import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_order.dart';
import 'package:safaria/features/flight/domain/utils/flight_order_status.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Confirmed / pending / cancelled pill used on ticket cards and details.
class FlightOrderStatusBadge extends StatelessWidget {
  const FlightOrderStatusBadge({super.key, required this.order});

  final FlightOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cancelled = isFlightOrderCancelled(order);
    final paid = !cancelled && isFlightOrderPaid(order);
    final Color bg;
    final Color fg;
    final String label;
    if (cancelled) {
      bg = AppColors.error.withValues(alpha: 0.14);
      fg = AppColors.error;
      label = l10n.ticketStatusCancelled;
    } else if (paid) {
      bg = AppColors.success.withValues(alpha: 0.14);
      fg = AppColors.success;
      label = l10n.ticketStatusConfirmed;
    } else {
      bg = AppColors.secondaryTint;
      fg = AppColors.onSecondary;
      label = l10n.ticketStatusPending;
    }

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
