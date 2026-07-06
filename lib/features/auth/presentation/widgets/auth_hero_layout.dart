import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/shared/widgets/gradient_hero.dart';

/// Skyline auth header: blue gradient hero with a floating card overlapping
/// upward — same pattern as [HomeScreen] and [ProfileScreen].
class AuthHeroLayout extends StatelessWidget {
  const AuthHeroLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GradientHero(
          title: title,
          subtitle: subtitle,
          reserveCardOverlap: true,
        ),
        Transform.translate(
          offset: const Offset(0, -AppSpacing.lg),
          child: child,
        ),
      ],
    );
  }
}
