import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_theme.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/profile/presentation/widgets/profile_circle_avatar.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Skyline shell-tab hero: blue gradient, decorative blobs, curved bottom.
///
/// Used by every bottom-nav tab. Pass tab-specific content via [child].
class SkylineTabHero extends StatelessWidget {
  const SkylineTabHero({
    super.key,
    required this.child,
    this.reserveCardOverlap = true,
  });

  final Widget child;

  /// When true, extends the gradient below the content so a floating card can
  /// overlap upward (matches Home / Profile Skyline layout).
  final bool reserveCardOverlap;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.statusBarLight,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(AppRadius.hero),
            bottomRight: Radius.circular(AppRadius.hero),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            PositionedDirectional(
              top: -50,
              end: -40,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            PositionedDirectional(
              bottom: 24,
              start: -26,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: 0.13),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    child,
                    if (reserveCardOverlap) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Home-tab greeting row: avatar, caption, headline, optional trailing.
class SkylineTabGreetingRow extends StatelessWidget {
  const SkylineTabGreetingRow({
    super.key,
    required this.initial,
    required this.greeting,
    required this.headline,
    this.avatarUrl,
    this.trailing,
  });

  final String initial;
  final String? avatarUrl;
  final String greeting;
  final String headline;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProfileCircleAvatar(
          size: 42,
          initial: initial,
          networkUrl: avatarUrl,
          style: ProfileCircleAvatarStyle.hero,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: AppTypography.caption.copyWith(
                  color: AppColors.onHero.withValues(alpha: 0.78),
                ),
              ),
              Text(
                headline,
                style: AppTypography.title.copyWith(
                  color: AppColors.onHero,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Simple hero headline + optional caption for non-home shell tabs.
class SkylineTabHeroText extends StatelessWidget {
  const SkylineTabHeroText({
    super.key,
    required this.headline,
    this.caption,
  });

  final String headline;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (caption != null)
          Text(
            caption!,
            style: AppTypography.caption.copyWith(
              color: AppColors.onHero.withValues(alpha: 0.78),
            ),
          ),
        Text(
          headline,
          style: AppTypography.title.copyWith(
            color: AppColors.onHero,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Notification bell shown on the Home tab hero.
class SkylineTabHeroBellButton extends StatelessWidget {
  const SkylineTabHeroBellButton({super.key, this.onTap});

  final VoidCallback? onTap;

  static const double badgeSize = 10;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.homeNotifications,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Icon(
                  PhosphorIconsLight.bell,
                  color: AppColors.onHero,
                  size: 22,
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 8,
            end: 9,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary,
                border: Border.all(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
