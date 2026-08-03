import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/domain/entities/bus_location.dart';
import 'package:safaria/features/bus/presentation/providers/bus_locations_provider.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Amber gradient end — legacy card tone; no darker `AppColors.secondary` token.
const _amberGradientEnd = Color(0xFFE0871A);

const _baseCardHeight = 118.0;

double _scaledCardHeight(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  return (_baseCardHeight * scale).clamp(_baseCardHeight, 168);
}

class PopularDestinations extends ConsumerWidget {
  const PopularDestinations({
    super.key,
    required this.visible,
    this.excludeCityId,
    required this.onSelected,
  });

  final bool visible;
  final int? excludeCityId;
  final ValueChanged<BusLocation> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!visible) return const SizedBox.shrink();

    final async = ref.watch(busLocationsProvider);
    return async.when(
      data: (locations) {
        if (locations.isEmpty) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context);
        final locale = Localizations.localeOf(context).languageCode;
        final screenWidth = MediaQuery.sizeOf(context).width;
        final cardWidth =
            (screenWidth - AppSpacing.lg * 2 - AppSpacing.sm) / 2;
        final cardHeight = _scaledCardHeight(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.homePopularDestinations,
              style: AppTypography.title.copyWith(fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: cardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: locations.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final city = locations[i];
                  final excluded =
                      excludeCityId != null && city.id == excludeCityId;
                  return _DestCard(
                    width: cardWidth,
                    height: cardHeight,
                    city: city.displayName(locale),
                    gradient: i.isEven
                        ? const LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryDeep,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [
                              AppColors.secondary,
                              _amberGradientEnd,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    enabled: !excluded,
                    onTap: () => onSelected(city),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _DestCard extends StatelessWidget {
  const _DestCard({
    required this.width,
    required this.height,
    required this.city,
    required this.gradient,
    required this.enabled,
    required this.onTap,
  });

  final double width;
  final double height;
  final String city;
  final LinearGradient gradient;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: Container(
                height: height,
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
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: Text(
                          city,
                          style: AppTypography.h2.copyWith(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
