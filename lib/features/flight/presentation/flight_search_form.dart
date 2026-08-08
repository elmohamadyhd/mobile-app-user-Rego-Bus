import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/date_formatting.dart';
import 'package:safaria/features/flight/domain/entities/flight_airport_suggestion.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_rules.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_airport_field.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_airport_picker_sheet.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_leg_row.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_passenger_count_field.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_trip_type_selector.dart';
import 'package:safaria/features/home/presentation/widgets/home_flight_class_picker.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

class FlightSearchForm extends ConsumerStatefulWidget {
  const FlightSearchForm({
    super.key,
    @visibleForTesting this.initialOrigin,
    @visibleForTesting this.initialDestination,
    @visibleForTesting this.initialTravelDate,
  });

  @visibleForTesting
  final FlightAirportSuggestion? initialOrigin;
  @visibleForTesting
  final FlightAirportSuggestion? initialDestination;
  @visibleForTesting
  final DateTime? initialTravelDate;

  @override
  ConsumerState<FlightSearchForm> createState() => _FlightSearchFormState();
}

class _FlightSearchFormState extends ConsumerState<FlightSearchForm> {
  FlightTripType _tripType = FlightTripType.oneWay;
  final List<_LegDraft> _legs = [_LegDraft()];
  DateTime? _returnDate;
  FlightClass _flightClass = kDefaultFlightClass;
  FlightPassengerCounts _passengers = const FlightPassengerCounts();
  bool _searching = false;

  static const _maxBookingDays = 90;
  static const _maxLegs = 5;

  @override
  void initState() {
    super.initState();
    final first = _legs.first;
    first.origin = widget.initialOrigin;
    first.destination = widget.initialDestination;
    if (widget.initialTravelDate != null) {
      first.date = dateOnly(widget.initialTravelDate!);
    }
  }

  DateTime get _today => dateOnly(DateTime.now());

  bool get _canSubmit {
    if (!_legs.every((leg) => leg.isComplete)) return false;
    if (_tripType == FlightTripType.roundTrip) {
      final returnDate = _returnDate;
      if (returnDate == null) return false;
      if (returnDate.isBefore(_legs.first.date)) return false;
    }
    return true;
  }

  /// A new leg starts where the previous one ended — right in most
  /// itineraries, and it saves the rider a whole airport search.
  void _addLeg() {
    if (_legs.length >= _maxLegs) return;
    final previous = _legs.last;
    setState(() {
      _legs.add(
        _LegDraft(
          origin: previous.destination,
          date: previous.date.add(const Duration(days: 1)),
        ),
      );
    });
  }

  void _removeLeg(int index) {
    if (index == 0 || _legs.length <= 1) return;
    setState(() => _legs.removeAt(index));
  }

  /// A leg cannot depart before the one it follows. Changing a date pushes
  /// any later leg that would now be in the past forward to match.
  void _setLegDate(int index, DateTime date) {
    setState(() {
      _legs[index].date = date;
      for (var i = index + 1; i < _legs.length; i++) {
        if (_legs[i].date.isBefore(_legs[i - 1].date)) {
          _legs[i].date = _legs[i - 1].date;
        }
      }
    });
  }

  /// Earliest date leg [index] may depart: today for the first leg, the
  /// previous leg's date for the rest.
  DateTime _minDateForLeg(int index) =>
      index == 0 ? dateOnly(DateTime.now()) : _legs[index - 1].date;

  /// Switching trip type keeps the first leg and discards the rest.
  void _setTripType(FlightTripType type) {
    setState(() {
      _tripType = type;
      if (type != FlightTripType.multiCity && _legs.length > 1) {
        _legs.removeRange(1, _legs.length);
      }
      if (type != FlightTripType.roundTrip) _returnDate = null;
      if (type == FlightTripType.multiCity && _legs.length == 1) {
        final previous = _legs.last;
        _legs.add(
          _LegDraft(
            origin: previous.destination,
            date: previous.date.add(const Duration(days: 1)),
          ),
        );
      }
    });
  }

  void _swapLeg(int index) {
    setState(() {
      final leg = _legs[index];
      final tmp = leg.origin;
      leg.origin = leg.destination;
      leg.destination = tmp;
    });
  }

  Future<void> _pickOrigin(int index) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showFlightAirportPicker(context, title: l10n.homeFrom);
    if (picked != null) setState(() => _legs[index].origin = picked);
  }

  Future<void> _pickDestination(int index) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showFlightAirportPicker(context, title: l10n.homeTo);
    if (picked != null) setState(() => _legs[index].destination = picked);
  }

  Future<void> _pickLegDate(int index) async {
    final minDate = _minDateForLeg(index);
    final initial = _legs[index].date.isBefore(minDate)
        ? minDate
        : _legs[index].date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minDate,
      lastDate: _today.add(const Duration(days: _maxBookingDays)),
    );
    if (picked != null) _setLegDate(index, dateOnly(picked));
  }

  Future<void> _pickReturnDate() async {
    final minDate = _legs.first.date;
    final current = _returnDate;
    final initial = current == null || current.isBefore(minDate)
        ? minDate
        : current;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minDate,
      lastDate: _today.add(const Duration(days: _maxBookingDays)),
    );
    if (picked != null) setState(() => _returnDate = dateOnly(picked));
  }

  Future<void> _pickFlightClass() async {
    final l10n = AppLocalizations.of(context);
    final picked =
        await showFlightClassPicker(context, title: l10n.homeFlightClass);
    if (picked != null) setState(() => _flightClass = picked);
  }

  Future<void> _pickPassengers() async {
    final result = await showModalBottomSheet<FlightPassengerCounts>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: FlightPassengerCountSheet(
            initial: _passengers,
            onApply: (counts) => Navigator.of(context).pop(counts),
          ),
        ),
      ),
    );
    if (result != null) setState(() => _passengers = result);
  }

  Future<void> _onSearch() async {
    final l10n = AppLocalizations.of(context);
    if (!_canSubmit) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.flightSearchSelectAirports),
            duration: const Duration(seconds: 2),
          ),
        );
      return;
    }

    for (final leg in _legs) {
      if (leg.origin!.iataCode == leg.destination!.iataCode) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.flightSearchSamePlace),
              duration: const Duration(seconds: 2),
            ),
          );
        return;
      }
    }

    final first = _legs.first;
    final last = _legs.last;
    final notifier = ref.read(flightBookingProvider.notifier);
    notifier.setSearchLabels(
      from: first.origin!.name,
      to: last.destination!.name,
    );

    final params = FlightSearchParams(
      tripType: _tripType,
      legs: _legs
          .map(
            (leg) => FlightSearchLeg(
              origin: leg.origin!.iataCode,
              destination: leg.destination!.iataCode,
              date: leg.date,
            ),
          )
          .toList(),
      returnDate: _tripType == FlightTripType.roundTrip ? _returnDate : null,
      passengers: toWirePassengers(_passengers),
      cabinClass: flightCabinClassFor(_flightClass),
      currency: 'EGP',
    );

    setState(() => _searching = true);
    try {
      await notifier.search(params);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
    if (mounted) unawaited(context.push(FlightRoutes.results));
  }

  String _passengerSummary(AppLocalizations l10n) {
    final parts = <String>[
      if (_passengers.adults > 0)
        '${_passengers.adults} ${l10n.flightPaxAdults}',
      if (_passengers.children > 0)
        '${_passengers.children} ${l10n.flightPaxChildren}',
      if (_passengers.infants > 0)
        '${_passengers.infants} ${l10n.flightPaxInfants}',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FlightTripTypeSelector(
          value: _tripType,
          onChanged: _setTripType,
        ),
        const SizedBox(height: AppSpacing.md),
        if (_tripType == FlightTripType.multiCity) ...[
          for (var i = 0; i < _legs.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            FlightLegRow(
              index: i,
              origin: _legs[i].origin,
              destination: _legs[i].destination,
              date: _legs[i].date,
              onPickOrigin: () => _pickOrigin(i),
              onPickDestination: () => _pickDestination(i),
              onPickDate: () => _pickLegDate(i),
              onSwap: () => _swapLeg(i),
              onRemove: i == 0 ? null : () => _removeLeg(i),
            ),
          ],
          if (_legs.length < _maxLegs) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              key: const Key('flight-add-leg'),
              onPressed: _addLeg,
              icon: const Icon(PhosphorIconsLight.plus),
              label: Text(l10n.flightAddLeg),
            ),
          ],
        ] else ...[
          _SingleLegAirports(
            origin: _legs.first.origin,
            destination: _legs.first.destination,
            onPickOrigin: () => _pickOrigin(0),
            onPickDestination: () => _pickDestination(0),
            onSwap: () => _swapLeg(0),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.hairline),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: _DateField(
              label: l10n.homeDepart,
              date: _legs.first.date,
              onTap: () => _pickLegDate(0),
            ),
          ),
          if (_tripType == FlightTripType.roundTrip) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.hairline),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: _DateField(
                label: l10n.flightReturnDate,
                date: _returnDate,
                onTap: _pickReturnDate,
              ),
            ),
          ],
        ],
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: _ClassField(
            label: l10n.homeFlightClass,
            flightClass: _flightClass,
            onTap: _pickFlightClass,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: _PassengersField(
            label: l10n.flightPaxTitle,
            summary: _passengerSummary(l10n),
            onTap: _pickPassengers,
          ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: l10n.flightSearch,
          loading: _searching,
          onPressed: _canSubmit ? _onSearch : null,
        ),
      ],
    );
  }
}

/// A leg while the rider is still filling it in — airports may be unset.
class _LegDraft {
  _LegDraft({this.origin, DateTime? date})
      : date = date ?? dateOnly(DateTime.now());

  FlightAirportSuggestion? origin;
  FlightAirportSuggestion? destination;
  DateTime date;

  bool get isComplete => origin != null && destination != null;
}

class _SingleLegAirports extends StatelessWidget {
  const _SingleLegAirports({
    required this.origin,
    required this.destination,
    required this.onPickOrigin,
    required this.onPickDestination,
    required this.onSwap,
  });

  final FlightAirportSuggestion? origin;
  final FlightAirportSuggestion? destination;
  final VoidCallback onPickOrigin;
  final VoidCallback onPickDestination;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            children: [
              FlightAirportField(
                label: l10n.homeFrom,
                airport: origin,
                placeholder: l10n.homeCitySelectPlaceholder,
                icon: PhosphorIconsLight.airplaneTakeoff,
                iconBg: AppColors.primaryTint,
                iconColor: AppColors.primary,
                onTap: onPickOrigin,
              ),
              const Divider(
                color: AppColors.hairline,
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
              FlightAirportField(
                label: l10n.homeTo,
                airport: destination,
                placeholder: l10n.homeCitySelectPlaceholder,
                icon: PhosphorIconsLight.airplaneLanding,
                iconBg: AppColors.secondaryTint,
                iconColor: AppColors.secondary,
                onTap: onPickDestination,
              ),
            ],
          ),
        ),
        PositionedDirectional(
          end: 14,
          top: 0,
          bottom: 0,
          child: Center(child: _SwapButton(onTap: onSwap)),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localeName = Localizations.localeOf(context).toString();
    final value =
        date == null ? '' : formatSearchDateCell(date!, localeName);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.bgBase,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsLight.calendarBlank,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.overline.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      value,
                      style: AppTypography.title.copyWith(
                        color: date == null
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                PhosphorIconsLight.caretDown,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassField extends StatelessWidget {
  const _ClassField({
    required this.label,
    required this.flightClass,
    required this.onTap,
  });

  final String label;
  final FlightClass flightClass;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.bgBase,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsLight.airplane,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.overline.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      flightClass.label(l10n),
                      style: AppTypography.title.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                PhosphorIconsLight.caretDown,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassengersField extends StatelessWidget {
  const _PassengersField({
    required this.label,
    required this.summary,
    required this.onTap,
  });

  final String label;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.bgBase,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsLight.usersThree,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.overline.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      summary,
                      style: AppTypography.title.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                PhosphorIconsLight.caretDown,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.6),
            blurRadius: 16,
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              PhosphorIconsLight.arrowsDownUp,
              color: AppColors.onPrimary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
