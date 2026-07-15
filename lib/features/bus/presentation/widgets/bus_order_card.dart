import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/presentation/widgets/operator_mark.dart';
import 'package:rego/features/bus/presentation/widgets/order_info_row.dart';
import 'package:rego/features/bus/presentation/widgets/order_status_badge.dart';
import 'package:rego/features/bus/presentation/widgets/ticket_border.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

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
  });

  final BusOrder order;
  final VoidCallback onTap;
  final VoidCallback onPay;
  final VoidCallback onOpenETicket;
  final VoidCallback onCancel;

  static const double _cardActionHeight = 40;
  static const double _cardActionGap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stubHeight = _stubHeightFor(order);
    final shape = TicketBorder(
      radius: AppRadius.card,
      notchRadius: 10,
      notchOffsetFromBottom: stubHeight > 0 ? stubHeight : 1,
      dashColor: AppColors.border,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
                            AppIcons.calendar,
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
              if (stubHeight > 0)
                SizedBox(
                  height: stubHeight,
                  child: Padding(
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
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static double _stubHeightFor(BusOrder order) {
    final showPay = order.statusKind == BusOrderStatusKind.pending &&
        (order.gatewayCheckoutUrl ?? '').isNotEmpty;
    final showETicket = (order.invoiceUrl ?? '').isNotEmpty;
    final showCancel =
        order.canCancel && (order.cancelUrl ?? '').isNotEmpty;
    final hasSecondary = showETicket || showCancel;
    if (!showPay && !hasSecondary) return 0;

    var height = AppSpacing.xs + AppSpacing.sm;
    if (showPay) height += _cardActionHeight;
    if (showPay && hasSecondary) height += _cardActionGap;
    if (hasSecondary) height += _cardActionHeight;
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
  });

  final BusOrder order;
  final VoidCallback onPay;
  final VoidCallback onOpenETicket;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showPay = order.statusKind == BusOrderStatusKind.pending &&
        (order.gatewayCheckoutUrl ?? '').isNotEmpty;
    final showETicket = (order.invoiceUrl ?? '').isNotEmpty;
    final showCancel =
        order.canCancel && (order.cancelUrl ?? '').isNotEmpty;

    if (!showPay && !showETicket && !showCancel) {
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
        if (showPay && (showETicket || showCancel))
          const SizedBox(height: BusOrderCard._cardActionGap),
        if (showETicket || showCancel)
          Row(
            children: [
              if (showETicket)
                Expanded(
                  child: _CardOutlinedAction(
                    onPressed: onOpenETicket,
                    icon: AppIcons.download,
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
                    icon: AppIcons.close,
                    label: l10n.ticketActionCancel,
                    foregroundColor: AppColors.error,
                    borderColor: AppColors.error.withValues(alpha: 0.4),
                  ),
                ),
            ],
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
