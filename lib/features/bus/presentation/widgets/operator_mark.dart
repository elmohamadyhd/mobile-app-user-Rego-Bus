import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';

/// Rounded-square operator mark (logo or initials) for order cards and other
/// list surfaces where a full [BusTripSummary] is not available.
class OperatorMark extends StatelessWidget {
  const OperatorMark({
    super.key,
    required this.name,
    this.logoUrl,
    this.size = 42,
  });

  final String name;
  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: hasLogo
          ? Image.network(
              logoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initials(),
            )
          : _initials(),
    );
  }

  Widget _initials() {
    final trimmed = name.trim();
    final code =
        trimmed.isNotEmpty ? trimmed.substring(0, 1).toUpperCase() : '?';
    return Text(
      code,
      style: AppTypography.body.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
        fontSize: size * 0.31,
      ),
    );
  }
}
