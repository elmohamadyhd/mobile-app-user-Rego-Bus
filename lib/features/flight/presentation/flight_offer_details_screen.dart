import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_segment_row.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

class FlightOfferDetailsScreen extends ConsumerWidget {
  const FlightOfferDetailsScreen({super.key, required this.offer});

  final FlightOffer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final journey = offer.journeys.first;
    final rules = offer.priceClasses
        .expand((c) => c.rulesAndPenalties ?? const <String>[])
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(
        title: '${journey.origin} → ${journey.destination}',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                children: [
                  for (final segment in journey.segments)
                    FlightSegmentRow(segment: segment),
                ],
              ),
            ),
            if (rules.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.flightFareRules,
                style:
                    AppTypography.title.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final rule in rules)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    '•  $rule',
                    style: AppTypography.body
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.flightPriceTotal,
              style: AppTypography.title.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            _priceRow(l10n.flightPriceBase, offer.baseAmount, offer.currency),
            _priceRow(l10n.flightPriceTaxes, offer.taxesAmount, offer.currency),
            if (offer.discountAmount > 0)
              _priceRow(
                l10n.flightPriceDiscount,
                -offer.discountAmount,
                offer.currency,
              ),
            const Divider(color: AppColors.hairline),
            _priceRow(
              l10n.flightPriceTotal,
              offer.totalAmount,
              offer.currency,
              bold: true,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: PrimaryButton(
            label: l10n.flightSelectThisFlight,
            onPressed: () {
              ref.read(flightBookingProvider.notifier).selectOffer(offer);
              context.push(FlightRoutes.review);
            },
          ),
        ),
      ),
    );
  }

  Widget _priceRow(
    String label,
    double amount,
    String currency, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: bold
                ? AppTypography.body.copyWith(fontWeight: FontWeight.w800)
                : AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            '${amount.toStringAsFixed(0)} $currency',
            style: bold
                ? AppTypography.body.copyWith(fontWeight: FontWeight.w800)
                : AppTypography.body,
          ),
        ],
      ),
    );
  }
}
