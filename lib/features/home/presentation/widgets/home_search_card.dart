import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/core/utils/date_formatting.dart';
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/home/presentation/widgets/home_city_picker.dart';
import 'package:rego/features/home/presentation/widgets/home_flight_class_picker.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

enum TripType { oneWay, roundTrip }

class HomeSearchCard extends ConsumerStatefulWidget {
  const HomeSearchCard({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  static const int flightTabIndex = 2;

  @override
  ConsumerState<HomeSearchCard> createState() => _HomeSearchCardState();
}

class _HomeSearchCardState extends ConsumerState<HomeSearchCard> {
  HomeCity _fromCity = kDefaultFromCity;
  HomeCity _toCity = kDefaultToCity;
  TripType _tripType = TripType.oneWay;
  DateTime _travelDate = dateOnly(DateTime.now());
  DateTime _returnDate = dateOnly(DateTime.now().add(const Duration(days: 7)));
  FlightClass _flightClass = kDefaultFlightClass;

  static const _maxBookingDays = 90;

  void _swapFields() {
    setState(() {
      final tmp = _fromCity;
      _fromCity = _toCity;
      _toCity = tmp;
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

  Future<void> _pickFrom() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showHomeCityPicker(
      context,
      title: l10n.homeFrom,
      exclude: _toCity,
    );
    if (picked != null) setState(() => _fromCity = picked);
  }

  Future<void> _pickTo() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showHomeCityPicker(
      context,
      title: l10n.homeTo,
      exclude: _fromCity,
    );
    if (picked != null) setState(() => _toCity = picked);
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

  Future<void> _pickFlightClass() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showFlightClassPicker(
      context,
      title: l10n.homeFlightClass,
    );
    if (picked != null) setState(() => _flightClass = picked);
  }

  Future<void> _onSearch() async {
    final l10n = AppLocalizations.of(context);
    if (widget.selectedTab != 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.homeComingSoon),
            duration: const Duration(seconds: 2),
          ),
        );
      return;
    }

    await ref.read(busBookingProvider.notifier).searchTrips(
          _fromCity.apiName,
          _toCity.apiName,
          toIsoDate(_travelDate),
        );
    if (mounted) unawaited(context.push(BusRoutes.results));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = [
      (l10n.homeTabBus, AppIcons.bus),
      (l10n.homeTabPrivate, AppIcons.private),
      (l10n.homeTabFlight, AppIcons.flight),
      (l10n.homeTabTrain, AppIcons.train),
    ];
    final isRoundTrip = _tripType == TripType.roundTrip;
    final showFlightClass = widget.selectedTab == HomeSearchCard.flightTabIndex;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59146CEC),
            blurRadius: 40,
            spreadRadius: -18,
            offset: Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.bgBase,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: List.generate(tabs.length, (i) {
                final (label, icon) = tabs[i];
                final active = widget.selectedTab == i;
                return Expanded(
                  child: _TransportTab(
                    label: label,
                    icon: icon,
                    active: active,
                    onTap: () {
                      widget.onTabChanged(i);
                      if (i != 0) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(l10n.homeComingSoon),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                      }
                    },
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
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
                    _CityField(
                      label: l10n.homeFrom,
                      city: _fromCity,
                      iconBg: AppColors.primaryTint,
                      iconColor: AppColors.primary,
                      onTap: _pickFrom,
                    ),
                    const Divider(
                      color: AppColors.hairline,
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                    _CityField(
                      label: l10n.homeTo,
                      city: _toCity,
                      iconBg: AppColors.secondaryTint,
                      iconColor: const Color(0xFFD98A2B),
                      onTap: _pickTo,
                    ),
                  ],
                ),
              ),
              PositionedDirectional(
                end: 14,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _SwapButton(onTap: _swapFields),
                ),
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
          if (showFlightClass) ...[
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
          ],
          const SizedBox(height: 14),
          PrimaryButton(label: l10n.homeSearch, onPressed: _onSearch),
        ],
      ),
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
          padding: EdgeInsetsDirectional.fromSTEB(
            16,
            14,
            compact ? 16 : 16,
            14,
          ),
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
                  AppIcons.flight,
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

class _TransportTab extends StatelessWidget {
  const _TransportTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      elevation: active ? 1 : 0,
      shadowColor: const Color(0x1A000000),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: active ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.overline.copyWith(
                  color: active ? AppColors.textPrimary : AppColors.textMuted,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CityField extends StatelessWidget {
  const _CityField({
    required this.label,
    required this.city,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  final String label;
  final HomeCity city;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 56, 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(AppIcons.locationTo, color: iconColor, size: 18),
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
                      city.label(l10n),
                      style: AppTypography.title.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
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
