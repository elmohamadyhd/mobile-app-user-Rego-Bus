import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/booking/data/mock_booking_data.dart';
import 'package:rego/features/booking/presentation/providers/booking_providers.dart';
import 'package:rego/features/booking/presentation/widgets/booking_app_bar.dart';
import 'package:rego/features/booking/presentation/widgets/seat_grid.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class SeatSelectionScreen extends ConsumerWidget {
  const SeatSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final (tripDetail, selectedSeats) = ref.watch(
      bookingFlowProvider.select((s) => (s.tripDetail, s.selectedSeats)),
    );

    final priceEgp = tripDetail?.summary.priceEgp ?? 0;
    final totalPrice = priceEgp * selectedSeats.length;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(title: l10n.seatSelectionTitle),
      body: Column(
        children: [
          // Legend row
          _LegendRow(l10n: l10n),
          // Seat grid (scrollable)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SeatGrid(
                rows: MockBookingData.seatLayout,
                selectedSeats: selectedSeats,
                onToggle: (id) =>
                    ref.read(bookingFlowProvider.notifier).toggleSeat(id),
              ),
            ),
          ),
          // Bottom panel
          _BottomPanel(
            selectedSeats: selectedSeats,
            totalPrice: totalPrice,
            l10n: l10n,
            onContinue: selectedSeats.isEmpty
                ? null
                : () => context.push(AppRoutes.tripConfirm),
          ),
        ],
      ),
    );
  }
}

// ── Legend ────────────────────────────────────────────────────────────────────

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgElevated,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LegendItem(
            color: AppColors.bgElevated,
            border: AppColors.hairline,
            label: l10n.seatSelectionLegendAvailable,
          ),
          const SizedBox(width: AppSpacing.lg),
          _LegendItem(
            color: const Color(0xFFDCE3F0),
            label: l10n.seatSelectionLegendBooked,
          ),
          const SizedBox(width: AppSpacing.lg),
          _LegendItem(
            color: AppColors.primary,
            label: l10n.seatSelectionLegendSelected,
            textColor: AppColors.onPrimary,
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.border,
    this.textColor,
  });
  final Color color;
  final Color? border;
  final String label;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: border != null ? Border.all(color: border!) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: textColor ?? AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ── Bottom panel ──────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.selectedSeats,
    required this.totalPrice,
    required this.l10n,
    required this.onContinue,
  });
  final List<String> selectedSeats;
  final int totalPrice;
  final AppLocalizations l10n;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.seatSelectionSeatsLabel,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted)),
                      Text(
                        selectedSeats.isEmpty
                            ? l10n.seatSelectionNoSeats
                            : selectedSeats.join(', '),
                        style: AppTypography.body
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(l10n.seatSelectionTotal,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted)),
                      Text(
                        '$totalPrice EGP',
                        style: AppTypography.h2
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: l10n.seatSelectionContinue,
                onPressed: onContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
