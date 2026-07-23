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

    final borderColor = selected ? AppColors.primary : AppColors.hairline;
    final background = selected ? AppColors.primaryTint : AppColors.bgElevated;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: borderColor,
              width: selected ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VehicleImage(quote: quote),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            quote.company.name,
                            style: AppTypography.title.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (quote.company.refundability)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              l10n.carRefundable,
                              style: AppTypography.overline.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _vehicleSubtitle(quote),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _metaLine(l10n, quote),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
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

  String _metaLine(AppLocalizations l10n, CarTripQuote quote) {
    final seats = l10n.carSeats(quote.vehicle.seatsNumber);
    final big = quote.vehicle.bigBagsCount ?? 0;
    final small = quote.vehicle.smallBagsCount ?? 0;
    final bags = l10n.carBags(big, small);
    final gear = _gearLabel(l10n, quote.vehicle.gearType);
    return '$seats · $bags · $gear';
  }

  String _gearLabel(AppLocalizations l10n, String? gearType) {
    if (gearType == 'manual') return l10n.carGearManual;
    return l10n.carGearAutomatic;
  }
}

class _VehicleImage extends StatelessWidget {
  const _VehicleImage({required this.quote});

  final CarTripQuote quote;

  @override
  Widget build(BuildContext context) {
    final url = quote.vehicle.featuredUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 56,
        height: 56,
        color: AppColors.bgBase,
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  AppIcons.private,
                  color: AppColors.primary,
                ),
              )
            : const Icon(
                AppIcons.private,
                color: AppColors.primary,
              ),
      ),
    );
  }
}
