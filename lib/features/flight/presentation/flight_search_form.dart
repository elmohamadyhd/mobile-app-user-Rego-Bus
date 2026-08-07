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
import 'package:safaria/features/flight/domain/entities/flight_search_params.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_airport_field.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_airport_picker_sheet.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_passenger_count_field.dart';
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
  FlightAirportSuggestion? _origin;
  FlightAirportSuggestion? _destination;
  late DateTime _travelDate;
  FlightClass _flightClass = kDefaultFlightClass;
  int _adults = 1;
  bool _searching = false;

  static const _maxBookingDays = 90;

  @override
  void initState() {
    super.initState();
    _origin = widget.initialOrigin;
    _destination = widget.initialDestination;
    _travelDate = dateOnly(widget.initialTravelDate ?? DateTime.now());
  }

  DateTime get _today => dateOnly(DateTime.now());

  DateTime get _effectiveTravelDate =>
      _travelDate.isBefore(_today) ? _today : _travelDate;

  void _swapFields() {
    setState(() {
      final tmp = _origin;
      _origin = _destination;
      _destination = tmp;
    });
  }

  Future<void> _pickOrigin() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showFlightAirportPicker(context, title: l10n.homeFrom);
    if (picked != null) setState(() => _origin = picked);
  }

  Future<void> _pickDestination() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showFlightAirportPicker(context, title: l10n.homeTo);
    if (picked != null) setState(() => _destination = picked);
  }

  Future<void> _pickDate() async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveTravelDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: _maxBookingDays)),
    );
    if (picked != null) setState(() => _travelDate = dateOnly(picked));
  }

  Future<void> _pickFlightClass() async {
    final l10n = AppLocalizations.of(context);
    final picked =
        await showFlightClassPicker(context, title: l10n.homeFlightClass);
    if (picked != null) setState(() => _flightClass = picked);
  }

  FlightCabinClass get _cabinClass => switch (_flightClass.id) {
        'business' => FlightCabinClass.business,
        'first' => FlightCabinClass.first,
        _ => FlightCabinClass.economy,
      };

  Future<void> _onSearch() async {
    final l10n = AppLocalizations.of(context);
    final origin = _origin;
    final destination = _destination;
    if (origin == null || destination == null) {
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
    if (origin.iataCode == destination.iataCode) {
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

    final notifier = ref.read(flightBookingProvider.notifier);
    notifier.setSearchLabels(from: origin.name, to: destination.name);

    final params = FlightSearchParams(
      origin: origin.iataCode,
      destination: destination.iataCode,
      date: _effectiveTravelDate,
      passengers: [
        FlightPassengerCount(passengerTypeCode: 'ADT', count: _adults),
      ],
      cabinClass: _cabinClass,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
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
                    airport: _origin,
                    placeholder: l10n.homeCitySelectPlaceholder,
                    icon: PhosphorIconsLight.airplaneTakeoff,
                    iconBg: AppColors.primaryTint,
                    iconColor: AppColors.primary,
                    onTap: _pickOrigin,
                  ),
                  const Divider(
                    color: AppColors.hairline,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  FlightAirportField(
                    label: l10n.homeTo,
                    airport: _destination,
                    placeholder: l10n.homeCitySelectPlaceholder,
                    icon: PhosphorIconsLight.airplaneLanding,
                    iconBg: AppColors.secondaryTint,
                    iconColor: const Color(0xFFD98A2B),
                    onTap: _pickDestination,
                  ),
                ],
              ),
            ),
            PositionedDirectional(
              end: 14,
              top: 0,
              bottom: 0,
              child: Center(child: _SwapButton(onTap: _swapFields)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: _DateField(
            label: l10n.homeDepart,
            date: _effectiveTravelDate,
            onTap: _pickDate,
          ),
        ),
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
          child: FlightPassengerCountField(
            count: _adults,
            onChanged: (v) => setState(() => _adults = v),
          ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: l10n.flightSearch,
          loading: _searching,
          onPressed:
              (_origin != null && _destination != null) ? _onSearch : null,
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
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localeName = Localizations.localeOf(context).toString();
    final value = formatSearchDateCell(date, localeName);

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
