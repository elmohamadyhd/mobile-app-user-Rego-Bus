import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/presentation/widgets/order_status_badge.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

/// Card for one [BusOrder] in the My Tickets list: operator identity, status
/// badge, key details, and the contextual pay/e-ticket/cancel actions.
class BusOrderCard extends StatelessWidget {
  const BusOrderCard({
    super.key,
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
    final seatsJoined = order.seats.join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _OrderAvatar(
                name: order.operatorName,
                logoUrl: order.operatorLogoUrl,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.operatorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (order.category.trim().isNotEmpty)
                      Text(
                        order.category,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                  ],
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
                const Icon(AppIcons.calendar,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  order.dateTimeLabel,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.hairline, height: 1),
          const SizedBox(height: AppSpacing.md),
          if (order.bookingNumber.isNotEmpty)
            _InfoRow(label: l10n.eTicketRef, value: '#${order.bookingNumber}'),
          if (seatsJoined.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            _InfoRow(label: l10n.eTicketSeats, value: seatsJoined),
          ],
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(label: l10n.tripResultsFareLabel, value: order.total),
          _OrderActions(
            order: order,
            onPay: onPay,
            onOpenETicket: onOpenETicket,
            onCancel: onCancel,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style:
                AppTypography.body.copyWith(color: AppColors.textSecondary)),
        const Spacer(),
        Text(
          value,
          style: AppTypography.body.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _OrderAvatar extends StatelessWidget {
  const _OrderAvatar({required this.name, required this.logoUrl});

  final String name;
  final String? logoUrl;

  static const double _size = 42;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    return Container(
      width: _size,
      height: _size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: hasLogo
          ? Image.network(
              logoUrl!,
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initials(),
            )
          : _initials(),
    );
  }

  Widget _initials() {
    final trimmed = name.trim();
    final code =
        trimmed.isNotEmpty ? trimmed.substring(0, 1).toUpperCase() : '?';
    return Text(
      code,
      style: AppTypography.body.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
        fontSize: _size * 0.31,
      ),
    );
  }
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
    final showCancel = order.canCancel;

    if (!showPay && !showETicket && !showCancel) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showPay)
            PrimaryButton(label: l10n.ticketActionPay, onPressed: onPay),
          if (showPay && (showETicket || showCancel))
            const SizedBox(height: AppSpacing.sm),
          if (showETicket || showCancel)
            Row(
              children: [
                if (showETicket)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onOpenETicket,
                      icon: const Icon(AppIcons.download, size: 18),
                      label: Text(l10n.eTicketDownload),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.button),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm),
                      ),
                    ),
                  ),
                if (showETicket && showCancel)
                  const SizedBox(width: AppSpacing.sm),
                if (showCancel)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(AppIcons.close, size: 18),
                      label: Text(l10n.ticketActionCancel),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.button),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
