import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/domain/entities/flight_bundle.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_wizard_step.dart';
import 'package:safaria/features/flight/domain/utils/flight_bundle_pricing.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_rules.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_booking_step_bar.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_bundle_card.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Wizard step 2, shown only when the offer has bundles.
class FlightBundlesScreen extends ConsumerStatefulWidget {
  const FlightBundlesScreen({super.key});

  @override
  ConsumerState<FlightBundlesScreen> createState() =>
      _FlightBundlesScreenState();
}

class _FlightBundlesScreenState extends ConsumerState<FlightBundlesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(flightBookingProvider.notifier).loadBundles();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(flightBookingProvider);
    final confirmed = state.confirmedOrder;

    if (confirmed == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(FlightRoutes.results);
      });
      return const SizedBox.shrink();
    }

    final counts = flightPassengerCountsOf(state.searchParams);
    final selected = <FlightBundle>[];
    for (final journey in state.journeyBundles) {
      final code = state.selectedBundleCodes[journey.offerJourneyId];
      for (final bundle in journey.bundles) {
        if (bundle.code == code) selected.add(bundle);
      }
    }
    final allChosen = state.journeyBundles.isNotEmpty &&
        selected.length == state.journeyBundles.length;

    final total = flightBundlesTotal(
      baseAmount: confirmed.priceDetails.totalAmount,
      selected: selected,
      counts: counts,
    );

    return Scaffold(
      appBar: BookingAppBar(title: l10n.flightBundlesTitle),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.maxContentWidth,
            ),
            child: Column(
              children: [
                const FlightBookingStepBar(
                  current: FlightWizardStep.bundles,
                  haveBundles: true,
                ),
                if (state.status == FlightBookingStatus.loadingBundles)
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
                else
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        for (var i = 0;
                            i < state.journeyBundles.length;
                            i++)
                          _JourneySection(
                            key: ValueKey(
                              state.journeyBundles[i].offerJourneyId,
                            ),
                            index: i,
                            journey: state.journeyBundles[i],
                            counts: counts,
                            currency: confirmed.priceDetails.currency,
                            selectedCode: state.selectedBundleCodes[
                                state.journeyBundles[i].offerJourneyId],
                            onSelect: (code) => ref
                                .read(flightBookingProvider.notifier)
                                .selectBundle(
                                  journeyId: state
                                      .journeyBundles[i].offerJourneyId,
                                  bundleCode: code,
                                ),
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.flightPriceTotal,
                            style: AppTypography.body,
                          ),
                          Text(
                            '${total.toStringAsFixed(0)} '
                            '${confirmed.priceDetails.currency}',
                            style: AppTypography.h2,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        label: allChosen
                            ? l10n.flightContinue
                            : l10n.flightBundleChooseAll,
                        // Passengers screen is Phase 3 — bounce to results.
                        onPressed: allChosen
                            ? () => context.go(FlightRoutes.results)
                            : null,
                      ),
                    ],
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

class _JourneySection extends StatefulWidget {
  const _JourneySection({
    super.key,
    required this.index,
    required this.journey,
    required this.counts,
    required this.currency,
    required this.selectedCode,
    required this.onSelect,
  });

  final int index;
  final FlightJourneyBundles journey;
  final FlightPassengerCounts counts;
  final String currency;
  final String? selectedCode;
  final ValueChanged<String> onSelect;

  @override
  State<_JourneySection> createState() => _JourneySectionState();
}

class _JourneySectionState extends State<_JourneySection> {
  bool _expanded = false;

  bool get _isCollapsed => widget.selectedCode != null && !_expanded;

  FlightBundle? get _selected {
    for (final bundle in widget.journey.bundles) {
      if (bundle.code == widget.selectedCode) return bundle;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = _selected;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              l10n.flightBundleLeg(widget.index + 1),
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          if (_isCollapsed && selected != null)
            InkWell(
              onTap: () => setState(() => _expanded = true),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    const Icon(
                      PhosphorIconsLight.checkCircle,
                      size: 18,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(selected.name, style: AppTypography.body),
                    ),
                    const Icon(
                      PhosphorIconsLight.caretDown,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            )
          else
            for (final bundle in widget.journey.bundles)
              FlightBundleCard(
                bundle: bundle,
                delta: flightBundleDelta(bundle, widget.counts),
                currency: widget.currency,
                isSelected: bundle.code == widget.selectedCode,
                onTap: () {
                  widget.onSelect(bundle.code);
                  setState(() => _expanded = false);
                },
              ),
        ],
      ),
    );
  }
}
