import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';

/// The floating white card that overlaps the hero, holding the form fields.
class AuthCard extends StatelessWidget {
  const AuthCard({
    super.key,
    required this.children,
    this.gap = AppSpacing.md,
    this.margin = const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.lg - 6,
      0,
      AppSpacing.lg - 6,
      0,
    ),
  });

  final List<Widget> children;
  final double gap;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i != children.length - 1) spaced.add(SizedBox(height: gap));
    }

    return Container(
      margin: margin,
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.12),
            blurRadius: 28,
            spreadRadius: -12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: spaced,
      ),
    );
  }
}
