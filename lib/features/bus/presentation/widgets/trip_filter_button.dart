import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/core/utils/responsive.dart';
import 'package:rego/features/bus/domain/entities/bus_trip_filters.dart';
import 'package:rego/features/bus/domain/utils/apply_bus_trip_filters.dart';
import 'package:rego/l10n/app_localizations.dart';

/// Skyline filter control for trip results — 42dp visual inside a 48dp target.
class TripFilterButton extends StatelessWidget {
  const TripFilterButton({
    super.key,
    required this.filters,
    required this.onTap,
  });

  final BusTripFilters filters;
  final VoidCallback onTap;

  static const double _visualSize = 42;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final iconSize = context.textScaler.scale(20).clamp(18.0, 24.0);
    final activeCount = busTripFilterActiveCount(filters);
    final radius = BorderRadius.circular(AppRadius.lg);

    return Semantics(
      button: true,
      label: l10n.tripResultsFilter,
      child: Tooltip(
        message: l10n.tripResultsFilter,
        child: SizedBox(
          width: kMinInteractiveDimension,
          height: kMinInteractiveDimension,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: onTap,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Material(
                      color: AppColors.primary,
                      borderRadius: radius,
                      child: SizedBox(
                        width: _visualSize,
                        height: _visualSize,
                        child: Icon(
                          AppIcons.filter,
                          color: AppColors.onPrimary,
                          size: iconSize,
                        ),
                      ),
                    ),
                    if (activeCount > 0)
                      PositionedDirectional(
                        top: -2,
                        end: -2,
                        child: _FilterBadge(count: activeCount),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterBadge extends StatelessWidget {
  const _FilterBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 9 ? '9+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        // border: Border.all(color: AppColors.bgElevated, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTypography.overline.copyWith(
          color: AppColors.onSecondary,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
