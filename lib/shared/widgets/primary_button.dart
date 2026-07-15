import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';

enum PrimaryButtonVariant { primary, amber, ghost }

/// Skyline primary action button: solid fill, soft colored glow, and a
/// built-in loading state. Disabled when [onPressed] is null or [loading].
///
/// [PrimaryButtonVariant.ghost] renders the same size and shape as an
/// outlined secondary action (e.g. "Continue as a guest") — transparent
/// fill, primary-colored border and label, no glow.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.variant = PrimaryButtonVariant.primary,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final PrimaryButtonVariant variant;

  /// Card-stub sizing: 40 px tall, no glow — keeps stacked actions compact.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final isGhost = variant == PrimaryButtonVariant.ghost;
    final bg = isGhost
        ? Colors.transparent
        : variant == PrimaryButtonVariant.amber
            ? AppColors.secondary
            : AppColors.primary;
    final fg = isGhost
        ? AppColors.primary
        : variant == PrimaryButtonVariant.amber
            ? AppColors.onSecondary
            : AppColors.onPrimary;
    final radius = BorderRadius.circular(AppRadius.input);
    final showGlow = !isGhost && !compact;
    final height = compact ? 40.0 : 54.0;

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: showGlow
              ? [
                  BoxShadow(
                    color: bg.withValues(alpha: 0.45),
                    blurRadius: 26,
                    spreadRadius: -10,
                    offset: const Offset(0, 14),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: bg,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            child: Container(
              height: height,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: isGhost
                  ? BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    )
                  : null,
              child: loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(fg),
                      ),
                    )
                  : Text(
                      label,
                      style: AppTypography.title.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 15 : null,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
