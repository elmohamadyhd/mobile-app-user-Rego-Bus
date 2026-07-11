import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/l10n/app_localizations.dart';

/// Ordered steps of the bus booking wizard, in flow order.
enum BusBookingStep { route, seat, confirm }

/// Shared progress header shown at the top of each booking screen: Route →
/// Seat → Confirm. Completed steps are tappable and pop the navigation stack
/// back to that screen; the current step is emphasized; upcoming steps are
/// muted and inert — forward movement is gated by each screen's own
/// call-to-action, never by this bar.
class BookingStepBar extends StatelessWidget {
  const BookingStepBar({super.key, required this.current});

  final BusBookingStep current;

  static const _steps = BusBookingStep.values;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 20),
                  color: i <= current.index
                      ? AppColors.primary
                      : AppColors.hairline,
                ),
              ),
            _StepNode(
              label: _labelFor(l10n, _steps[i]),
              icon: _iconFor(_steps[i]),
              isCompleted: i < current.index,
              isCurrent: i == current.index,
              onTap: i < current.index
                  ? () => _goToStep(context, _steps[i])
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  String _labelFor(AppLocalizations l10n, BusBookingStep step) {
    return switch (step) {
      BusBookingStep.route => l10n.bookingStepRoute,
      BusBookingStep.seat => l10n.bookingStepSeat,
      BusBookingStep.confirm => l10n.bookingStepConfirm,
    };
  }

  IconData _iconFor(BusBookingStep step) {
    return switch (step) {
      BusBookingStep.route => AppIcons.locationTo,
      BusBookingStep.seat => AppIcons.ticket,
      BusBookingStep.confirm => AppIcons.checkCircle,
    };
  }

  void _goToStep(BuildContext context, BusBookingStep target) {
    final hops = current.index - target.index;
    for (var i = 0; i < hops; i++) {
      if (!context.canPop()) return;
      context.pop();
    }
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.label,
    required this.icon,
    required this.isCompleted,
    required this.isCurrent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isCompleted;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final filled = isCompleted || isCurrent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? AppColors.primary : AppColors.bgElevated,
                border: filled
                    ? null
                    : Border.all(color: AppColors.hairline, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Icon(
                isCompleted ? AppIcons.check : icon,
                size: 15,
                color: filled ? AppColors.onPrimary : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: filled ? AppColors.primary : AppColors.textMuted,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
