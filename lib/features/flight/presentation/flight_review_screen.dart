import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/domain/entities/flight_confirmed_order.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_wizard_step.dart';
import 'package:safaria/features/flight/domain/utils/flight_price_change.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_booking_step_bar.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_trip_summary_card.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_wizard_footer.dart';
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

  static String? _legLabel(AppLocalizations l10n, int index, int total) {
    if (total < 2) return null;
    if (total == 2) {
      return index == 0 ? l10n.flightLegOutbound : l10n.flightLegReturn;
    }
    return l10n.flightLegLabel(index + 1);
  }

  static String _passengerLabel(
    AppLocalizations l10n,
    FlightPassengerFareBreakdown breakdown,
  ) {
    final count = breakdown.numberOfPassengers;
    return switch (breakdown.passengerTypeCode.toUpperCase()) {
      'ADT' => l10n.flightFareAdults(count),
      'CHD' => l10n.flightFareChildren(count),
      'INF' => l10n.flightFareInfants(count),
      _ => '$count × ${breakdown.passengerTypeCode}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(flightBookingProvider);
    final offer = state.selectedOffer;

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
      backgroundColor: AppColors.bgBase,
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
                              onPressed: () => context.go(FlightRoutes.results),
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
                        if (change != null) _PriceChangeBanner(change: change),
                        for (var i = 0; i < offer.journeys.length; i++)
                          FlightTripSummaryCard(
                            key: ValueKey(offer.journeys[i].id),
                            journey: offer.journeys[i],
                            legLabel: _legLabel(
                              l10n,
                              i,
                              offer.journeys.length,
                            ),
                          ),
                        ..._fareRules(l10n, offer),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.flightPriceTotal,
                          style: AppTypography.title.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final breakdown
                            in confirmed.passengerFareBreakdown)
                          _FareRow(
                            label: _passengerLabel(l10n, breakdown),
                            amount: breakdown.passengerTotalAmount,
                            currency: confirmed.priceDetails.currency,
                          ),
                        _FareRow(
                          label: l10n.flightPriceTaxes,
                          amount: confirmed.priceDetails.taxesAmount,
                          currency: confirmed.priceDetails.currency,
                        ),
                        if (confirmed.priceDetails.discountAmount > 0)
                          _FareRow(
                            label: l10n.flightPriceDiscount,
                            amount: -confirmed.priceDetails.discountAmount,
                            currency: confirmed.priceDetails.currency,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: confirmed == null
          ? null
          : FlightWizardFooter(
              totalLabel: l10n.flightPriceTotal,
              totalText:
                  '${confirmed.priceDetails.totalAmount.toStringAsFixed(0)} '
                  '${confirmed.priceDetails.currency}',
              ctaLabel: change == null
                  ? l10n.flightContinue
                  : l10n.flightAcceptAndContinue,
              onCta: () => context.push(
                offer.haveBundles
                    ? FlightRoutes.bundles
                    : FlightRoutes.passengers,
              ),
            ),
    );
  }

  List<Widget> _fareRules(AppLocalizations l10n, FlightOffer offer) {
    final rules = offer.priceClasses
        .expand((c) => c.rulesAndPenalties ?? const <String>[])
        .toList();
    if (rules.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpacing.sm),
      Text(
        l10n.flightFareRules,
        style: AppTypography.title.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: AppSpacing.sm),
      for (final rule in rules)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(
            '•  $rule',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
    ];
  }
}

class _PriceChangeBanner extends StatelessWidget {
  const _PriceChangeBanner({required this.change});

  final FlightPriceChange change;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final was = change.wasSearched.toStringAsFixed(0);
    final now = change.nowConfirmed.toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.secondaryTint,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            PhosphorIconsLight.warning,
            size: 20,
            color: AppColors.secondaryDeep,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.flightPriceChanged,
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondaryDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${l10n.flightPriceWas(was)} → ${l10n.flightPriceNow(now)}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryDeep,
                  ),
                ),
              ],
            ),
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
  });

  final String label;
  final double amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            '${amount.toStringAsFixed(0)} $currency',
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
