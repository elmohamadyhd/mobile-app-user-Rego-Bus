import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/domain/entities/bus_location.dart';
import 'package:safaria/features/bus/presentation/providers/bus_locations_provider.dart';
import 'package:safaria/l10n/app_localizations.dart';

const _baseCardHeight = 118.0;

/// Wider than half-viewport so the next card peeks (~2.2 slots visible).
const _visibleCardSlots = 2.2;

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
        final availableWidth = screenWidth - AppSpacing.lg * 2;
        final cardWidth = (availableWidth - AppSpacing.sm) / _visibleCardSlots;
        final cardHeight = _scaledCardHeight(context);
        final canScroll = locations.length > 2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.homePopularDestinations,
                    style: AppTypography.title.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              hint: canScroll ? l10n.homePopularDestinationsSwipeHint : null,
              child: SizedBox(
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
                              begin: Alignment(-0.5, -1),
                              end: Alignment(1, 1),
                            )
                          : const LinearGradient(
                              colors: [
                                AppColors.secondary,
                                AppColors.secondaryDeep,
                              ],
                              begin: Alignment(-0.5, -1),
                              end: Alignment(1, 1),
                            ),
                      enabled: !excluded,
                      onTap: () => onSelected(city),
                    );
                  },
                ),
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

class _DestCard extends StatefulWidget {
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
  State<_DestCard> createState() => _DestCardState();
}

class _DestCardState extends State<_DestCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.97 : 1.0;

    return SizedBox(
      width: widget.width,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.45,
        child: GestureDetector(
          onTapDown:
              widget.enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp:
              widget.enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel:
              widget.enabled ? () => setState(() => _pressed = false) : null,
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  gradient: widget.gradient,
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.cardShadowSoft,
                      blurRadius: 22,
                      spreadRadius: -10,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PositionedDirectional(
                      top: -18,
                      end: -12,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      bottom: -28,
                      end: -20,
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            PhosphorIconsLight.mapPin,
                            color: AppColors.onHero.withValues(alpha: 0.72),
                            size: 18,
                          ),
                          const Spacer(),
                          Text(
                            widget.city,
                            style: AppTypography.h2.copyWith(
                              color: AppColors.onHero,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
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
