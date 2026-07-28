import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/car/presentation/car_routes.dart';
import 'package:safaria/features/car/presentation/providers/car_booking_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class CarPaymentPendingScreen extends ConsumerWidget {
  const CarPaymentPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final order = ref.watch(carBookingProvider.select((s) => s.order));

    void goHome() {
      context.go(AppRoutes.home);
      Future.microtask(() => ref.read(carBookingProvider.notifier).reset());
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        goHome();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.secondaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PhosphorIconsLight.calendarBlank,
                    color: AppColors.secondary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.paymentPendingTitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.h1,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.carPaymentPendingBody,
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (order != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.carVoucherOrderId(order.orderId),
                    textAlign: TextAlign.center,
                    style: AppTypography.title,
                  ),
                  if (order.trip != null)
                    Text(
                      '${order.trip!.fromLocation.name} → ${order.trip!.toLocation.name}',
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: l10n.paymentPendingComplete,
                  onPressed: () => context.push(CarRoutes.pay),
                ),
                const SizedBox(height: AppSpacing.sm),
                PrimaryButton(
                  label: l10n.paymentPendingBackHome,
                  variant: PrimaryButtonVariant.ghost,
                  onPressed: goHome,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
