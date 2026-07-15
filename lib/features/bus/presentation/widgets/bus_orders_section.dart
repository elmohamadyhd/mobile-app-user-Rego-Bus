import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/auth/presentation/auth_flow_args.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/bus/domain/entities/bus_order.dart';
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/bus/presentation/payment_webview_screen.dart';
import 'package:rego/features/bus/presentation/providers/bus_orders_provider.dart';
import 'package:rego/features/bus/presentation/widgets/bus_order_card.dart';
import 'package:rego/features/bus/presentation/widgets/ticket_border.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

/// The bus-owned section dropped into the "My Tickets" tab shell
/// (`TicketsScreen`). Renders guest/loading/error/empty/list states for the
/// signed-in rider's bus orders — flight/car will add their own sibling
/// sections later, each equally self-contained.
class BusOrdersSection extends ConsumerWidget {
  const BusOrdersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `guestModeProvider` is async — while it's still resolving, `.value` is
    // null. Wait for a definite answer rather than defaulting to "not
    // guest", so the protected `busOrdersProvider` fetch never fires for a
    // guest, even on the transient first frame.
    final guestModeValue = ref.watch(guestModeProvider).value;
    if (guestModeValue == null) return const _OrdersSkeleton();
    if (guestModeValue) return const _GuestSignInCard();

    final ordersAsync = ref.watch(busOrdersProvider);
    return ordersAsync.when(
      loading: () => const _OrdersSkeleton(),
      error: (error, _) =>
          _ErrorState(onRetry: () => ref.invalidate(busOrdersProvider)),
      data: (orders) =>
          orders.isEmpty ? const _EmptyState() : _OrdersList(orders: orders),
    );
  }
}

class _SkylineFloatCard extends StatelessWidget {
  const _SkylineFloatCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.20),
            blurRadius: 40,
            spreadRadius: -18,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GuestSignInCard extends StatelessWidget {
  const _GuestSignInCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SkylineFloatCard(
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
                    AppIcons.user,
                    size: 22,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.profileGuestSignInCta,
                    style: AppTypography.title.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  AppIcons.forward,
                  size: 20,
                  color: AppColors.textMuted,
                ),
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
    return _SkylineFloatCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryTint,
              ),
              child: const Icon(
                AppIcons.ticket,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.ticketsEmptyTitle,
              style: AppTypography.h1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.ticketsEmptyBody,
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
    return _SkylineFloatCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.error, size: 40, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.ticketsError,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
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
      child: const Column(
        children: [
          _OrderCardSkeleton(),
          SizedBox(height: AppSpacing.md),
          _OrderCardSkeleton(),
        ],
      ),
    );
  }
}

class _OrderCardSkeleton extends StatelessWidget {
  const _OrderCardSkeleton();

  static const _block = BoxDecoration(color: AppColors.hairline);

  static Widget _bar(double width, double height) => Container(
        width: width,
        height: height,
        decoration: _block,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: const ShapeDecoration(
        color: AppColors.bgCard,
        shape: TicketBorder(
          radius: AppRadius.card,
          notchRadius: 10,
          notchOffsetFromBottom: 56,
          dashColor: AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bar(120, 14),
                    const SizedBox(height: AppSpacing.xs),
                    _bar(80, 10),
                  ],
                ),
                const Spacer(),
                _bar(64, 22),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _bar(double.infinity, 12),
            const SizedBox(height: AppSpacing.xs),
            _bar(double.infinity, 12),
            const SizedBox(height: AppSpacing.xs),
            _bar(double.infinity, 12),
          ],
        ),
      ),
    );
  }
}

class _BusSectionHeader extends StatelessWidget {
  const _BusSectionHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(AppIcons.bus, size: 22, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            l10n.ticketsSectionBus,
            style: AppTypography.title.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersList extends ConsumerWidget {
  const _OrdersList({required this.orders});

  final List<BusOrder> orders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BusSectionHeader(),
        for (final order in orders)
          BusOrderCard(
            order: order,
            onPay: () => context.push(
              BusRoutes.pay,
              extra: PaymentFlowArgs(
                checkoutUrl: order.gatewayCheckoutUrl ?? '',
                orderId: order.orderId,
              ),
            ),
            onOpenETicket: () =>
                unawaited(_openETicket(context, order.invoiceUrl ?? '')),
            onCancel: () =>
                unawaited(_confirmCancel(context, ref, order.orderId)),
          ),
      ],
    );
  }
}

Future<void> _openETicket(BuildContext context, String invoiceUrl) async {
  final l10n = AppLocalizations.of(context);
  final uri = invoiceUrl.isEmpty ? null : Uri.tryParse(invoiceUrl);
  if (uri == null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.eTicketDownloadUnavailable)));
    return;
  }
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.eTicketDownloadFailed)));
  }
}

Future<void> _confirmCancel(
  BuildContext context,
  WidgetRef ref,
  String orderId,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      title: Text(l10n.ticketCancelTitle, style: AppTypography.h2),
      content: Text(
        l10n.ticketCancelBody,
        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            l10n.ticketCancelKeep,
            style:
                AppTypography.title.copyWith(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            l10n.ticketCancelConfirm,
            style: AppTypography.title.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  final success = await ref.read(busOrdersProvider.notifier).cancel(orderId);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          success ? l10n.ticketCancelSuccess : l10n.ticketCancelFailed,
        ),
      ),
    );
}
