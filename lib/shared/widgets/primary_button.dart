import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';

enum PrimaryButtonVariant { primary, amber }

/// Skyline primary action button: solid fill, soft colored glow, and a
/// built-in loading state. Disabled when [onPressed] is null or [loading].
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.variant = PrimaryButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final PrimaryButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final bg = variant == PrimaryButtonVariant.amber
        ? AppColors.secondary
        : AppColors.primary;
    final fg = variant == PrimaryButtonVariant.amber
        ? AppColors.onSecondary
        : AppColors.onPrimary;
    final radius = BorderRadius.circular(AppRadius.input);

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: bg.withValues(alpha: 0.45),
              blurRadius: 26,
              spreadRadius: -10,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Material(
          color: bg,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: 54,
              width: double.infinity,
              child: Center(
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
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
