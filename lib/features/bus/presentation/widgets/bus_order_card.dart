import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/domain/entities/bus_order.dart';
import 'package:safaria/features/bus/domain/utils/bus_order_review.dart';
import 'package:safaria/features/bus/presentation/widgets/operator_mark.dart';
import 'package:safaria/features/bus/presentation/widgets/order_info_row.dart';
import 'package:safaria/features/bus/presentation/widgets/order_status_badge.dart';
import 'package:safaria/features/bus/presentation/widgets/ticket_border.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/order_rate_trip_button.dart';
import 'package:safaria/shared/widgets/order_rated_badge.dart';
import 'package:safaria/shared/widgets/primary_button.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Card for one [BusOrder] in the My Tickets list: operator identity, route
/// stops, status, key details, and contextual pay/e-ticket/cancel actions.
class BusOrderCard extends StatelessWidget {
  const BusOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    required this.onPay,
    required this.onOpenETicket,
    required this.onCancel,
    this.onRate,
  });

  final BusOrder order;
  final VoidCallback onTap;
  final VoidCallback onPay;
  final VoidCallback onOpenETicket;
  final VoidCallback onCancel;
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
    final actionsHeight = _actionsStubHeightFor(order);
    final hasActions = actionsHeight > 0;
    final stubHeight = hasActions ? actionsHeight : _decorativeStubHeight;
    final shape = TicketBorder(
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
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        OperatorMark(
                          name: order.operatorName,
                          logoUrl: order.operatorLogoUrl,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            order.operatorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.title.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        OrderStatusBadge(statusKind: order.statusKind),
                      ],
                    ),
                    if (order.dateTimeLabel.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          const Icon(
                            PhosphorIconsLight.calendarBlank,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              order.dateTimeLabel,
                              style: AppTypography.body.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    if (_hasLabel(order.pickupStopLabel))
                      OrderInfoRow(
                        label: l10n.eTicketFrom,
                        value: order.pickupStopLabel!,
                      ),
                    if (_hasLabel(order.pickupStopLabel) &&
                        _hasLabel(order.dropoffStopLabel))
                      const SizedBox(height: AppSpacing.xs),
                    if (_hasLabel(order.dropoffStopLabel))
                      OrderInfoRow(
                        label: l10n.eTicketTo,
                        value: order.dropoffStopLabel!,
                      ),
                    if (_hasLabel(order.pickupStopLabel) ||
                        _hasLabel(order.dropoffStopLabel))
                      const SizedBox(height: AppSpacing.xs),
                    if (order.bookingNumber.isNotEmpty) ...[
                      OrderInfoRow(
                        label: l10n.eTicketRef,
                        value: '#${order.bookingNumber}',
                        valueLtr: true,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    OrderInfoRow(
                      label: l10n.tripResultsFareLabel,
                      value: order.total,
                      valueLtr: true,
                    ),
                  ],
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
                        child: _OrderActions(
                          order: order,
                          onPay: onPay,
                          onOpenETicket: onOpenETicket,
                          onCancel: onCancel,
                          onRate: onRate,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _showsReviewUi(BusOrder order) =>
      busOrderCanRate(order) || order.reviewRating != null;

  static double _actionsStubHeightFor(BusOrder order) {
    final showPay = order.statusKind == BusOrderStatusKind.pending &&
        (order.gatewayCheckoutUrl ?? '').isNotEmpty;
    final showETicket = order.statusKind == BusOrderStatusKind.confirmed &&
        (order.invoiceUrl ?? '').isNotEmpty;
    final showCancel = order.canCancel && (order.cancelUrl ?? '').isNotEmpty;
    final showReview = _showsReviewUi(order);
    final hasSecondary = showETicket || showCancel;
    if (!showPay && !hasSecondary && !showReview) return 0;

    var height = AppSpacing.xs + AppSpacing.sm;
    if (showPay) height += _cardActionHeight;
    if (showPay && (hasSecondary || showReview)) height += _cardActionGap;
    if (hasSecondary) height += _cardActionHeight;
    if (hasSecondary && showReview) height += _cardActionGap;
    if (showReview) height += _cardActionHeight;
    return height;
  }

  static bool _hasLabel(String? value) =>
      value != null && value.trim().isNotEmpty;
}

class _OrderActions extends StatelessWidget {
  const _OrderActions({
    required this.order,
    required this.onPay,
    required this.onOpenETicket,
    required this.onCancel,
    this.onRate,
  });

  final BusOrder order;
  final VoidCallback onPay;
  final VoidCallback onOpenETicket;
  final VoidCallback onCancel;
  final VoidCallback? onRate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showPay = order.statusKind == BusOrderStatusKind.pending &&
        (order.gatewayCheckoutUrl ?? '').isNotEmpty;
    final showETicket = order.statusKind == BusOrderStatusKind.confirmed &&
        (order.invoiceUrl ?? '').isNotEmpty;
    final showCancel = order.canCancel && (order.cancelUrl ?? '').isNotEmpty;
    final canRate = busOrderCanRate(order);
    final rated = order.reviewRating;
    final showReview = canRate || rated != null;

    if (!showPay && !showETicket && !showCancel && !showReview) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showPay)
          PrimaryButton(
            label: l10n.ticketActionPay,
            onPressed: onPay,
            compact: true,
          ),
        if (showPay && (showETicket || showCancel || showReview))
          const SizedBox(height: BusOrderCard._cardActionGap),
        if (showETicket || showCancel)
          Row(
            children: [
              if (showETicket)
                Expanded(
                  child: _CardOutlinedAction(
                    onPressed: onOpenETicket,
                    icon: PhosphorIconsLight.downloadSimple,
                    label: l10n.eTicketDownload,
                    foregroundColor: AppColors.primary,
                    borderColor: AppColors.border,
                  ),
                ),
              if (showETicket && showCancel)
                const SizedBox(width: AppSpacing.sm),
              if (showCancel)
                Expanded(
                  child: _CardOutlinedAction(
                    onPressed: onCancel,
                    icon: PhosphorIconsLight.x,
                    label: l10n.ticketActionCancel,
                    foregroundColor: AppColors.error,
                    borderColor: AppColors.error.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
        if ((showETicket || showCancel) && showReview)
          const SizedBox(height: BusOrderCard._cardActionGap),
        if (canRate && onRate != null) OrderRateTripButton(onPressed: onRate!),
        if (!canRate && rated != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OrderRatedBadge(rating: rated),
          ),
      ],
    );
  }
}

class _CardOutlinedAction extends StatelessWidget {
  const _CardOutlinedAction({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.borderColor,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: foregroundColor,
        minimumSize: const Size.fromHeight(BusOrderCard._cardActionHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
