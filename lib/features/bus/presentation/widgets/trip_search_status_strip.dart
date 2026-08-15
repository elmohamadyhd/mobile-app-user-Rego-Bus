import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Tells the rider whether the results list is still filling in.
///
/// `complete` renders nothing on purpose: a settled search needs no chrome,
/// and a permanent "search finished" banner is noise on every result set.
class TripSearchStatusStrip extends StatelessWidget {
  const TripSearchStatusStrip({
    super.key,
    required this.phase,
    required this.onCheckForMore,
  });

  final BusSearchPhase phase;
  final VoidCallback onCheckForMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (phase) {
      case BusSearchPhase.idle:
      case BusSearchPhase.complete:
        return const SizedBox.shrink();
      case BusSearchPhase.polling:
        return _Frame(
          child: Row(
            children: [
              const SizedBox(
                width: 56,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: AppColors.hairline,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.tripResultsSearchingMore,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        );
      case BusSearchPhase.exhausted:
        return _Frame(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.tripResultsSlowOperators,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: onCheckForMore,
                child: Text(l10n.tripResultsCheckForMore),
              ),
            ],
          ),
        );
    }
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.bgElevated,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: child,
    );
  }
}
