import 'dart:async';

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
import 'package:safaria/features/flight/domain/entities/flight_confirmed_order.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
import 'package:safaria/features/flight/domain/entities/flight_wizard_step.dart';
import 'package:safaria/features/flight/domain/utils/flight_airport_labels.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_booking_step_bar.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_fare_row.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_leg_badge.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_trip_summary_card.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_wizard_footer.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/pages/cms_page_paths.dart';
import 'package:safaria/shared/widgets/booking_terms_checkbox.dart';
import 'package:safaria/shared/widgets/ltr_icon.dart';

/// Wizard step 4 — the last screen before money moves.
class FlightPayScreen extends ConsumerStatefulWidget {
  const FlightPayScreen({super.key});

  @override
  ConsumerState<FlightPayScreen> createState() => _FlightPayScreenState();
}

class _FlightPayScreenState extends ConsumerState<FlightPayScreen> {
  bool _termsAccepted = false;

  int _ordinalOf(List<FlightPassengerDraft> drafts, int index) {
    var seen = 0;
    for (var i = 0; i <= index; i++) {
      if (drafts[i].type == drafts[index].type) seen++;
    }
    return seen;
  }

  List<FlightJourney> _journeys(
    FlightBookingState state,
    FlightConfirmedOrder confirmed,
  ) {
    final offer = state.selectedOffer;
    if (offer != null && offer.journeys.isNotEmpty) return offer.journeys;
    return [_journeyFromConfirmed(confirmed)];
  }

  List<FlightBundle> _selectedBundles(FlightBookingState state) {
    final selected = <FlightBundle>[];
    for (final journey in state.journeyBundles) {
      final code = state.selectedBundleCodes[journey.offerJourneyId];
      for (final bundle in journey.bundles) {
        if (bundle.code == code) selected.add(bundle);
      }
    }
    return selected;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(flightBookingProvider);
    final confirmed = state.confirmedOrder;
    final settings = ref.watch(flightSettingsProvider);

    if (confirmed == null || state.passengersOfferId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(FlightRoutes.results);
      });
      return const SizedBox.shrink();
    }

    final currency =
        settings.value?.bookingCurrency ?? confirmed.priceDetails.currency;
    final journeys = _journeys(state, confirmed);
    final bundles = _selectedBundles(state);
    final drafts = state.passengerDrafts;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(title: l10n.flightPayTitle),
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
                  current: FlightWizardStep.pay,
                  haveBundles:
                      state.selectedOffer?.haveBundles ?? confirmed.haveBundles,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      for (var i = 0; i < journeys.length; i++)
                        _journeyCard(
                          l10n,
                          state,
                          journeys[i],
                          i,
                          journeys.length,
                        ),
                      if (drafts.isNotEmpty)
                        _PayCard(
                          title: l10n.flightPayTravellers,
                          children: [
                            for (var i = 0; i < drafts.length; i++)
                              _TravellerTile(
                                name: _displayName(l10n, drafts[i]),
                                slot: _slotLabel(
                                  l10n,
                                  drafts[i].type,
                                  _ordinalOf(drafts, i),
                                ),
                              ),
                          ],
                        ),
                      if (bundles.isNotEmpty ||
                          state.selectedBundleCodes.isNotEmpty)
                        _PayCard(
                          title: l10n.flightPayBundles,
                          children: [
                            if (bundles.isNotEmpty)
                              for (final bundle in bundles)
                                _IconLine(
                                  icon: PhosphorIconsLight.package,
                                  text: bundle.name,
                                )
                            else
                              for (final code
                                  in state.selectedBundleCodes.values)
                                _IconLine(
                                  icon: PhosphorIconsLight.package,
                                  text: code,
                                ),
                          ],
                        ),
                      _PayCard(
                        title: l10n.flightFareBreakdown,
                        children: [
                          for (final breakdown
                              in confirmed.passengerFareBreakdown)
                            FlightFareRow(
                              label: flightPassengerFareLabel(l10n, breakdown),
                              amount: breakdown.passengerTotalAmount,
                              currency: currency,
                            ),
                          FlightFareRow(
                            label: l10n.flightPriceTaxes,
                            amount: confirmed.priceDetails.taxesAmount,
                            currency: currency,
                          ),
                          if (confirmed.priceDetails.discountAmount > 0)
                            FlightFareRow(
                              label: l10n.flightPriceDiscount,
                              amount: -confirmed.priceDetails.discountAmount,
                              currency: currency,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: FlightWizardFooter(
        totalLabel: l10n.flightPriceTotal,
        totalText:
            '${confirmed.priceDetails.totalAmount.toStringAsFixed(0)} $currency',
        ctaLabel: l10n.flightPayNow,
        loading: state.status == FlightBookingStatus.creatingOrder,
        onCta: _termsAccepted
            ? () async {
                final order = await ref
                    .read(flightBookingProvider.notifier)
                    .createOrder(currency: currency);
                if (!context.mounted) return;
                final url = order?.checkoutUrl;
                if (url == null || url.isEmpty) return;
                unawaited(context.push(FlightRoutes.pay, extra: order));
              }
            : null,
        beforeCta: BookingTermsCheckbox(
          value: _termsAccepted,
          onChanged: (value) => setState(() => _termsAccepted = value),
          onOpenTerms: () => context.push(CmsPagePaths.terms),
        ),
      ),
    );
  }

  FlightTripSummaryCard _journeyCard(
    AppLocalizations l10n,
    FlightBookingState state,
    FlightJourney journey,
    int index,
    int total,
  ) {
    final labels = flightJourneyAirportLabels(
      index: index,
      journey: journey,
      tripType: state.searchParams?.tripType ?? FlightTripType.oneWay,
      searchLegs: state.searchParams?.legs ?? const [],
      namesByIata: state.searchAirportNames,
      searchFromLabel: state.searchFromLabel,
      searchToLabel: state.searchToLabel,
    );
    return FlightTripSummaryCard(
      key: ValueKey(journey.id),
      journey: journey,
      originLabel: labels.origin,
      destinationLabel: labels.destination,
      legLabel: flightJourneyBadgeLabel(
        l10n,
        index: index,
        total: total,
      ),
      legKind: flightJourneyBadgeKind(
        index: index,
        total: total,
      ),
    );
  }
}

FlightJourney _journeyFromConfirmed(FlightConfirmedOrder confirmed) {
  return FlightJourney(
    id: confirmed.journeyId,
    origin: confirmed.origin,
    destination: confirmed.destination,
    numberOfStops: confirmed.numberOfStops,
    segments: [
      for (final segment in confirmed.segments)
        FlightSegment(
          id: segment.segmentId,
          origin: segment.origin,
          destination: segment.destination,
          departureDateTime: segment.departureDateTime,
          arrivalDateTime: segment.arrivalDateTime,
          departureTerminal: segment.departureTerminal,
          arrivalTerminal: segment.arrivalTerminal,
          flightTimeInMinutes: segment.flightTimeInMinutes,
          operatingCarrierCode: segment.operatingCarrierCode,
          operatingCarrierName: segment.operatingCarrierName,
          operatingCarrierLogo: segment.operatingCarrierLogo,
          operatingFlightNumber: segment.operatingFlightNumber,
          marketingCarrierCode: segment.marketingCarrierCode,
          marketingFlightNumber: segment.marketingFlightNumber,
          equipment: segment.equipment,
        ),
    ],
  );
}

String _displayName(AppLocalizations l10n, FlightPassengerDraft draft) {
  final title = switch (draft.title) {
    'MR' => l10n.flightTitleMr,
    'MRS' => l10n.flightTitleMrs,
    'MS' => l10n.flightTitleMs,
    _ => null,
  };
  final name = [draft.firstName, draft.lastName]
      .whereType<String>()
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join(' ');
  if (title == null || title.isEmpty) return name;
  if (name.isEmpty) return title;
  return '$title $name';
}

String _slotLabel(
  AppLocalizations l10n,
  FlightPassengerType type,
  int ordinal,
) {
  return switch (type) {
    FlightPassengerType.adult => l10n.flightPassengerAdultN(ordinal),
    FlightPassengerType.child => l10n.flightPassengerChildN(ordinal),
    FlightPassengerType.infant => l10n.flightPassengerInfantN(ordinal),
  };
}

class _PayCard extends StatelessWidget {
  const _PayCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.title.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

class _TravellerTile extends StatelessWidget {
  const _TravellerTile({required this.name, required this.slot});

  final String name;
  final String slot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: const LtrIcon(
              PhosphorIconsLight.user,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? slot : name,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  slot,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
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

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          LtrIcon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
