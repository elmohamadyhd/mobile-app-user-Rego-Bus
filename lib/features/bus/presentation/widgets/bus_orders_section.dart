import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

/// The bus-owned section dropped into the "My Tickets" tab shell
/// (`TicketsScreen`). Renders guest/loading/error/empty/list states for the
/// signed-in rider's bus orders — flight/car will add their own sibling
/// sections later, each equally self-contained.
class BusOrdersSection extends ConsumerWidget {
  const BusOrdersSection({super.key});

  static const _loadingIndicator = Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
    child: Center(child: CircularProgressIndicator()),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `guestModeProvider` is async — while it's still resolving, `.value` is
    // null. Wait for a definite answer rather than defaulting to "not
    // guest", so the protected `busOrdersProvider` fetch never fires for a
    // guest, even on the transient first frame.
    final guestModeValue = ref.watch(guestModeProvider).value;
    if (guestModeValue == null) return _loadingIndicator;
    if (guestModeValue) return const _GuestSignInCard();

    final ordersAsync = ref.watch(busOrdersProvider);
    return ordersAsync.when(
      loading: () => _loadingIndicator,
      error: (error, _) =>
          _ErrorState(onRetry: () => ref.invalidate(busOrdersProvider)),
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: -12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
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
                  child: const Icon(AppIcons.user,
                      size: 22, color: AppColors.primary),
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
                const Icon(AppIcons.forward,
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
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          const Icon(AppIcons.ticket, size: 40, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.ticketsEmptyTitle,
            style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.ticketsEmptyBody,
            textAlign: TextAlign.center,
            style:
                AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: l10n.ticketsBookCta,
            onPressed: () => context.go(AppRoutes.home),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          const Icon(AppIcons.error, size: 36, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.ticketsError,
            textAlign: TextAlign.center,
            style:
                AppTypography.body.copyWith(color: AppColors.textSecondary),
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
    );
  }
}

class _OrdersList extends ConsumerWidget {
  const _OrdersList({required this.orders});

  final List<BusOrder> orders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
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
            success ? l10n.ticketCancelSuccess : l10n.ticketCancelFailed),
      ),
    );
}
