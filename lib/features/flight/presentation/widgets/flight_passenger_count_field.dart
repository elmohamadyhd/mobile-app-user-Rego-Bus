import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_rules.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Adult/child/infant picker. Increments disable with a stated reason rather
/// than failing silently — a dead control with no explanation is the failure
/// mode this screen exists to avoid.
class FlightPassengerCountSheet extends StatefulWidget {
  const FlightPassengerCountSheet({
    super.key,
    required this.initial,
    required this.onApply,
  });

  final FlightPassengerCounts initial;
  final ValueChanged<FlightPassengerCounts> onApply;

  @override
  State<FlightPassengerCountSheet> createState() =>
      _FlightPassengerCountSheetState();
}

class _FlightPassengerCountSheetState extends State<FlightPassengerCountSheet> {
  late FlightPassengerCounts _counts = widget.initial;

  void _add(FlightPassengerType type) {
    if (!canAddFlightPassenger(_counts, type)) return;
    setState(() {
      _counts = switch (type) {
        FlightPassengerType.adult =>
          _counts.copyWith(adults: _counts.adults + 1),
        FlightPassengerType.child =>
          _counts.copyWith(children: _counts.children + 1),
        FlightPassengerType.infant =>
          _counts.copyWith(infants: _counts.infants + 1),
      };
    });
  }

  void _remove(FlightPassengerType type) {
    if (!canRemoveFlightPassenger(_counts, type)) return;
    setState(() {
      _counts = switch (type) {
        FlightPassengerType.adult =>
          _counts.copyWith(adults: _counts.adults - 1),
        FlightPassengerType.child =>
          _counts.copyWith(children: _counts.children - 1),
        FlightPassengerType.infant =>
          _counts.copyWith(infants: _counts.infants - 1),
      };
    });
  }

  /// The most relevant blocked rule across all three rows, or null when
  /// nothing is blocked. Total-cap wins because it explains every row at once.
  String? _limitMessage(AppLocalizations l10n) {
    if (_counts.total >= kMaxFlightPassengers) return l10n.flightPaxLimitTotal;
    if (flightPassengerLimit(_counts, FlightPassengerType.infant) ==
        FlightPassengerLimit.infantsPerAdult) {
      return l10n.flightPaxLimitInfants;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final limit = _limitMessage(l10n);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.flightPaxTitle, style: AppTypography.h2),
              Text(
                l10n.flightPaxCount(_counts.total, kMaxFlightPassengers),
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _CountRow(
            keyPrefix: 'adult',
            label: l10n.flightPaxAdults,
            hint: l10n.flightPaxAdultsAge,
            value: _counts.adults,
            canAdd: canAddFlightPassenger(_counts, FlightPassengerType.adult),
            canRemove:
                canRemoveFlightPassenger(_counts, FlightPassengerType.adult),
            onAdd: () => _add(FlightPassengerType.adult),
            onRemove: () => _remove(FlightPassengerType.adult),
          ),
          _CountRow(
            keyPrefix: 'child',
            label: l10n.flightPaxChildren,
            hint: l10n.flightPaxChildrenAge,
            value: _counts.children,
            canAdd: canAddFlightPassenger(_counts, FlightPassengerType.child),
            canRemove:
                canRemoveFlightPassenger(_counts, FlightPassengerType.child),
            onAdd: () => _add(FlightPassengerType.child),
            onRemove: () => _remove(FlightPassengerType.child),
          ),
          _CountRow(
            keyPrefix: 'infant',
            label: l10n.flightPaxInfants,
            hint: l10n.flightPaxInfantsAge,
            value: _counts.infants,
            canAdd: canAddFlightPassenger(_counts, FlightPassengerType.infant),
            canRemove:
                canRemoveFlightPassenger(_counts, FlightPassengerType.infant),
            onAdd: () => _add(FlightPassengerType.infant),
            onRemove: () => _remove(FlightPassengerType.infant),
          ),
          if (limit != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.secondaryTint,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsLight.info,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      limit,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.secondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: l10n.flightPaxApply,
            onPressed: () => widget.onApply(_counts),
          ),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.keyPrefix,
    required this.label,
    required this.hint,
    required this.value,
    required this.canAdd,
    required this.canRemove,
    required this.onAdd,
    required this.onRemove,
  });

  final String keyPrefix;
  final String label;
  final String hint;
  final int value;
  final bool canAdd;
  final bool canRemove;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.body),
                Text(
                  hint,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          _StepButton(
            key: Key('flight-pax-remove-$keyPrefix'),
            icon: PhosphorIconsLight.minus,
            enabled: canRemove,
            onTap: onRemove,
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
          ),
          _StepButton(
            key: Key('flight-pax-add-$keyPrefix'),
            icon: PhosphorIconsLight.plus,
            enabled: canAdd,
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: enabled ? onTap : null,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: enabled ? color : AppColors.hairline),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
