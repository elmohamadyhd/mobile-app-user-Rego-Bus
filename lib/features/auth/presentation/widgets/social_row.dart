import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/shared/widgets/brand_mark.dart';

/// "or continue with" divider plus the Google sign-in button.
class SocialRow extends StatelessWidget {
  const SocialRow({
    super.key,
    required this.dividerLabel,
    required this.onGoogleTap,
    this.busy = false,
  });

  final String dividerLabel;
  final VoidCallback onGoogleTap;

  /// True while a Google sign-in is in flight — shows a spinner on the
  /// button and ignores taps instead of firing [onGoogleTap] again.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.hairline)),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + AppSpacing.xs,
              ),
              child: Text(
                dividerLabel,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const Expanded(child: Divider(color: AppColors.hairline)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: _SocialButton(BrandMark.google, onGoogleTap, busy)),
          ],
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton(this.asset, this.onTap, this.busy);

  final String asset;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.input);
    return Material(
      color: AppColors.bgCard,
      borderRadius: radius,
      child: InkWell(
        key: const Key('googleSignInButton'),
        borderRadius: radius,
        onTap: busy ? null : onTap,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppColors.hairline),
          ),
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : BrandMark(asset, size: 26),
        ),
      ),
    );
  }
}
