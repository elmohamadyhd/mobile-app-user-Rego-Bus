import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/domain/entities/bus_trip_filters.dart';
import 'package:rego/features/bus/domain/utils/apply_bus_trip_filters.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

/// Bottom sheet for client-side trip filters; resolves to applied [BusTripFilters]
/// or null when dismissed without applying.
Future<BusTripFilters?> showTripFilterSheet(
  BuildContext context, {
  required BusTripFilters initial,
  required List<BusTripSummary> trips,
}) {
  return showModalBottomSheet<BusTripFilters>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: _TripFilterSheet(
        initial: initial,
        trips: trips,
      ),
    ),
  );
}

class _TripFilterSheet extends StatefulWidget {
  const _TripFilterSheet({
    required this.initial,
    required this.trips,
  });

  final BusTripFilters initial;
  final List<BusTripSummary> trips;

  @override
  State<_TripFilterSheet> createState() => _TripFilterSheetState();
}

class _TripFilterSheetState extends State<_TripFilterSheet> {
  late BusTripFilters _draft;
  late final List<String> _operators;
  late final int _priceMin;
  late final int _priceMax;
  late final int _departMin;
  late final int _departMax;

  late RangeValues _priceRange;
  late RangeValues _departRange;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _operators = uniqueOperators(widget.trips);
    final (priceLo, priceHi) = priceBounds(widget.trips);
    _priceMin = priceLo;
    _priceMax = priceHi == priceLo ? priceLo + 1 : priceHi;
    final (departLo, departHi) = departBounds(widget.trips);
    _departMin = departLo;
    _departMax = departHi == departLo ? departLo + 1 : departHi;

    _priceRange = RangeValues(
      (_draft.minPriceEgp ?? _priceMin).toDouble(),
      (_draft.maxPriceEgp ?? _priceMax).toDouble(),
    );
    _departRange = RangeValues(
      (_draft.departAfter != null
              ? _draft.departAfter!.hour * 60 + _draft.departAfter!.minute
              : _departMin)
          .toDouble(),
      (_draft.departBefore != null
              ? _draft.departBefore!.hour * 60 + _draft.departBefore!.minute
              : _departMax)
          .toDouble(),
    );
  }

  void _toggleOperator(String name) {
    setState(() {
      final next = {..._draft.operators};
      if (next.contains(name)) {
        next.remove(name);
      } else {
        next.add(name);
      }
      _draft = _draft.copyWith(operators: next);
    });
  }

  void _onPriceChanged(RangeValues values) {
    setState(() {
      _priceRange = values;
      final minChanged = values.start.round() != _priceMin;
      final maxChanged = values.end.round() != _priceMax;
      _draft = _draft.copyWith(
        minPriceEgp: minChanged ? values.start.round() : null,
        maxPriceEgp: maxChanged ? values.end.round() : null,
      );
    });
  }

  void _onDepartChanged(RangeValues values) {
    setState(() {
      _departRange = values;
      final startMin = values.start.round();
      final endMin = values.end.round();
      _draft = _draft.copyWith(
        departAfter:
            startMin != _departMin ? minutesToTimeOfDay(startMin) : null,
        departBefore: endMin != _departMax ? minutesToTimeOfDay(endMin) : null,
      );
    });
  }

  void _clearAll() {
    setState(() {
      _draft = const BusTripFilters();
      _priceRange = RangeValues(_priceMin.toDouble(), _priceMax.toDouble());
      _departRange = RangeValues(_departMin.toDouble(), _departMax.toDouble());
    });
  }

  void _apply() {
    Navigator.of(context).pop(_draft);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.tripFilterSheetTitle,
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.close),
                    color: AppColors.textMuted,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.hairline, height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_operators.isNotEmpty) ...[
                      Text(
                        l10n.tripFilterOperators,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final name in _operators)
                            _OperatorChip(
                              label: name,
                              selected: _draft.operators.contains(name),
                              onTap: () => _toggleOperator(name),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    Text(
                      l10n.tripFilterDepartTime,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatTimeOfDay(
                            minutesToTimeOfDay(_departRange.start.round()),
                          ),
                          style: AppTypography.body,
                        ),
                        Text(
                          formatTimeOfDay(
                            minutesToTimeOfDay(_departRange.end.round()),
                          ),
                          style: AppTypography.body,
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: _departRange,
                      min: _departMin.toDouble(),
                      max: _departMax.toDouble(),
                      divisions: (_departMax - _departMin).clamp(1, 24 * 60),
                      activeColor: AppColors.primary,
                      onChanged: _onDepartChanged,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.tripFilterPrice,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_priceRange.start.round()} EGP',
                          style: AppTypography.body,
                        ),
                        Text(
                          '${_priceRange.end.round()} EGP',
                          style: AppTypography.body,
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: _priceRange,
                      min: _priceMin.toDouble(),
                      max: _priceMax.toDouble(),
                      divisions: (_priceMax - _priceMin).clamp(1, 1000),
                      activeColor: AppColors.primary,
                      onChanged: _onPriceChanged,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _clearAll,
                    child: Text(l10n.tripFilterClearAll),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: PrimaryButton(
                      label: l10n.tripFilterApply,
                      onPressed: _apply,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperatorChip extends StatelessWidget {
  const _OperatorChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? AppColors.onPrimary : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
