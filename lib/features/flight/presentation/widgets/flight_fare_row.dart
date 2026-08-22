import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_confirmed_order.dart';
import 'package:safaria/l10n/app_localizations.dart';

String flightPassengerFareLabel(
  AppLocalizations l10n,
  FlightPassengerFareBreakdown breakdown,
) {
  final count = breakdown.numberOfPassengers;
  return switch (breakdown.passengerTypeCode.toUpperCase()) {
    'ADT' => l10n.flightFareAdults(count),
    'CHD' => l10n.flightFareChildren(count),
    'INF' => l10n.flightFareInfants(count),
    _ => '$count × ${breakdown.passengerTypeCode}',
  };
}

class FlightFareRow extends StatelessWidget {
  const FlightFareRow({
    super.key,
    required this.label,
    required this.amount,
    required this.currency,
  });

  final String label;
  final double amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            '${amount.toStringAsFixed(0)} $currency',
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
