import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_wizard_step.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/ltr_icon.dart';

/// Progress header for the flight booking wizard. The step list is derived
/// from the offer, so an offer without bundles shows three nodes rather than
/// four with one unreachable.
///
/// Completed steps pop back to their screen; upcoming steps are inert —
/// forward movement is gated by each screen's own call to action.
class FlightBookingStepBar extends StatelessWidget {
  const FlightBookingStepBar({
    super.key,
    required this.current,
    required this.haveBundles,
  });

  final FlightWizardStep current;
  final bool haveBundles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = flightWizardSteps(haveBundles: haveBundles);
    final currentIndex =
        flightWizardStepIndex(current, haveBundles: haveBundles) ?? 0;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 20),
                  color: i <= currentIndex
                      ? AppColors.primary
                      : AppColors.hairline,
                ),
              ),
            _StepNode(
              label: _labelFor(l10n, steps[i]),
              icon: _iconFor(steps[i]),
              isCompleted: i < currentIndex,
              isCurrent: i == currentIndex,
              onTap:
                  i < currentIndex ? () => Navigator.of(context).pop() : null,
            ),
          ],
        ],
      ),
    );
  }

  static String _labelFor(AppLocalizations l10n, FlightWizardStep step) {
    return switch (step) {
      FlightWizardStep.review => l10n.flightStepReview,
      FlightWizardStep.bundles => l10n.flightStepBundles,
      FlightWizardStep.passengers => l10n.flightStepPassengers,
      FlightWizardStep.pay => l10n.flightStepPay,
    };
  }

  static IconData _iconFor(FlightWizardStep step) {
    return switch (step) {
      FlightWizardStep.review => PhosphorIconsLight.clipboardText,
      FlightWizardStep.bundles => PhosphorIconsLight.package,
      FlightWizardStep.passengers => PhosphorIconsLight.users,
      FlightWizardStep.pay => PhosphorIconsLight.creditCard,
    };
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.label,
    required this.icon,
    required this.isCompleted,
    required this.isCurrent,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isCompleted;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = isCompleted || isCurrent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent
                      ? AppColors.primary
                      : isCompleted
                          ? AppColors.primaryTint
                          : Colors.transparent,
                  border: Border.all(
                    color: active ? AppColors.primary : AppColors.hairline,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? const LtrIcon(
                        PhosphorIconsLight.check,
                        size: 14,
                        color: AppColors.primary,
                      )
                    : LtrIcon(
                        icon,
                        size: 14,
                        color: isCurrent
                            ? AppColors.onPrimary
                            : AppColors.textMuted,
                      ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: isCurrent
                      ? AppColors.primary
                      : active
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
