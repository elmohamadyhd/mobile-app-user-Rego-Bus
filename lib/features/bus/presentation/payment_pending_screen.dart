import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

/// Shown when the rider returns from the payment gateway without a confirmed
/// payment (cancelled, closed, or still processing). The seat is held and the
/// backend auto-cancels the order in ~15 minutes if it stays unpaid, so this
/// screen nudges the rider to finish paying rather than treating it as a hard
/// failure.
class PaymentPendingScreen extends ConsumerWidget {
  const PaymentPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ticket = ref.watch(busBookingProvider.select((s) => s.ticket));

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              _PendingHero(l10n: l10n),
              const SizedBox(height: AppSpacing.lg),
              if (ticket != null) _OrderRecap(ticket: ticket, l10n: l10n),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: l10n.paymentPendingComplete,
                onPressed: () => context.push(BusRoutes.pay),
              ),
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(
                label: l10n.paymentPendingBackHome,
                variant: PrimaryButtonVariant.ghost,
                onPressed: () {
                  ref.read(busBookingProvider.notifier).reset();
                  context.go(AppRoutes.home);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingHero extends StatelessWidget {
  const _PendingHero({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: AppColors.secondaryTint,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            AppIcons.calendar,
            color: AppColors.secondary,
            size: 36,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.paymentPendingTitle,
          textAlign: TextAlign.center,
          style: AppTypography.h1,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.paymentPendingBody,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _OrderRecap extends StatelessWidget {
  const _OrderRecap({required this.ticket, required this.l10n});

  final BusTicket ticket;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final seatsJoined = ticket.seats.join(', ');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          _RecapRow(label: l10n.eTicketRef, value: ticket.bookingRef),
          const SizedBox(height: AppSpacing.sm),
          _RecapRow(
            label: l10n.eTicketSeats,
            value: seatsJoined.isNotEmpty ? seatsJoined : '-',
          ),
          const SizedBox(height: AppSpacing.sm),
          _RecapRow(label: l10n.confirmTotal, value: ticket.total),
        ],
      ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  const _RecapRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
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
