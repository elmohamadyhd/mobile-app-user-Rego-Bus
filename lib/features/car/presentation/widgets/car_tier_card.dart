import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/car/domain/entities/car_trip_quote.dart';
import 'package:rego/l10n/app_localizations.dart';

class CarTierCard extends StatelessWidget {
  const CarTierCard({
    super.key,
    required this.quote,
    required this.rounded,
    required this.selected,
    required this.onTap,
  });

  final CarTripQuote quote;
  final bool rounded;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final price = quote.priceFor(rounded: rounded);
    final priceText = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    ).format(price);

    final borderColor = selected ? AppColors.primary : AppColors.border;
    final background = selected ? AppColors.primaryTint : AppColors.bgElevated;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.18)
                : AppColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: selected ? 18 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: borderColor,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _VehicleImage(quote: quote),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    quote.company.name,
                                    style: AppTypography.title.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                _SelectionMark(selected: selected),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _vehicleSubtitle(quote),
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (quote.company.refundability) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: _RefundableBadge(
                                  label: l10n.carRefundable,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            priceText,
                            style: AppTypography.h2.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            quote.currency,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(height: 1, color: AppColors.hairline),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _SpecChip(
                        icon: AppIcons.seats,
                        label: l10n.carSeats(quote.vehicle.seatsNumber),
                      ),
                      _SpecChip(
                        icon: AppIcons.luggage,
                        label: l10n.carBags(
                          quote.vehicle.bigBagsCount ?? 0,
                          quote.vehicle.smallBagsCount ?? 0,
                        ),
                      ),
                      _SpecChip(
                        icon: AppIcons.gear,
                        label: _gearLabel(l10n, quote.vehicle.gearType),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _vehicleSubtitle(CarTripQuote quote) {
    final model = quote.vehicle.model;
    if (model != null && model.isNotEmpty) {
      return '${quote.vehicle.categoryName} · $model';
    }
    return quote.vehicle.categoryName;
  }

  String _gearLabel(AppLocalizations l10n, String? gearType) {
    if (gearType == 'manual') return l10n.carGearManual;
    return l10n.carGearAutomatic;
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(
              AppIcons.check,
              size: 14,
              color: AppColors.onPrimary,
            )
          : null,
    );
  }
}

class _RefundableBadge extends StatelessWidget {
  const _RefundableBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTypography.overline.copyWith(
          color: AppColors.success,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleImage extends StatelessWidget {
  const _VehicleImage({required this.quote});

  final CarTripQuote quote;

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    final url = quote.vehicle.featuredUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: _size,
        height: _size,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [AppColors.primaryTint, AppColors.inputFill],
          ),
        ),
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  AppIcons.transfer,
                  color: AppColors.primary,
                  size: 28,
                ),
              )
            : const Icon(
                AppIcons.transfer,
                color: AppColors.primary,
                size: 28,
              ),
      ),
    );
  }
}
