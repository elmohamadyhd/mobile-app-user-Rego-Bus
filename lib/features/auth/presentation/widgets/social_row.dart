import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/shared/widgets/brand_mark.dart';

/// "or continue with" divider plus the three social brand buttons.
///
/// The buttons are shown for design fidelity but are not yet wired to social
/// auth — tapping invokes [onDisabledTap] (a "coming soon" hint).
class SocialRow extends StatelessWidget {
  const SocialRow({
    super.key,
    required this.dividerLabel,
    required this.onDisabledTap,
  });

  final String dividerLabel;
  final VoidCallback onDisabledTap;

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
            Expanded(child: _SocialButton(BrandMark.google, onDisabledTap)),
          ],
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton(this.asset, this.onTap);

  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.input);
    return Material(
      color: AppColors.bgCard,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppColors.hairline),
          ),
          child: BrandMark(asset, size: 26),
        ),
      ),
    );
  }
}
