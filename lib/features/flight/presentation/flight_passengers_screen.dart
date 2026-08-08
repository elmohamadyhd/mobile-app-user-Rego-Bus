import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';
import 'package:safaria/features/flight/domain/entities/flight_wizard_step.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_validation.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_booking_step_bar.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_passenger_row.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Wizard step 3.
class FlightPassengersScreen extends ConsumerStatefulWidget {
  const FlightPassengersScreen({super.key});

  @override
  ConsumerState<FlightPassengersScreen> createState() =>
      _FlightPassengersScreenState();
}

class _FlightPassengersScreenState
    extends ConsumerState<FlightPassengersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(flightBookingProvider.notifier).seedPassengerDrafts();
    });
  }

  /// 1-based position within the traveller's own type, so the labels read
  /// "Adult 1, Adult 2, Child 1" rather than numbering straight through.
  int _ordinalOf(List<FlightPassengerDraft> drafts, int index) {
    var seen = 0;
    for (var i = 0; i <= index; i++) {
      if (drafts[i].type == drafts[index].type) seen++;
    }
    return seen;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(flightBookingProvider);
    final notifier = ref.read(flightBookingProvider.notifier);

    if (state.confirmedOrder == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(FlightRoutes.results);
      });
      return const SizedBox.shrink();
    }

    final drafts = state.passengerDrafts;
    final contactFilled = state.contact.email.trim().isNotEmpty &&
        state.contact.phone.trim().isNotEmpty;
    final allComplete =
        drafts.isNotEmpty && drafts.every(isFlightPassengerComplete);
    final canContinue = contactFilled && allComplete;

    return Scaffold(
      appBar: BookingAppBar(title: l10n.flightPassengersTitle),
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
                  current: FlightWizardStep.passengers,
                  haveBundles: state.selectedOffer?.haveBundles ?? false,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      Text(
                        l10n.flightContactSection,
                        style: AppTypography.body,
                      ),
                      Text(
                        l10n.flightContactOnce,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        initialValue: state.contact.email,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: l10n.flightContactEmail,
                        ),
                        onChanged: (value) => notifier.setContactDetails(
                          state.contact.copyWith(email: value),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        initialValue: state.contact.phone,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: l10n.flightContactPhone,
                        ),
                        onChanged: (value) => notifier.setContactDetails(
                          state.contact.copyWith(phone: value),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      for (var i = 0; i < drafts.length; i++)
                        FlightPassengerRow(
                          draft: drafts[i],
                          ordinal: _ordinalOf(drafts, i),
                          serverError: state.passengerErrors[i]?.values.first,
                          onTap: () => context.push(
                            FlightRoutes.passengerForm,
                            extra: i,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: PrimaryButton(
                    label: l10n.flightContinue,
                    loading: state.status ==
                        FlightBookingStatus.submittingPassengers,
                    onPressed: canContinue
                        ? () async {
                            final ok = await notifier.submitPassengers();
                            if (ok && context.mounted) {
                              unawaited(context.push(FlightRoutes.results));
                            }
                          }
                        : null,
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
