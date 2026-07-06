import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/core/theme/app_typography.dart';

/// The signature Skyline hero: an immersive blue gradient with curved bottom
/// corners and translucent decorative "blobs". Reused by the auth screens and
/// (later) Home.
class GradientHero extends StatelessWidget {
  const GradientHero({
    super.key,
    this.title,
    this.subtitle,
    this.showWordmark = true,
    this.padding = const EdgeInsets.fromLTRB(26, 64, 26, 40),
    this.reserveCardOverlap = false,
    this.child,
  });

  final String? title;
  final String? subtitle;
  final bool showWordmark;
  final EdgeInsets padding;

  /// When true, extends the gradient below the text so a floating card can
  /// overlap upward (matches Home / Profile Skyline layout).
  final bool reserveCardOverlap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    // Full-bleed: the Stack would otherwise shrink-wrap to its text content
    // (the parent Column centers it), collapsing the hero into a floating
    // card. Forcing infinite width makes it span the screen edge-to-edge.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.statusBarLight,
      child: SizedBox(
        width: double.infinity,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppRadius.hero),
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppColors.heroGradient),
            child: Stack(
              children: [
                Positioned(
                  top: -40,
                  right: -30,
                  child: _blob(150, Colors.white.withValues(alpha: 0.08)),
                ),
                Positioned(
                  bottom: -20,
                  left: 24,
                  child: _blob(80, AppColors.secondary.withValues(alpha: 0.14)),
                ),
                Padding(
                  padding: padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showWordmark) ...[
                        Image.asset(
                          'assets/rego-wordmark-white.png',
                          width: 92,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (title != null)
                        Text(
                          title!,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: AppColors.onHero,
                          ),
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onHero.withValues(alpha: 0.88),
                          ),
                        ),
                      ],
                      if (child != null) child!,
                      if (reserveCardOverlap)
                        const SizedBox(
                          height: AppSpacing.lg + AppSpacing.xxl,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
