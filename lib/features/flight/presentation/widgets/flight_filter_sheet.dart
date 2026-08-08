import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer_filters.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Called when the rider applies. [directOnly] is the server-backed value as
/// the rider left it, and [needsSearch] is true when it changed — telling the
/// caller to re-run the search and preserve these local filters onto the new
/// results.
typedef FlightFilterApply = void Function(
  FlightOfferFilters filters, {
  required bool directOnly,
  required bool needsSearch,
});

/// One sheet holding both filter groups. Each group is badged with what it
/// costs — without that, the rider cannot tell which control throws the list
/// away and which is instant.
class FlightFilterSheet extends StatefulWidget {
  const FlightFilterSheet({
    super.key,
    required this.initial,
    required this.carriers,
    required this.priceBounds,
    required this.matchCount,
    required this.onApply,
    this.initialDirectOnly = false,
  });

  final FlightOfferFilters initial;
  final List<FlightCarrierOption> carriers;
  final (double min, double max) priceBounds;
  final int Function(FlightOfferFilters) matchCount;
  final FlightFilterApply onApply;
  final bool initialDirectOnly;

  @override
  State<FlightFilterSheet> createState() => _FlightFilterSheetState();
}

class _FlightFilterSheetState extends State<FlightFilterSheet> {
  late FlightOfferFilters _filters = widget.initial;
  late bool _directOnly = widget.initialDirectOnly;

  bool get _needsSearch => _directOnly != widget.initialDirectOnly;

  void _toggleCarrier(String code) {
    final next = Set<String>.from(_filters.carrierCodes);
    if (!next.remove(code)) next.add(code);
    setState(() => _filters = _filters.copyWith(carrierCodes: next));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (low, high) = widget.priceBounds;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GroupHeader(
              title: l10n.flightFilterServerGroup,
              badge: l10n.flightFilterServerBadge,
              badgeColor: AppColors.secondary,
              badgeBackground: AppColors.secondaryTint,
            ),
            SwitchListTile(
              key: const Key('flight-filter-direct'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.flightFilterDirectOnly,
                style: AppTypography.body,
              ),
              value: _directOnly,
              onChanged: (value) => setState(() => _directOnly = value),
            ),
            const Divider(height: AppSpacing.lg),
            _GroupHeader(
              title: l10n.flightFilterLocalGroup,
              badge: l10n.flightFilterLocalBadge,
              badgeColor: AppColors.success,
              badgeBackground: AppColors.success.withValues(alpha: 0.12),
            ),
            if (high > low) ...[
              Text(
                l10n.flightFilterPrice,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              RangeSlider(
                min: low,
                max: high,
                values: RangeValues(
                  _filters.minPrice ?? low,
                  _filters.maxPrice ?? high,
                ),
                labels: RangeLabels(
                  (_filters.minPrice ?? low).round().toString(),
                  (_filters.maxPrice ?? high).round().toString(),
                ),
                onChanged: (values) => setState(
                  () => _filters = _filters.copyWith(
                    minPrice: values.start,
                    maxPrice: values.end,
                  ),
                ),
              ),
            ],
            SwitchListTile(
              key: const Key('flight-filter-refundable'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.flightFilterRefundableOnly,
                style: AppTypography.body,
              ),
              value: _filters.refundableOnly,
              onChanged: (value) => setState(
                () => _filters = _filters.copyWith(refundableOnly: value),
              ),
            ),
            if (widget.carriers.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.flightFilterAirlines,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              for (final carrier in widget.carriers)
                CheckboxListTile(
                  key: Key('flight-filter-carrier-${carrier.code}'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _filters.carrierCodes.contains(carrier.code),
                  onChanged: (_) => _toggleCarrier(carrier.code),
                  title: Text(
                    carrier.name ?? carrier.code,
                    style: AppTypography.body,
                  ),
                  secondary: Text(
                    '${carrier.offerCount}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: l10n.flightFilterShow(widget.matchCount(_filters)),
              onPressed: () => widget.onApply(
                _filters,
                directOnly: _directOnly,
                needsSearch: _needsSearch,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.badge,
    required this.badgeColor,
    required this.badgeBackground,
  });

  final String title;
  final String badge;
  final Color badgeColor;
  final Color badgeBackground;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(title, style: AppTypography.body),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: badgeBackground,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              badge,
              style: AppTypography.caption.copyWith(color: badgeColor),
            ),
          ),
        ],
      ),
    );
  }
}
