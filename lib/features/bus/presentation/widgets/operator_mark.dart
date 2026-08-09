import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';

/// Rounded-square operator mark (logo or initials) for list/ticket surfaces.
///
/// Logos sit on a neutral plate with clear space so brand assets keep their
/// proportions; initials keep the brand tint when no logo is available.
class OperatorMark extends StatelessWidget {
  const OperatorMark({
    super.key,
    required this.name,
    this.logoUrl,
    this.size = 48,
  });

  final String name;
  final String? logoUrl;
  final double size;

  /// Inset so logos keep brand clear-space inside the plate (~16% of size).
  double get _logoInset => (size * 0.16).clamp(AppSpacing.xs, AppSpacing.sm);

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plateColor = hasLogo
        ? (isDark ? AppColors.darkBgCard : AppColors.bgElevated)
        : AppColors.primaryTint;
    final borderColor = hasLogo
        ? (isDark ? AppColors.darkBorder : AppColors.border)
        : Colors.transparent;

    return Semantics(
      label: name,
      image: hasLogo,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: plateColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: borderColor),
        ),
        child: hasLogo
            ? Padding(
                padding: EdgeInsets.all(_logoInset),
                child: Image.network(
                  logoUrl!,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return ColoredBox(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.hairline,
                    );
                  },
                  errorBuilder: (_, __, ___) => _initials(),
                ),
              )
            : _initials(),
      ),
    );
  }

  Widget _initials() {
    return Text(
      _initialsCode(name),
      style: AppTypography.body.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
        fontSize: size * 0.31,
      ),
    );
  }

  /// Two-letter mark when the name has multiple words ("Blue Bus" → "BB").
  static String _initialsCode(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.length >= 2
        ? trimmed.substring(0, 2).toUpperCase()
        : trimmed[0].toUpperCase();
  }
}
