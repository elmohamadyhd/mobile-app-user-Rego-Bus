import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/presentation/providers/bus_orders_provider.dart';
import 'package:rego/features/bus/presentation/widgets/operator_mark.dart';
import 'package:rego/features/bus/presentation/widgets/order_info_row.dart';
import 'package:rego/features/bus/presentation/widgets/order_status_badge.dart';
import 'package:rego/l10n/app_localizations.dart';

/// Opens the order-detail sheet, seeded instantly from [order] (the row
/// already in memory from the My Tickets list) while `GET
/// /profile/buses/orders/:id` refreshes it in the background — see
/// `docs/superpowers/specs/2026-07-15-bus-order-detail-sheet-design.md`.
Future<void> showBusOrderDetailSheet(BuildContext context, BusOrder order) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (context) => _BusOrderDetailSheet(seed: order),
  );
}

bool _hasLabel(String? value) => value != null && value.trim().isNotEmpty;

bool _hasPaymentInfo(BusOrder order) =>
    _hasLabel(order.paymentGateway) ||
    _hasLabel(order.paymentStatusText) ||
    _hasLabel(order.paymentInvoiceId);

bool _hasReferenceInfo(BusOrder order) =>
    _hasLabel(order.bookingNumber) ||
    _hasLabel(order.tripId) ||
    _hasLabel(order.gatewayOrderId) ||
    _hasLabel(order.tripType);

class _BusOrderDetailSheet extends ConsumerWidget {
  const _BusOrderDetailSheet({required this.seed});

  final BusOrder seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final order = ref.watch(busOrderDetailProvider(seed.orderId)).value ?? seed;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final hasRoute = _hasLabel(order.pickupStopLabel) ||
        _hasLabel(order.dropoffStopLabel) ||
        order.dateTimeLabel.trim().isNotEmpty;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.orderDetailTitle,
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.close),
                    color: AppColors.textMuted,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.hairline, height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeaderSection(order: order),
                    if (hasRoute) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _RouteSection(order: order, l10n: l10n),
                    ],
                    if (order.ticketLines.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _SeatsSection(order: order, l10n: l10n),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _FareSection(order: order, l10n: l10n),
                    if (_hasPaymentInfo(order)) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _PaymentSection(order: order, l10n: l10n),
                    ],
                    if (_hasReferenceInfo(order)) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _ReferenceSection(order: order, l10n: l10n),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.order});

  final BusOrder order;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        OperatorMark(name: order.operatorName, logoUrl: order.operatorLogoUrl),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.operatorName,
                style: AppTypography.title.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (order.category.trim().isNotEmpty)
                Text(
                  order.category,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        OrderStatusBadge(statusKind: order.statusKind),
      ],
    );
  }
}

class _RouteSection extends StatelessWidget {
  const _RouteSection({required this.order, required this.l10n});

  final BusOrder order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void addRow(String label, String? value) {
      if (!_hasLabel(value)) return;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.xs));
      rows.add(OrderInfoRow(label: label, value: value!));
    }

    addRow(l10n.eTicketFrom, order.pickupStopLabel);
    addRow(l10n.eTicketTo, order.dropoffStopLabel);
    if (order.dateTimeLabel.trim().isNotEmpty) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.xs));
      rows.add(
        OrderInfoRow(label: l10n.eTicketDate, value: order.dateTimeLabel),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.orderDetailRouteSection),
        ...rows,
      ],
    );
  }
}

class _SeatsSection extends StatelessWidget {
  const _SeatsSection({required this.order, required this.l10n});

  final BusOrder order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final lines = order.ticketLines;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.eTicketSeats),
        for (var i = 0; i < lines.length; i++) ...[
          OrderInfoRow(
            label: l10n.orderDetailSeatLabel(lines[i].seatNumber),
            value: lines[i].price,
            valueLtr: true,
          ),
          if (i != lines.length - 1) const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _FareSection extends StatelessWidget {
  const _FareSection({required this.order, required this.l10n});

  final BusOrder order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final fare = order.fare;
    final rows = <Widget>[
      OrderInfoRow(
        label: l10n.orderDetailSubtotal,
        value: fare.originalTicketsTotal,
        valueLtr: true,
      ),
    ];
    if (!_isZeroAmount(fare.discount)) {
      rows.add(const SizedBox(height: AppSpacing.xs));
      rows.add(
        OrderInfoRow(
          label: l10n.orderDetailDiscount,
          value: fare.discount,
          valueLtr: true,
        ),
      );
    }
    if (!_isZeroAmount(fare.walletDiscount)) {
      rows.add(const SizedBox(height: AppSpacing.xs));
      rows.add(
        OrderInfoRow(
          label: l10n.orderDetailWalletDiscount,
          value: fare.walletDiscount,
          valueLtr: true,
        ),
      );
    }
    rows.addAll([
      const SizedBox(height: AppSpacing.xs),
      OrderInfoRow(
        label: l10n.orderDetailAfterDiscount,
        value: fare.ticketsTotalAfterDiscount,
        valueLtr: true,
      ),
      const SizedBox(height: AppSpacing.xs),
      OrderInfoRow(
        label: l10n.orderDetailFees,
        value: fare.paymentFees,
        valueLtr: true,
      ),
      const SizedBox(height: AppSpacing.sm),
      const Divider(color: AppColors.hairline, height: 1),
      const SizedBox(height: AppSpacing.sm),
      OrderInfoRow(
        label: l10n.confirmTotal,
        value: fare.total,
        valueLtr: true,
        emphasized: true,
      ),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.orderDetailFareSection),
        ...rows,
      ],
    );
  }

  static bool _isZeroAmount(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9.]'), '');
    if (digits.isEmpty) return false;
    final parsed = double.tryParse(digits);
    if (parsed == null) return false;
    return parsed == 0;
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({required this.order, required this.l10n});

  final BusOrder order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void addRow(String label, String? value) {
      if (!_hasLabel(value)) return;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.xs));
      rows.add(OrderInfoRow(label: label, value: value!, valueLtr: true));
    }

    addRow(l10n.orderDetailPaymentProvider, order.paymentGateway);
    addRow(l10n.orderDetailPaymentStatus, order.paymentStatusText);
    addRow(l10n.orderDetailInvoiceId, order.paymentInvoiceId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.paymentTitle),
        ...rows,
      ],
    );
  }
}

class _ReferenceSection extends StatelessWidget {
  const _ReferenceSection({required this.order, required this.l10n});

  final BusOrder order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void addRow(String label, String? value) {
      if (!_hasLabel(value)) return;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.xs));
      rows.add(OrderInfoRow(label: label, value: value!, valueLtr: true));
    }

    addRow(l10n.eTicketRef, order.bookingNumber);
    addRow(l10n.orderDetailTripId, order.tripId);
    addRow(l10n.orderDetailGatewayOrderId, order.gatewayOrderId);
    addRow(l10n.orderDetailTripType, order.tripType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.orderDetailReferenceSection),
        ...rows,
      ],
    );
  }
}
