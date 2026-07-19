// lib/features/bus/presentation/passenger_confirm_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/core/utils/date_formatting.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/entities/seat_map.dart';
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:rego/features/bus/presentation/widgets/booking_step_bar.dart';
import 'package:rego/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

int _bookingTotalEgp(BusBookingState state) =>
    state.segmentFare.round() * state.selectedSeats.length;

class _WalletPaymentSplit {
  const _WalletPaymentSplit({
    required this.subtotal,
    required this.walletApplied,
    required this.cardRemainder,
    required this.currency,
  });

  final int subtotal;
  final double walletApplied;
  final double cardRemainder;
  final String currency;

  bool get isPartial => cardRemainder > 0;
}

_WalletPaymentSplit? _walletSplit({
  required PaymentMethod method,
  required double? balance,
  required String? currency,
  required int subtotal,
}) {
  if (method != PaymentMethod.wallet || balance == null || currency == null) {
    return null;
  }
  final walletApplied = balance < subtotal ? balance : subtotal.toDouble();
  return _WalletPaymentSplit(
    subtotal: subtotal,
    walletApplied: walletApplied,
    cardRemainder: subtotal - walletApplied,
    currency: currency,
  );
}

class PassengerConfirmScreen extends ConsumerWidget {
  const PassengerConfirmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Side-effect navigation via ref.listen — never call context.go inside build.
    ref.listen<BusBookingState>(busBookingProvider, (prev, next) {
      if (next.status == BusBookingStatus.awaitingPayment) {
        if (next.paymentMethod == PaymentMethod.wallet) {
          ref.read(walletProvider.notifier).refresh();
        }
        // Order created (pending) with a gateway payment_url — go pay.
        context.push(BusRoutes.pay);
      } else if (next.status == BusBookingStatus.confirmed) {
        if (next.paymentMethod == PaymentMethod.wallet) {
          ref.read(walletProvider.notifier).refresh();
        }
        context.go(BusRoutes.ticket);
      } else if (next.status == BusBookingStatus.error && next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    final state = ref.watch(busBookingProvider);
    final isLoading = state.status == BusBookingStatus.confirming;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(title: l10n.confirmTitle),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: PrimaryButton(
            label: l10n.confirmBook,
            loading: isLoading,
            onPressed: isLoading
                ? null
                : () => ref.read(busBookingProvider.notifier).confirmBooking(),
          ),
        ),
      ),
      body: Column(
        children: [
          const BookingStepBar(current: BusBookingStep.confirm),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BusTripSummaryCard(state: state, l10n: l10n),
                  const SizedBox(height: AppSpacing.md),
                  _PaymentSection(state: state, l10n: l10n),
                  const SizedBox(height: AppSpacing.md),
                  _PriceBreakdown(state: state, l10n: l10n),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trip summary card ────────────────────────────────────────────────────────

class _BusTripSummaryCard extends StatelessWidget {
  const _BusTripSummaryCard({required this.state, required this.l10n});
  final BusBookingState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final trip = state.selectedTrip;
    final from = state.fromStop;
    final to = state.toStop;
    final seats = state.selectedSeats;
    final seatLabels =
        state.seatMap?.labelsForSeatIds(seats) ?? seats;
    final params = state.searchParams;
    final dateLabel = params == null
        ? ''
        : formatSearchDateCell(
            params.date,
            Localizations.localeOf(context).toString(),
          );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Operator code circle
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  trip?.operatorCode ?? 'R',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip?.operatorName ?? 'REGO Buses',
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (trip != null)
                      Text(
                        trip.serviceClass,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (from != null && to != null) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.hairline),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.confirmRouteSection,
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            _ConfirmRouteRow(from: from, to: to),
          ],
          if (dateLabel.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  l10n.confirmDateLabel,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(width: 6),
                Text(
                  dateLabel,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.seatSelectionSeatsLabel,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          seats.isEmpty
              ? Text(
                  l10n.seatSelectionNoSeats,
                  style:
                      AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final label in seatLabels) _SeatChip(label: label),
                  ],
                ),
        ],
      ),
    );
  }
}

class _ConfirmRouteRow extends StatelessWidget {
  const _ConfirmRouteRow({required this.from, required this.to});

  final BusStop from;
  final BusStop to;

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatTime(from.arrivalAt),
                style:
                    AppTypography.title.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                from.name,
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
              ),
              if (from.cityName.isNotEmpty)
                Text(
                  from.cityName,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMuted),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Icon(AppIcons.forward, size: 18, color: AppColors.textMuted),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTime(to.arrivalAt),
                style:
                    AppTypography.title.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                to.name,
                textAlign: TextAlign.end,
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
              ),
              if (to.cityName.isNotEmpty)
                Text(
                  to.cityName,
                  textAlign: TextAlign.end,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMuted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SeatChip extends StatelessWidget {
  const _SeatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Payment section ──────────────────────────────────────────────────────────

class _PaymentSection extends ConsumerWidget {
  const _PaymentSection({
    required this.state,
    required this.l10n,
  });
  final BusBookingState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisa = state.paymentMethod == PaymentMethod.visa;
    final isWallet = state.paymentMethod == PaymentMethod.wallet;
    final walletAsync = ref.watch(walletProvider);
    final bookingTotal = _bookingTotalEgp(state);
    final split = walletAsync.hasValue
        ? _walletSplit(
            method: state.paymentMethod,
            balance: walletAsync.value!.balance,
            currency: walletAsync.value!.currency,
            subtotal: bookingTotal,
          )
        : null;

    String? walletSubtitle;
    if (walletAsync.isLoading) {
      walletSubtitle = '…';
    } else if (walletAsync.hasError) {
      walletSubtitle = l10n.walletError;
    } else if (walletAsync.hasValue) {
      final wallet = walletAsync.value!;
      if (isWallet && split != null && split.isPartial) {
        walletSubtitle = l10n.confirmWalletPartialPay(
          split.walletApplied.toStringAsFixed(2),
          split.cardRemainder.toStringAsFixed(2),
          wallet.currency,
        );
      } else {
        walletSubtitle = l10n.confirmPaymentWalletBalance(
          wallet.balance.toStringAsFixed(2),
          wallet.currency,
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.confirmPaymentSection,
          style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        _PaymentOption(
          icon: AppIcons.ticket,
          label: l10n.confirmPaymentCard,
          selected: isVisa,
          onTap: () {
            ref
                .read(busBookingProvider.notifier)
                .setPaymentMethod(PaymentMethod.visa);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        _PaymentOption(
          icon: AppIcons.wallet,
          label: l10n.confirmPaymentWallet,
          selected: isWallet,
          subtitle: walletSubtitle,
          onTap: () {
            ref
                .read(busBookingProvider.notifier)
                .setPaymentMethod(PaymentMethod.wallet);
          },
        ),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primary : AppColors.bgCard;
    final fg = selected ? AppColors.onPrimary : AppColors.textPrimary;
    final iconColor = selected ? AppColors.onPrimary : AppColors.primary;
    final borderColor = selected ? AppColors.primary : AppColors.border;
    final subtitleColor = selected
        ? AppColors.onPrimary.withValues(alpha: 0.85)
        : AppColors.textMuted;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppTypography.caption.copyWith(
                          color: subtitleColor,
                        ),
                      ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  AppIcons.check,
                  size: 20,
                  color: AppColors.onPrimary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Price breakdown ──────────────────────────────────────────────────────────

class _PriceBreakdown extends ConsumerWidget {
  const _PriceBreakdown({required this.state, required this.l10n});
  final BusBookingState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricePerSeat = state.segmentFare.round();
    final seatCount = state.selectedSeats.length;
    final subtotal = pricePerSeat * seatCount;
    final walletAsync = ref.watch(walletProvider);
    final split = walletAsync.hasValue
        ? _walletSplit(
            method: state.paymentMethod,
            balance: walletAsync.value!.balance,
            currency: walletAsync.value!.currency,
            subtotal: subtotal,
          )
        : null;

    final priceRows = <Widget>[
      _PriceRow(
        label: l10n.confirmPricePerSeat,
        value: '$pricePerSeat EGP',
        bold: false,
      ),
      const SizedBox(height: AppSpacing.sm),
      _PriceRow(
        label: l10n.seatSelectionSeatsLabel,
        value: '$seatCount',
        bold: false,
      ),
    ];

    if (split != null) {
      final currency = split.currency;
      priceRows.addAll([
        const SizedBox(height: AppSpacing.sm),
        const Divider(color: AppColors.hairline),
        const SizedBox(height: AppSpacing.sm),
        _PriceRow(
          label: l10n.confirmPriceSubtotal,
          value: '${split.subtotal} $currency',
          bold: false,
        ),
        const SizedBox(height: AppSpacing.sm),
        _PriceRow(
          label: l10n.confirmPriceWalletApplied,
          value: '−${split.walletApplied.toStringAsFixed(2)} $currency',
          bold: false,
          valueColor: AppColors.success,
        ),
        if (split.isPartial) ...[
          const SizedBox(height: AppSpacing.sm),
          _PriceRow(
            label: l10n.confirmPricePayByCard,
            value: '${split.cardRemainder.toStringAsFixed(2)} $currency',
            bold: false,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        const Divider(color: AppColors.hairline),
        const SizedBox(height: AppSpacing.sm),
        _PriceRow(
          label: l10n.confirmTotal,
          value: '${split.cardRemainder.toStringAsFixed(2)} $currency',
          bold: true,
          valueColor: AppColors.primary,
        ),
      ]);
    } else {
      priceRows.addAll([
        const SizedBox(height: AppSpacing.sm),
        const Divider(color: AppColors.hairline),
        const SizedBox(height: AppSpacing.sm),
        _PriceRow(
          label: l10n.confirmTotal,
          value: '$subtotal EGP',
          bold: true,
          valueColor: AppColors.primary,
        ),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.confirmPriceSection,
          style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(children: priceRows),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    required this.bold,
    this.valueColor,
  });
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final valueStyle = bold
        ? AppTypography.title.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.textPrimary,
          )
        : AppTypography.body.copyWith(
            color: valueColor ?? AppColors.textSecondary,
          );
    final labelStyle = bold
        ? AppTypography.title.copyWith(fontWeight: FontWeight.w700)
        : AppTypography.body.copyWith(color: AppColors.textSecondary);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        Text(value, style: valueStyle),
      ],
    );
  }
}
