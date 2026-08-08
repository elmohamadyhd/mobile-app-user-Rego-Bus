import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/domain/entities/flight_wizard_step.dart';
import 'package:safaria/features/flight/domain/utils/flight_price_change.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_booking_step_bar.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Wizard step 1. Calls confirm on entry — the searched fare is an estimate
/// until the provider re-prices it.
class FlightReviewScreen extends ConsumerStatefulWidget {
  const FlightReviewScreen({super.key});

  @override
  ConsumerState<FlightReviewScreen> createState() => _FlightReviewScreenState();
}

class _FlightReviewScreenState extends ConsumerState<FlightReviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(flightBookingProvider.notifier).confirmSelectedOffer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(flightBookingProvider);
    final offer = state.selectedOffer;

    // Guard: a restored route or an odd back-stack must not open a mid-flow
    // step against empty state.
    if (offer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(FlightRoutes.results);
      });
      return const SizedBox.shrink();
    }

    final confirmed = state.confirmedOrder;
    final change = confirmed == null
        ? null
        : flightPriceChange(
            searched: offer.totalAmount,
            confirmed: confirmed.priceDetails.totalAmount,
          );

    return Scaffold(
      appBar: BookingAppBar(title: l10n.flightReviewTitle),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.maxContentWidth,
            ),
            child: Column(
              children: [
                FlightBookingStepBar(
                  current: FlightWizardStep.review,
                  haveBundles: offer.haveBundles,
                ),
                if (state.status == FlightBookingStatus.confirming)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.status == FlightBookingStatus.error)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.error ?? '',
                              textAlign: TextAlign.center,
                              style: AppTypography.body.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            PrimaryButton(
                              label: l10n.flightBackToResults,
                              variant: PrimaryButtonVariant.ghost,
                              onPressed: () =>
                                  context.go(FlightRoutes.results),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (confirmed != null)
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        if (change != null)
                          _PriceChangeBanner(change: change),
                        for (final breakdown
                            in confirmed.passengerFareBreakdown)
                          _FareRow(
                            label:
                                '${breakdown.numberOfPassengers} × ${breakdown.passengerTypeCode}',
                            amount: breakdown.passengerTotalAmount,
                            currency: confirmed.priceDetails.currency,
                          ),
                        const Divider(),
                        _FareRow(
                          label: l10n.flightPriceTotal,
                          amount: confirmed.priceDetails.totalAmount,
                          currency: confirmed.priceDetails.currency,
                          emphasized: true,
                        ),
                      ],
                    ),
                  ),
                if (confirmed != null)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: PrimaryButton(
                      // Wording carries the weight here: when the fare moved,
                      // this must read as an explicit acceptance, not a
                      // habitual next.
                      label: change == null
                          ? l10n.flightContinue
                          : l10n.flightAcceptAndContinue,
                      onPressed: () => context.push(
                        offer.haveBundles
                            ? FlightRoutes.bundles
                            : FlightRoutes.passengers,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceChangeBanner extends StatelessWidget {
  const _PriceChangeBanner({required this.change});

  final FlightPriceChange change;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.secondaryTint,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.flightPriceChanged,
            style: AppTypography.body.copyWith(color: AppColors.secondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.flightPriceWas(change.wasSearched.toStringAsFixed(0)),
            style: AppTypography.caption.copyWith(color: AppColors.secondary),
          ),
          Text(
            l10n.flightPriceNow(change.nowConfirmed.toStringAsFixed(0)),
            style: AppTypography.caption.copyWith(color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}

class _FareRow extends StatelessWidget {
  const _FareRow({
    required this.label,
    required this.amount,
    required this.currency,
    this.emphasized = false,
  });

  final String label;
  final double amount;
  final String currency;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized ? AppTypography.h2 : AppTypography.body;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('${amount.toStringAsFixed(0)} $currency', style: style),
        ],
      ),
    );
  }
}
