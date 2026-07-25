import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_icons.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_theme.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/ltr_text.dart';

/// Immersive gradient header for the wallet screen: back navigation, title,
/// and the available balance displayed on the hero.
class WalletHeroHeader extends StatelessWidget {
  const WalletHeroHeader({
    super.key,
    required this.balance,
    required this.currency,
    this.onBack,
  });

  final double balance;
  final String currency;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
              bottom: 48,
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
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _HeroBackButton(
                          onTap: onBack ?? () => context.pop(),
                        ),
                        Expanded(
                          child: Text(
                            l10n.walletTitle,
                            textAlign: TextAlign.center,
                            style: AppTypography.title.copyWith(
                              color: AppColors.onHero,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.walletBalanceLabel,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.onHero.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        LtrText(
                          balance.toStringAsFixed(2),
                          style: AppTypography.display.copyWith(
                            color: AppColors.onHero,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        LtrText(
                          currency,
                          style: AppTypography.title.copyWith(
                            color: AppColors.onHero.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
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

class _HeroBackButton extends StatelessWidget {
  const _HeroBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final radius = BorderRadius.circular(AppRadius.lg);

    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Transform.flip(
            flipX: isRtl,
            child: const Icon(AppIcons.back, color: AppColors.onHero),
          ),
        ),
      ),
    );
  }
}
