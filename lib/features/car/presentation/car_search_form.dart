import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/location/device_location_gateway.dart';
import 'package:safaria/core/places/places_providers.dart';
import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/date_formatting.dart';
import 'package:safaria/features/car/domain/entities/car_place.dart';
import 'package:safaria/features/car/domain/entities/car_search_params.dart';
import 'package:safaria/features/car/presentation/car_routes.dart';
import 'package:safaria/features/car/presentation/providers/car_booking_providers.dart';
import 'package:safaria/features/car/presentation/widgets/car_place_field.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/models/trip_type.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

class CarSearchForm extends ConsumerStatefulWidget {
  const CarSearchForm({
    super.key,
    @visibleForTesting this.initialFrom,
    @visibleForTesting this.initialTo,
    @visibleForTesting this.initialTravelDate,
  });

  @visibleForTesting
  final CarPlace? initialFrom;
  @visibleForTesting
  final CarPlace? initialTo;
  @visibleForTesting
  final DateTime? initialTravelDate;

  @override
  ConsumerState<CarSearchForm> createState() => _CarSearchFormState();
}

class _CarSearchFormState extends ConsumerState<CarSearchForm> {
  CarPlace? _from;
  CarPlace? _to;
  TripType _tripType = TripType.oneWay;
  late DateTime _travelDate;
  late DateTime _returnDate;
  late TimeOfDay _departTime;
  late TimeOfDay _returnTime;
  bool _searching = false;

  static const _maxBookingDays = 90;

  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom;
    _to = widget.initialTo;
    _travelDate = dateOnly(
      widget.initialTravelDate ?? DateTime.now(),
    );
    _returnDate = dateOnly(_travelDate.add(const Duration(days: 7)));
    _departTime = defaultDepartTimeForDate(_travelDate);
    _returnTime = defaultDepartTimeForDate(_returnDate);
    // Prefill pickup only when permission is already granted — never prompt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prefillPickupIfPermitted());
    });
  }

  Future<void> _prefillPickupIfPermitted() async {
    if (!mounted || _from != null) return;
    final place =
        await ref.read(deviceLocationGatewayProvider).resolveCurrentPlace(
              places: ref.read(placesClientProvider),
              languageCode: Localizations.localeOf(context).languageCode,
              requestIfNeeded: false,
            );
    if (!mounted || place == null || _from != null) return;
    setState(() => _from = place);
  }

  // `_travelDate`/`_returnDate` are cached fields, so if the screen stays
  // alive across a midnight rollover they can fall behind the real "today".
  // Read through these getters instead of the raw fields wherever "now"
  // matters, so a stale cached date never gets treated as valid.
  DateTime get _today => dateOnly(DateTime.now());

  DateTime get _effectiveTravelDate =>
      _travelDate.isBefore(_today) ? _today : _travelDate;

  DateTime get _effectiveReturnDate =>
      _returnDate.isBefore(_effectiveTravelDate)
          ? _effectiveTravelDate
          : _returnDate;

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
      if (type == TripType.roundTrip &&
          _returnDate.isBefore(_effectiveTravelDate)) {
        _returnDate = _effectiveTravelDate.add(const Duration(days: 7));
        _returnTime = defaultDepartTimeForDate(_returnDate);
      }
    });
  }

  Future<void> _pickDepartDate() async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveTravelDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: _maxBookingDays)),
    );
    if (picked == null) return;
    setState(() {
      _travelDate = dateOnly(picked);
      _departTime = bumpTimeIfPast(_travelDate, _departTime);
      if (_tripType == TripType.roundTrip &&
          _returnDate.isBefore(_travelDate)) {
        _returnDate = _travelDate;
        _returnTime = defaultDepartTimeForDate(_returnDate);
      }
    });
  }

  Future<void> _pickReturnDate() async {
    final travelDate = _effectiveTravelDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveReturnDate,
      firstDate: travelDate,
      lastDate: travelDate.add(const Duration(days: _maxBookingDays)),
    );
    if (picked == null) return;
    setState(() {
      _returnDate = dateOnly(picked);
      _returnTime = bumpTimeIfPast(_returnDate, _returnTime);
    });
  }

  Future<void> _pickDepartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _departTime,
    );
    if (picked == null) return;
    setState(() {
      _departTime = bumpTimeIfPast(_travelDate, picked);
    });
  }

  Future<void> _pickReturnTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _returnTime,
    );
    if (picked == null) return;
    setState(() {
      _returnTime = bumpTimeIfPast(_returnDate, picked);
    });
  }

  Future<void> _onSearch() async {
    final l10n = AppLocalizations.of(context);
    if (_from == null || _to == null) return;
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

    final departDateTime = combineDateAndTime(_travelDate, _departTime);
    final now = DateTime.now();
    if (departDateTime.isBefore(now)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.carSearchDepartInPast),
            duration: const Duration(seconds: 2),
          ),
        );
      return;
    }

    final rounded = _tripType == TripType.roundTrip;
    DateTime? returnDateTime;
    if (rounded) {
      returnDateTime = combineDateAndTime(_returnDate, _returnTime);
      if (!returnDateTime.isAfter(departDateTime)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.carSearchReturnBeforeDepart),
              duration: const Duration(seconds: 2),
            ),
          );
        return;
      }
    }

    final params = CarSearchParams(
      from: _from!,
      to: _to!,
      rounded: rounded,
      departDate: departDateTime,
      returnDate: returnDateTime,
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
    final localeName = Localizations.localeOf(context).toString();
    final isRoundTrip = _tripType == TripType.roundTrip;
    final departDateTime =
        combineDateAndTime(_effectiveTravelDate, _departTime);
    final returnDateTime =
        combineDateAndTime(_effectiveReturnDate, _returnTime);

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
                    icon: PhosphorIconsLight.crosshair,
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
                    icon: PhosphorIconsLight.mapPin,
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
                        child: _DateTimeField(
                          label: l10n.homeDepart,
                          dateTime: departDateTime,
                          timeLabel: l10n.carSearchTime,
                          localeName: localeName,
                          compact: true,
                          onPickDate: _pickDepartDate,
                          onPickTime: _pickDepartTime,
                        ),
                      ),
                      const VerticalDivider(
                        color: AppColors.hairline,
                        width: 1,
                      ),
                      Expanded(
                        child: _DateTimeField(
                          label: l10n.homeReturn,
                          dateTime: returnDateTime,
                          timeLabel: l10n.carSearchTime,
                          localeName: localeName,
                          compact: true,
                          onPickDate: _pickReturnDate,
                          onPickTime: _pickReturnTime,
                        ),
                      ),
                    ],
                  ),
                )
              : _DateTimeField(
                  label: l10n.homeDepart,
                  dateTime: departDateTime,
                  timeLabel: l10n.carSearchTime,
                  localeName: localeName,
                  onPickDate: _pickDepartDate,
                  onPickTime: _pickDepartTime,
                ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: l10n.carRequestCar,
          loading: _searching,
          onPressed: (_from != null && _to != null) ? _onSearch : null,
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

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.dateTime,
    required this.timeLabel,
    required this.localeName,
    required this.onPickDate,
    required this.onPickTime,
    this.compact = false,
  });

  final String label;
  final DateTime dateTime;
  final String timeLabel;
  final String localeName;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dateValue = formatSearchDateCell(dateTime, localeName);
    final timeValue = DateFormat.jm(localeName).format(dateTime);
    final overlineStyle = AppTypography.overline.copyWith(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w600,
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: overlineStyle),
            const SizedBox(height: AppSpacing.xs),
            _TappableValue(value: dateValue, onTap: onPickDate),
            const SizedBox(height: AppSpacing.xs),
            Text(timeLabel, style: overlineStyle),
            const SizedBox(height: AppSpacing.xs),
            _TappableValue(value: timeValue, onTap: onPickTime),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                Text(label, style: overlineStyle),
                const SizedBox(height: AppSpacing.xs),
                _TappableValue(value: dateValue, onTap: onPickDate),
              ],
            ),
          ),
          const SizedBox(
            height: 40,
            child: VerticalDivider(
              color: AppColors.hairline,
              width: 1,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(timeLabel, style: overlineStyle),
                const SizedBox(height: AppSpacing.xs),
                _TappableValue(value: timeValue, onTap: onPickTime),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TappableValue extends StatelessWidget {
  const _TappableValue({
    required this.value,
    required this.onTap,
  });

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
          child: Text(
            value,
            style: AppTypography.title.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
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
