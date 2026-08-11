import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/car/domain/entities/car_order.dart';
import 'package:safaria/features/car/domain/utils/car_order_review.dart';
import 'package:safaria/features/car/presentation/widgets/car_ticket_shell.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/order_rate_trip_button.dart';
import 'package:safaria/shared/widgets/order_rated_badge.dart';
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
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
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
    this.onTap,
    this.onRate,
  });

  final CarOrder order;
  final VoidCallback onPay;
  final VoidCallback onOpenVoucher;
  final VoidCallback onCancel;
  final VoidCallback? onTap;
  final VoidCallback? onRate;

  static const double _cardActionHeight = 40;
  static const double _cardActionGap = AppSpacing.sm;
  static const double _notchRadius = 10;
  // Keeps the tear above the bottom edge when there are no actions so every
  // card shares the same boarding-pass silhouette.
  static const double _decorativeStubHeight = AppSpacing.lg;

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
    final showCancel = order.canBeCancel;
    final canRate = carOrderCanRate(order);
    final rated = order.reviewRating;
    final showReview = canRate || rated != null;
    final actionsHeight = _actionsStubHeightFor(
      showPay: showPay,
      showVoucher: showVoucher,
      showCancel: showCancel,
      showReview: showReview,
    );
    final hasActions = actionsHeight > 0;
    final stubHeight = hasActions ? actionsHeight : _decorativeStubHeight;
    final shape = CarTicketBorder(
      radius: AppRadius.card,
      notchRadius: _notchRadius,
      notchOffsetFromBottom: stubHeight,
      dashColor: AppColors.border,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.16),
            blurRadius: 32,
            spreadRadius: -14,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Material(
        color: AppColors.bgCard,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              company.isEmpty
                                  ? l10n.carTicketSectionTitle
                                  : company,
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
                        style: AppTypography.title.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              height: stubHeight,
              child: hasActions
                  ? Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showPay)
                            PrimaryButton(
                              label: l10n.ticketActionPay,
                              compact: true,
                              onPressed: onPay,
                            ),
                          if (showVoucher) ...[
                            if (showPay) const SizedBox(height: _cardActionGap),
                            PrimaryButton(
                              label: l10n.carTicketActionVoucher,
                              compact: true,
                              onPressed: onOpenVoucher,
                            ),
                          ],
                          if (showCancel) ...[
                            if (showPay || showVoucher)
                              const SizedBox(height: _cardActionGap),
                            PrimaryButton(
                              label: l10n.ticketCancelConfirm,
                              compact: true,
                              variant: PrimaryButtonVariant.ghost,
                              onPressed: onCancel,
                            ),
                          ],
                          if (showReview) ...[
                            if (showPay || showVoucher || showCancel)
                              const SizedBox(height: _cardActionGap),
                            if (canRate && onRate != null)
                              OrderRateTripButton(onPressed: onRate!)
                            else if (rated != null)
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: OrderRatedBadge(rating: rated),
                              ),
                          ],
                        ],
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  static double _actionsStubHeightFor({
    required bool showPay,
    required bool showVoucher,
    required bool showCancel,
    required bool showReview,
  }) {
    final actionCount = (showPay ? 1 : 0) +
        (showVoucher ? 1 : 0) +
        (showCancel ? 1 : 0) +
        (showReview ? 1 : 0);
    if (actionCount == 0) return 0;

    var height = AppSpacing.xs + AppSpacing.sm;
    height += actionCount * _cardActionHeight;
    if (actionCount > 1) {
      height += (actionCount - 1) * _cardActionGap;
    }
    return height;
  }
}
