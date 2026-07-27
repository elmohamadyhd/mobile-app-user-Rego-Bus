import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/car/domain/entities/car_order.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

class CarOrderStatusBadge extends StatelessWidget {
  const CarOrderStatusBadge({super.key, required this.statusKind});

  final CarOrderStatusKind statusKind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, bg, fg) = switch (statusKind) {
      CarOrderStatusKind.pending => (
          l10n.ticketStatusPending,
          AppColors.secondaryTint,
          AppColors.onSecondary,
        ),
      CarOrderStatusKind.confirmed => (
          l10n.ticketStatusConfirmed,
          AppColors.success.withValues(alpha: 0.14),
          AppColors.success,
        ),
      CarOrderStatusKind.cancelled => (
          l10n.ticketStatusCancelled,
          AppColors.hairline,
          AppColors.textMuted,
        ),
      CarOrderStatusKind.unknown => (
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

class CarOrderCard extends StatelessWidget {
  const CarOrderCard({
    super.key,
    required this.order,
    required this.onPay,
    required this.onOpenVoucher,
    required this.onCancel,
  });

  final CarOrder order;
  final VoidCallback onPay;
  final VoidCallback onOpenVoucher;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trip = order.trip;
    final routeLabel = trip == null
        ? '—'
        : '${trip.fromLocation.name} → ${trip.toLocation.name}';
    final company = trip?.company.name ?? '';
    final showPay = order.statusKind == CarOrderStatusKind.pending;
    final showVoucher = order.statusKind == CarOrderStatusKind.confirmed;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  company.isEmpty ? l10n.carTicketSectionTitle : company,
                  style: AppTypography.title.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              CarOrderStatusBadge(statusKind: order.statusKind),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(routeLabel, style: AppTypography.body),
          if (order.departureDate != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              order.departureDate!,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${order.currency} ${order.price}',
            style: AppTypography.title.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (showPay)
            PrimaryButton(
              label: l10n.ticketActionPay,
              compact: true,
              onPressed: onPay,
            ),
          if (showVoucher) ...[
            if (showPay) const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: l10n.carTicketActionVoucher,
              compact: true,
              onPressed: onOpenVoucher,
            ),
          ],
          if (order.canBeCancel) ...[
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: l10n.ticketCancelConfirm,
              compact: true,
              variant: PrimaryButtonVariant.ghost,
              onPressed: onCancel,
            ),
          ],
        ],
      ),
    );
  }
}
