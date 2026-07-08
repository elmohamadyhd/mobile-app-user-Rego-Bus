// lib/features/bus/presentation/passenger_confirm_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/trip.dart';
import 'package:rego/features/bus/presentation/providers/booking_providers.dart';
import 'package:rego/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class PassengerConfirmScreen extends ConsumerWidget {
  const PassengerConfirmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Side-effect navigation via ref.listen — never call context.go inside build.
    ref.listen<BookingFlowState>(bookingFlowProvider, (prev, next) {
      if (next.status == BookingFlowStatus.confirmed) {
        context.go(AppRoutes.eTicket);
      } else if (next.status == BookingFlowStatus.error && next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    final state = ref.watch(bookingFlowProvider);
    final isLoading = state.status == BookingFlowStatus.confirming;

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
                : () => ref.read(bookingFlowProvider.notifier).confirmBooking(),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TripSummaryCard(state: state, l10n: l10n),
            const SizedBox(height: AppSpacing.md),
            _PassengerSection(state: state, l10n: l10n),
            const SizedBox(height: AppSpacing.md),
            _PaymentSection(state: state, l10n: l10n),
            const SizedBox(height: AppSpacing.md),
            _PriceBreakdown(state: state, l10n: l10n),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

// ── Trip summary card ────────────────────────────────────────────────────────

class _TripSummaryCard extends StatelessWidget {
  const _TripSummaryCard({required this.state, required this.l10n});
  final BookingFlowState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final trip = state.selectedTrip;
    final seats = state.selectedSeats;

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
              Column(
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
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Depart → Arrive times
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trip?.departLabel ?? '--:--',
                    style: AppTypography.h2.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Icon(
                      AppIcons.forward,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    trip?.arriveLabel ?? '--:--',
                    style: AppTypography.h2.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              // Seats pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${seats.length} ${l10n.seatSelectionSeatsLabel}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
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

// ── Passenger section ────────────────────────────────────────────────────────

class _PassengerSection extends StatelessWidget {
  const _PassengerSection({required this.state, required this.l10n});
  final BookingFlowState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final name =
        state.passengerName.isNotEmpty ? state.passengerName : 'Ahmed Mohamed';
    final phone = state.passengerPhone.isNotEmpty
        ? state.passengerPhone
        : '+20 10 1234 5678';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.confirmPassengerSection,
          style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _PassengerRow(
                label: l10n.confirmPassengerName,
                value: name,
                icon: AppIcons.user,
                editLabel: l10n.confirmEditComingSoon,
              ),
              const Divider(height: 1, color: AppColors.hairline),
              _PassengerRow(
                label: l10n.confirmPassengerPhone,
                value: phone,
                icon: AppIcons.phone,
                editLabel: l10n.confirmEditComingSoon,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PassengerRow extends StatelessWidget {
  const _PassengerRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.editLabel,
  });
  final String label;
  final String value;
  final IconData icon;
  final String editLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(editLabel)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted),
                    ),
                    Text(
                      value,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(AppIcons.forward,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
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
  final BookingFlowState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWallet = state.paymentMethod == PaymentMethod.wallet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.confirmPaymentSection,
          style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Wallet option (selectable)
        _PaymentOption(
          icon: AppIcons.wallet,
          label: l10n.confirmPaymentWallet,
          selected: isWallet,
          onTap: () {
            ref
                .read(bookingFlowProvider.notifier)
                .setPaymentMethod(PaymentMethod.wallet);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        // Card option (shows snackbar — not selectable)
        _PaymentOption(
          icon: AppIcons.ticket,
          label: l10n.confirmPaymentCard,
          selected: false,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.confirmCardComingSoon)),
            );
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
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primary : AppColors.bgCard;
    final fg = selected ? AppColors.onPrimary : AppColors.textPrimary;
    final iconColor = selected ? AppColors.onPrimary : AppColors.primary;
    final borderColor = selected ? AppColors.primary : AppColors.border;

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
                child: Text(
                  label,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
              if (selected)
                const Icon(AppIcons.check,
                    size: 20, color: AppColors.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Price breakdown ──────────────────────────────────────────────────────────

class _PriceBreakdown extends StatelessWidget {
  const _PriceBreakdown({required this.state, required this.l10n});
  final BookingFlowState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final trip = state.selectedTrip;
    final pricePerSeat = trip?.priceEgp ?? 0;
    final seatCount = state.selectedSeats.length;
    final total = pricePerSeat * seatCount;

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
          child: Column(
            children: [
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
              const SizedBox(height: AppSpacing.sm),
              const Divider(color: AppColors.hairline),
              const SizedBox(height: AppSpacing.sm),
              _PriceRow(
                label: l10n.confirmTotal,
                value: '$total EGP',
                bold: true,
                valueColor: AppColors.primary,
              ),
            ],
          ),
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
