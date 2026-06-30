// lib/features/booking/presentation/eticket_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/booking/domain/entities/booking.dart';
import 'package:rego/features/booking/presentation/providers/booking_providers.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class ETicketScreen extends ConsumerWidget {
  const ETicketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticket = ref.watch(bookingFlowProvider.select((s) => s.ticket));

    if (ticket == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _HeroSection(ticket: ticket),
            _BoardingPassCard(ticket: ticket),
            _ActionButtons(),
            _BackHomeButton(onPressed: () {
              ref.read(bookingFlowProvider.notifier).reset();
              context.go(AppRoutes.home);
            }),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// ── Hero section ─────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.ticket});
  final ETicket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        top: 64,
        bottom: 48,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D6FF2), AppColors.primaryDark, AppColors.primaryDeep],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              AppIcons.checkCircle,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.eTicketConfirmed,
            style: AppTypography.h1.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.eTicketSubtitle,
            style: AppTypography.body.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

// ── Boarding pass card ────────────────────────────────────────────────────────

class _BoardingPassCard extends StatelessWidget {
  const _BoardingPassCard({required this.ticket});
  final ETicket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = ticket.trip;
    final summary = detail.summary;

    final departTime =
        '${summary.departHour.toString().padLeft(2, '0')}:${summary.departMinute.toString().padLeft(2, '0')}';
    final seatsJoined = ticket.seats.join(', ');

    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TicketRow(label: l10n.eTicketFrom, value: detail.terminalFrom),
                const SizedBox(height: AppSpacing.sm),
                _TicketRow(label: l10n.eTicketTo, value: detail.terminalTo),
                const SizedBox(height: AppSpacing.sm),
                _TicketRow(label: l10n.eTicketDate, value: departTime),
                const SizedBox(height: AppSpacing.sm),
                _TicketRow(
                  label: l10n.eTicketSeats,
                  value: seatsJoined.isNotEmpty ? seatsJoined : '-',
                ),
                const SizedBox(height: AppSpacing.sm),
                _TicketRow(label: l10n.eTicketRef, value: ticket.bookingRef),
              ],
            ),
          ),
          const Divider(color: AppColors.hairline, height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: _QrPlaceholder(bookingRef: ticket.bookingRef),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.label, required this.value});
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

class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder({required this.bookingRef});
  final String bookingRef;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(AppIcons.ticket, color: AppColors.textMuted, size: 32),
          const SizedBox(height: 8),
          Text(
            bookingRef,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Action buttons row ────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    void showComingSoon() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.eTicketComingSoon)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: showComingSoon,
              icon: const Icon(AppIcons.download),
              label: Text(l10n.eTicketDownload),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: showComingSoon,
              icon: const Icon(AppIcons.share),
              label: Text(l10n.eTicketShare),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Back to home button ───────────────────────────────────────────────────────

class _BackHomeButton extends StatelessWidget {
  const _BackHomeButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: PrimaryButton(
        label: l10n.eTicketBackHome,
        onPressed: onPressed,
      ),
    );
  }
}
