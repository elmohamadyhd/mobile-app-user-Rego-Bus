import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/domain/entities/flight_order.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Paid outcome. Reached only from a server-verified [FlightOrder] — never
/// from the checkout WebView's redirect directly.
class FlightTicketScreen extends StatelessWidget {
  const FlightTicketScreen({super.key, required this.order});

  final FlightOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pnr = order.airlinePnr ?? order.gdsPnr;

    return Scaffold(
      appBar: BookingAppBar(title: l10n.flightTicketTitle),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Icon(
            PhosphorIconsLight.checkCircle,
            size: 56,
            color: AppColors.success,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.flightTicketTitle,
            textAlign: TextAlign.center,
            style: AppTypography.h2,
          ),
          if (pnr != null && pnr.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.flightTicketPnr,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
            Text(pnr, style: AppTypography.h2),
          ],
          const SizedBox(height: AppSpacing.lg),
          for (final segment in order.segments)
            Text(
              '${segment.origin} → ${segment.destination}',
              style: AppTypography.body,
            ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: l10n.flightGoToTickets,
            onPressed: () => context.go(AppRoutes.tickets),
          ),
        ],
      ),
    );
  }
}
