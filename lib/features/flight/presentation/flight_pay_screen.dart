import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/domain/entities/flight_wizard_step.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_booking_step_bar.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/pages/cms_page_paths.dart';
import 'package:safaria/shared/widgets/booking_terms_checkbox.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Wizard step 4 — the last screen before money moves.
class FlightPayScreen extends ConsumerStatefulWidget {
  const FlightPayScreen({super.key});

  @override
  ConsumerState<FlightPayScreen> createState() => _FlightPayScreenState();
}

class _FlightPayScreenState extends ConsumerState<FlightPayScreen> {
  bool _termsAccepted = false;

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

    return Scaffold(
      appBar: BookingAppBar(title: l10n.flightPayTitle),
      body: Column(
        children: [
          FlightBookingStepBar(
            current: FlightWizardStep.pay,
            haveBundles: state.selectedOffer?.haveBundles ?? false,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _Section(
                  title: l10n.flightPayItinerary,
                  children: [
                    for (final segment in confirmed.segments)
                      Text(
                        '${segment.origin} → ${segment.destination}'
                        '  ·  ${segment.marketingCarrierCode}'
                        '${segment.marketingFlightNumber}',
                        style: AppTypography.body,
                      ),
                  ],
                ),
                _Section(
                  title: l10n.flightPayTravellers,
                  children: [
                    for (final passenger in state.passengerDrafts)
                      Text(
                        [passenger.firstName, passenger.lastName]
                            .whereType<String>()
                            .join(' '),
                        style: AppTypography.body,
                      ),
                  ],
                ),
                if (state.selectedBundleCodes.isNotEmpty)
                  _Section(
                    title: l10n.flightPayBundles,
                    children: [
                      for (final code in state.selectedBundleCodes.values)
                        Text(code, style: AppTypography.body),
                    ],
                  ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.flightPriceTotal, style: AppTypography.body),
                    Text(
                      '${confirmed.priceDetails.totalAmount.toStringAsFixed(0)}'
                      ' $currency',
                      style: AppTypography.h2,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                BookingTermsCheckbox(
                  value: _termsAccepted,
                  onChanged: (value) =>
                      setState(() => _termsAccepted = value),
                  onOpenTerms: () => context.push(CmsPagePaths.terms),
                ),
                const SizedBox(height: AppSpacing.sm),
                PrimaryButton(
                  label: l10n.flightPayNow,
                  loading:
                      state.status == FlightBookingStatus.creatingOrder,
                  onPressed: _termsAccepted
                      ? () async {
                          final order = await ref
                              .read(flightBookingProvider.notifier)
                              .createOrder(currency: currency);
                          if (!context.mounted) return;
                          final url = order?.checkoutUrl;
                          if (url == null || url.isEmpty) return;
                          unawaited(
                            context.push(FlightRoutes.pay, extra: order),
                          );
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.caption
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...children,
        ],
      ),
    );
  }
}
