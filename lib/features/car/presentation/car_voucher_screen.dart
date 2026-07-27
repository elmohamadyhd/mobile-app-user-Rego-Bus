import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_icons.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/features/car/presentation/providers/car_booking_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

class CarVoucherScreen extends ConsumerWidget {
  const CarVoucherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final order = ref.watch(carBookingProvider.select((s) => s.order));

    void goHome() {
      context.go(AppRoutes.home);
      Future.microtask(() => ref.read(carBookingProvider.notifier).reset());
    }

    if (order == null) {
      return const Scaffold(
        backgroundColor: AppColors.primaryDeep,
        body:  DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.heroGradient),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final trip = order.trip;
    final routeLabel = trip == null
        ? ''
        : '${trip.fromLocation.name} → ${trip.toLocation.name}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        goHome();
      },
      child: Scaffold(
        backgroundColor: AppColors.primaryDeep,
        body: SizedBox.expand(
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppColors.heroGradient),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.lg),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppBreakpoints.maxContentWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        children: [
                          const SizedBox(height: AppSpacing.lg),
                          const Icon(
                            AppIcons.checkCircle,
                            color: AppColors.onHero,
                            size: 56,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            l10n.carVoucherTitle,
                            textAlign: TextAlign.center,
                            style: AppTypography.h1.copyWith(
                              color: AppColors.onHero,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.carVoucherSubtitle,
                            textAlign: TextAlign.center,
                            style: AppTypography.body.copyWith(
                              color: AppColors.onHero.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.bgElevated,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.card),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.carVoucherOrderId(order.orderId),
                                  style: AppTypography.h2,
                                ),
                                if (routeLabel.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(routeLabel, style: AppTypography.body),
                                ],
                                if (order.departureDate != null) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    order.departureDate!,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                                if (trip != null) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    '${trip.vehicle.categoryName} · ${trip.company.name}',
                                    style: AppTypography.body,
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  '${order.currency} ${order.price}',
                                  style: AppTypography.h1.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          PrimaryButton(
                            label: l10n.carVoucherBackHome,
                            onPressed: goHome,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
