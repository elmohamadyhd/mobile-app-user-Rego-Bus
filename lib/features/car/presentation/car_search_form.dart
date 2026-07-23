import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/core/utils/date_formatting.dart';
import 'package:rego/features/car/domain/entities/car_place.dart';
import 'package:rego/features/car/domain/entities/car_search_params.dart';
import 'package:rego/features/car/presentation/car_routes.dart';
import 'package:rego/features/car/presentation/providers/car_booking_providers.dart';
import 'package:rego/features/car/presentation/widgets/car_place_field.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/models/trip_type.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class CarSearchForm extends ConsumerStatefulWidget {
  const CarSearchForm({
    super.key,
    @visibleForTesting this.initialFrom,
    @visibleForTesting this.initialTo,
  });

  @visibleForTesting
  final CarPlace? initialFrom;
  @visibleForTesting
  final CarPlace? initialTo;

  @override
  ConsumerState<CarSearchForm> createState() => _CarSearchFormState();
}

class _CarSearchFormState extends ConsumerState<CarSearchForm> {
  CarPlace? _from;
  CarPlace? _to;
  TripType _tripType = TripType.oneWay;
  DateTime _travelDate = dateOnly(DateTime.now());
  DateTime _returnDate = dateOnly(DateTime.now().add(const Duration(days: 7)));
  bool _searching = false;

  static const _maxBookingDays = 90;

  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom;
    _to = widget.initialTo;
  }

  void _swapFields() {
    setState(() {
      final tmp = _from;
      _from = _to;
      _to = tmp;
    });
  }

  void _setTripType(TripType type) {
    setState(() {
      _tripType = type;
      if (type == TripType.roundTrip && _returnDate.isBefore(_travelDate)) {
        _returnDate = _travelDate.add(const Duration(days: 7));
      }
    });
  }

  Future<void> _pickDepart() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _travelDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: _maxBookingDays)),
    );
    if (picked == null) return;
    setState(() {
      _travelDate = dateOnly(picked);
      if (_tripType == TripType.roundTrip &&
          _returnDate.isBefore(_travelDate)) {
        _returnDate = _travelDate;
      }
    });
  }

  Future<void> _pickReturn() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _returnDate.isBefore(_travelDate) ? _travelDate : _returnDate,
      firstDate: _travelDate,
      lastDate: _travelDate.add(const Duration(days: _maxBookingDays)),
    );
    if (picked != null) setState(() => _returnDate = dateOnly(picked));
  }

  Future<void> _onSearch() async {
    final l10n = AppLocalizations.of(context);
    if (_from == null || _to == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.carSearchSelectBothPlaces),
            duration: const Duration(seconds: 2),
          ),
        );
      return;
    }
    if (_from!.sameCoordinates(_to!)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.carSearchSamePlace),
            duration: const Duration(seconds: 2),
          ),
        );
      return;
    }

    final rounded = _tripType == TripType.roundTrip;
    final params = CarSearchParams(
      from: _from!,
      to: _to!,
      rounded: rounded,
      departDate: _travelDate,
      returnDate: rounded ? _returnDate : null,
    );

    setState(() => _searching = true);
    try {
      await ref.read(carBookingProvider.notifier).searchQuotes(params);
    } finally {
      if (mounted) setState(() => _searching = false);
    }

    if (!mounted) return;
    final state = ref.read(carBookingProvider);
    if (state.needsAuthRetry || state.quotesError != null) {
      // Results screen handles 401 gate and error retry UI.
    }
    unawaited(context.push(CarRoutes.results));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRoundTrip = _tripType == TripType.roundTrip;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TripTypeToggle(
          tripType: _tripType,
          oneWayLabel: l10n.homeTripOneWay,
          roundTripLabel: l10n.homeTripRoundTrip,
          onChanged: _setTripType,
        ),
        const SizedBox(height: 14),
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.hairline),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                children: [
                  CarPlaceField(
                    label: l10n.carPickup,
                    placeholder: l10n.carPlaceSearchHint,
                    iconBg: AppColors.primaryTint,
                    iconColor: AppColors.primary,
                    icon: AppIcons.locationFrom,
                    value: _from,
                    onChanged: (p) => setState(() => _from = p),
                    showUseMyLocation: true,
                  ),
                  const Divider(
                    color: AppColors.hairline,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  CarPlaceField(
                    label: l10n.carDropoff,
                    placeholder: l10n.carPlaceSearchHint,
                    iconBg: AppColors.secondaryTint,
                    iconColor: AppColors.secondary,
                    icon: AppIcons.locationTo,
                    value: _to,
                    onChanged: (p) => setState(() => _to = p),
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
          child: isRoundTrip
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _DateField(
                          label: l10n.homeDepart,
                          date: _travelDate,
                          compact: true,
                          onTap: _pickDepart,
                        ),
                      ),
                      const VerticalDivider(
                        color: AppColors.hairline,
                        width: 1,
                      ),
                      Expanded(
                        child: _DateField(
                          label: l10n.homeReturn,
                          date: _returnDate,
                          compact: true,
                          onTap: _pickReturn,
                        ),
                      ),
                    ],
                  ),
                )
              : _DateField(
                  label: l10n.homeDepart,
                  date: _travelDate,
                  onTap: _pickDepart,
                ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: l10n.carRequestCar,
          loading: _searching,
          onPressed: _onSearch,
        ),
      ],
    );
  }
}

class _TripTypeToggle extends StatelessWidget {
  const _TripTypeToggle({
    required this.tripType,
    required this.oneWayLabel,
    required this.roundTripLabel,
    required this.onChanged,
  });

  final TripType tripType;
  final String oneWayLabel;
  final String roundTripLabel;
  final ValueChanged<TripType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TripTypeChip(
          label: oneWayLabel,
          active: tripType == TripType.oneWay,
          onTap: () => onChanged(TripType.oneWay),
        ),
        const SizedBox(width: AppSpacing.sm),
        _TripTypeChip(
          label: roundTripLabel,
          active: tripType == TripType.roundTrip,
          onTap: () => onChanged(TripType.roundTrip),
        ),
      ],
    );
  }
}

class _TripTypeChip extends StatelessWidget {
  const _TripTypeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primaryTint : AppColors.bgBase,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: active ? AppColors.primary : AppColors.textMuted,
              fontWeight: active ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;
  final bool compact;

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
                  AppIcons.calendar,
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
              if (!compact)
                const Icon(
                  AppIcons.chevronDown,
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
              AppIcons.swap,
              color: AppColors.onPrimary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
