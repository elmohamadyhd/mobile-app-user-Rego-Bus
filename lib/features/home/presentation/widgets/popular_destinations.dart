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
          children: [
            Expanded(
              child: Text(
                l10n.homePopularDestinations,
                style:
                    AppTypography.title.copyWith(fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(l10n.homeComingSoon),
                  ),
                ),
              child: Text(
                l10n.homeSeeAll,
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
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
                price: 240,
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D6FF2), AppColors.primaryDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _DestCard(
                city: l10n.homeCityAswan,
                price: 290,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFBA834), Color(0xFFE0871A)],
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
    required this.price,
    required this.gradient,
  });

  final String city;
  final int price;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        height: 118,
        decoration: BoxDecoration(gradient: gradient),
        child: Stack(
          children: [
            PositionedDirectional(
              bottom: -24,
              end: -16,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    city,
                    style: AppTypography.h2.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    l10n.homeFromPrice(price),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.onPrimary.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
