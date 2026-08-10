import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/addresses/domain/entities/saved_address.dart';
import 'package:safaria/features/addresses/presentation/providers/addresses_providers.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/car/domain/entities/car_place.dart';
import 'package:safaria/l10n/app_localizations.dart';

const _baseCardHeight = 118.0;

/// Wider than half-viewport so the next card peeks (~2.2 slots visible).
const _visibleCardSlots = 2.2;

double _scaledCardHeight(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  return (_baseCardHeight * scale).clamp(_baseCardHeight, 168);
}

CarPlace carPlaceFromSavedAddress(SavedAddress address) => CarPlace(
      latitude: address.mapLocation.latitude,
      longitude: address.mapLocation.longitude,
      label: address.mapLocation.addressName,
    );

/// Horizontal saved-address cards on Home Private tab (mirrors bus popular).
class SavedAddressesStrip extends ConsumerWidget {
  const SavedAddressesStrip({
    super.key,
    required this.visible,
    this.excludePlace,
    required this.onSelected,
  });

  final bool visible;
  final CarPlace? excludePlace;
  final ValueChanged<CarPlace> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!visible) return const SizedBox.shrink();

    final isGuest = ref.watch(guestModeProvider).value ?? false;
    if (isGuest) return const SizedBox.shrink();

    final async = ref.watch(addressesProvider);
    return async.when(
      data: (page) {
        if (page.items.isEmpty) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context);
        final screenWidth = MediaQuery.sizeOf(context).width;
        final availableWidth = screenWidth - AppSpacing.lg * 2;
        final cardWidth = (availableWidth - AppSpacing.sm) / _visibleCardSlots;
        final cardHeight = _scaledCardHeight(context);
        final canScroll = page.items.length > 2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.homeSavedAddresses,
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
              hint: canScroll ? l10n.homeSavedAddressesSwipeHint : null,
              child: SizedBox(
                height: cardHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: page.items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final address = page.items[i];
                    final place = carPlaceFromSavedAddress(address);
                    final excluded = excludePlace != null &&
                        place.sameCoordinates(excludePlace!);
                    return _AddressCard(
                      width: cardWidth,
                      height: cardHeight,
                      title: address.name,
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
                      onTap: () => onSelected(place),
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

class _AddressCard extends StatefulWidget {
  const _AddressCard({
    required this.width,
    required this.height,
    required this.title,
    required this.gradient,
    required this.enabled,
    required this.onTap,
  });

  final double width;
  final double height;
  final String title;
  final LinearGradient gradient;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_AddressCard> createState() => _AddressCardState();
}

class _AddressCardState extends State<_AddressCard> {
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
                            widget.title,
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
