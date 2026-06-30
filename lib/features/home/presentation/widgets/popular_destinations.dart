import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/l10n/app_localizations.dart';

class PopularDestinations extends StatelessWidget {
  const PopularDestinations({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.homePopularDestinations,
              style: AppTypography.title
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: () => ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(content: Text(l10n.homeComingSoon)),
                ),
              child: Text(
                l10n.homeSeeAll,
                style: AppTypography.caption
                    .copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _DestCard(
                city: l10n.homeCityLuxor,
                fromCity: l10n.homeCityCairo,
                fromLabel: l10n.homeFrom,
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _DestCard(
                city: l10n.homeCityAswan,
                fromCity: l10n.homeCityCairo,
                fromLabel: l10n.homeFrom,
                gradient: const LinearGradient(
                  colors: [AppColors.secondary, Color(0xFFD4873A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DestCard extends StatelessWidget {
  const _DestCard({
    required this.city,
    required this.fromCity,
    required this.fromLabel,
    required this.gradient,
  });

  final String city;
  final String fromCity;
  final String fromLabel;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            city,
            style: AppTypography.title.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '$fromLabel $fromCity',
            style: AppTypography.caption.copyWith(
              color: AppColors.onPrimary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
