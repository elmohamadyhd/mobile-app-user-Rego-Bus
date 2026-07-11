import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:rego/features/bus/presentation/widgets/booking_step_bar.dart';
import 'package:rego/features/bus/presentation/widgets/seat_grid.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class SeatSelectionScreen extends ConsumerWidget {
  const SeatSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(busBookingProvider);
    final seatMap = state.seatMap;
    final selectedSeats = state.selectedSeats;
    final isLoading = state.status == BusBookingStatus.loadingSeats;
    final totalPrice = (state.segmentFare * selectedSeats.length).round();
    final currency = state.selectedTrip?.currency ?? 'EGP';

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(title: l10n.seatSelectionTitle),
      body: Column(
        children: [
          const BookingStepBar(current: BusBookingStep.seat),
          _LegendRow(l10n: l10n),
          Expanded(
            child: isLoading
                ? const SingleChildScrollView(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: _SeatGridSkeleton(),
                  )
                : seatMap == null
                    ? _SeatMapErrorView(message: l10n.tripResultsError)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: SeatGrid(
                          seatMap: seatMap,
                          selectedSeats: selectedSeats,
                          onToggle: (id) => ref
                              .read(busBookingProvider.notifier)
                              .toggleSeat(id),
                        ),
                      ),
          ),
          _BottomPanel(
            selectedSeats: selectedSeats,
            totalPrice: totalPrice,
            currency: currency,
            l10n: l10n,
            onContinue: selectedSeats.isEmpty
                ? null
                : () => context.push(BusRoutes.confirm),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
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
            borderRadius: BorderRadius.circular(6),
            border: border != null ? Border.all(color: border!) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: textColor ?? AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SeatGridSkeleton extends StatelessWidget {
  const _SeatGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.hairline,
      highlightColor: AppColors.bgElevated,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          children: [
            for (var r = 0; r < 6; r++) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var c = 0; c < 4; c++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.hairline,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeatMapErrorView extends StatelessWidget {
  const _SeatMapErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.error, color: AppColors.error, size: 40),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: AppTypography.body.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.selectedSeats,
    required this.totalPrice,
    required this.currency,
    required this.l10n,
    required this.onContinue,
  });

  final List<String> selectedSeats;
  final int totalPrice;
  final String currency;
  final AppLocalizations l10n;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.sheet),
          topRight: Radius.circular(AppRadius.sheet),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -6),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.seatSelectionSeatsLabel,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        selectedSeats.isEmpty
                            ? Text(
                                l10n.seatSelectionNoSeats,
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final seat in selectedSeats)
                                    _SeatChip(label: seat),
                                ],
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        l10n.seatSelectionTotal,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        '$totalPrice $currency',
                        style: AppTypography.h2.copyWith(
                          color: AppColors.primary,
                        ),
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
