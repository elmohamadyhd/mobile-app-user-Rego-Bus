import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_spacing.dart';

/// Scroll layout shared by bottom-nav shell tab bodies.
///
/// Renders a [hero] at the top and [children] floated upward over it using
/// [cardOverlap], with horizontal page padding and bottom inset for the nav bar.
class ShellTabScrollView extends StatelessWidget {
  const ShellTabScrollView({
    super.key,
    required this.hero,
    required this.children,
    this.cardOverlap = AppSpacing.xxl,
    this.physics,
  });

  final Widget hero;
  final List<Widget> children;
  final double cardOverlap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: physics,
      padding: EdgeInsetsDirectional.only(
        bottom: MediaQuery.paddingOf(context).bottom +
            AppSpacing.md +
            MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          hero,
          for (final child in children)
            Transform.translate(
              offset: Offset(0, -cardOverlap),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: child,
              ),
            ),
        ],
      ),
    );
  }
}
