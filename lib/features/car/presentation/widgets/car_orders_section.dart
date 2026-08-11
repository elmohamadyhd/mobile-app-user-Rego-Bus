import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/auth/presentation/auth_flow_args.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/car/domain/entities/car_order.dart';
import 'package:safaria/features/car/presentation/car_payment_webview_screen.dart';
import 'package:safaria/features/car/presentation/car_routes.dart';
import 'package:safaria/features/car/presentation/providers/car_booking_providers.dart';
import 'package:safaria/features/car/presentation/providers/car_orders_provider.dart';
import 'package:safaria/features/car/presentation/widgets/car_order_card.dart';
import 'package:safaria/features/car/presentation/widgets/car_order_detail_sheet.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/order_review_sheet.dart';
import 'package:safaria/shared/widgets/primary_button.dart';
import 'package:safaria/shared/widgets/skyline_float_card.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class CarOrdersSection extends ConsumerWidget {
  const CarOrdersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guestModeValue = ref.watch(guestModeProvider).value;
    if (guestModeValue == null) return const _OrdersSkeleton();
    if (guestModeValue) return const _GuestSignInCard();

    final ordersAsync = ref.watch(carOrdersProvider);
    return ordersAsync.when(
      loading: () => const _OrdersSkeleton(),
      error: (error, _) =>
          _ErrorState(onRetry: () => ref.invalidate(carOrdersProvider)),
      data: (orders) =>
          orders.isEmpty ? const _EmptyState() : _OrdersList(orders: orders),
    );
  }
}

class _GuestSignInCard extends StatelessWidget {
  const _GuestSignInCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SkylineFloatCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => context.go(
            AppRoutes.login,
            extra: const AuthGateArgs(returnTo: AppRoutes.tickets),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PhosphorIconsLight.user,
                    size: 22,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.profileGuestSignInCta,
                    style: AppTypography.title.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(PhosphorIconsLight.caretRight,
                    size: 20, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SkylineFloatCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text(l10n.carTicketsEmptyTitle, style: AppTypography.h1),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.carTicketsEmptyBody,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: l10n.ticketsBookCta,
              onPressed: () => context.go(AppRoutes.home),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SkylineFloatCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text(l10n.ticketsError, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(l10n.tripResultsRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersSkeleton extends StatelessWidget {
  const _OrdersSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.hairline,
      highlightColor: AppColors.bgElevated,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
    );
  }
}

class _OrdersList extends ConsumerWidget {
  const _OrdersList({required this.orders});

  final List<CarOrder> orders;

  Future<void> _cancel(
      BuildContext context, WidgetRef ref, CarOrder order) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.ticketCancelTitle),
        content: Text(l10n.ticketCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.ticketCancelKeep),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.ticketCancelConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref.read(carOrdersProvider.notifier).cancel(order.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l10n.ticketCancelSuccess : l10n.ticketCancelFailed),
      ),
    );
  }

  Future<void> _pay(BuildContext context, WidgetRef ref, CarOrder order) async {
    var checkout = order;
    if ((checkout.invoiceUrl ?? '').isEmpty) {
      final ensured =
          await ref.read(carBookingProvider.notifier).ensureCheckoutUrl(order);
      if (ensured != null) checkout = ensured;
    }
    final url = checkout.invoiceUrl ?? '';
    if (url.isEmpty || !context.mounted) return;
    ref.read(carBookingProvider.notifier).hydrateOrder(checkout);
    await context.push(
      CarRoutes.pay,
      extra: CarPaymentFlowArgs(
        checkoutUrl: url,
        orderId: checkout.id,
      ),
    );
    ref.invalidate(carOrdersProvider);
  }

  void _openVoucher(BuildContext context, WidgetRef ref, CarOrder order) {
    ref.read(carBookingProvider.notifier).hydrateOrder(order);
    context.push(CarRoutes.voucher);
  }

  Future<void> _rateOrder(
    BuildContext context,
    WidgetRef ref,
    CarOrder order,
  ) async {
    await showOrderReviewSheet(
      context,
      onSubmit: (rating, comment) async {
        await ref.read(carRepositoryProvider).submitReview(
              orderId: order.id,
              rating: rating,
              comment: comment,
            );
        await ref.read(carOrdersProvider.notifier).refresh();
        ref.invalidate(carOrderDetailProvider(order.id));
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        for (final order in orders)
          CarOrderCard(
            key: ValueKey(order.id),
            order: order,
            onTap: () => showCarOrderDetailSheet(context, order),
            onPay: () => unawaited(_pay(context, ref, order)),
            onOpenVoucher: () => _openVoucher(context, ref, order),
            onCancel: () => unawaited(_cancel(context, ref, order)),
            onRate: () => unawaited(_rateOrder(context, ref, order)),
          ),
      ],
    );
  }
}
