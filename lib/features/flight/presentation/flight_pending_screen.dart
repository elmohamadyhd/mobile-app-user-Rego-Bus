import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/domain/entities/flight_order.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Unpaid outcome. The order already exists server-side, so retrying reopens
/// the same checkout rather than creating a second booking.
class FlightPendingScreen extends StatelessWidget {
  const FlightPendingScreen({super.key, required this.order});

  final FlightOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final checkoutUrl = order.checkoutUrl;

    return Scaffold(
      appBar: BookingAppBar(title: l10n.flightPendingTitle),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Icon(
            PhosphorIconsLight.clock,
            size: 56,
            color: AppColors.warning,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.flightPendingTitle,
            textAlign: TextAlign.center,
            style: AppTypography.h2,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.flightPendingBody,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (checkoutUrl != null && checkoutUrl.isNotEmpty)
            PrimaryButton(
              label: l10n.flightPendingRetry,
              onPressed: () => context.push(FlightRoutes.pay, extra: order),
            ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: l10n.flightGoToTickets,
            variant: PrimaryButtonVariant.ghost,
            onPressed: () => context.go(AppRoutes.tickets),
          ),
        ],
      ),
    );
  }
}
