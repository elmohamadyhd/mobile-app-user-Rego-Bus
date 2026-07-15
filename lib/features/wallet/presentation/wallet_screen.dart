import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:rego/features/wallet/presentation/wallet_routes.dart';
import 'package:rego/features/wallet/presentation/widgets/wallet_app_bar.dart';
import 'package:rego/features/wallet/presentation/widgets/wallet_balance_card.dart';
import 'package:rego/features/wallet/presentation/widgets/wallet_transaction_tile.dart';
import 'package:rego/l10n/app_localizations.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: WalletAppBar(title: l10n.walletTitle),
      body: RefreshIndicator(
        onRefresh: () => ref.read(walletProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: walletAsync.when(
            loading: () => const [
              SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, _) => [
              _WalletErrorState(onRetry: () => ref.invalidate(walletProvider)),
            ],
            data: (wallet) => [
              WalletBalanceCard(
                balance: wallet.balance,
                currency: wallet.currency,
                onTopUp: () => context.push(WalletRoutes.topUp),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.walletHistoryTitle, style: AppTypography.h2),
              const SizedBox(height: AppSpacing.sm),
              if (wallet.transactions.isEmpty)
                _WalletEmptyState(l10n: l10n)
              else
                for (final tx in wallet.transactions)
                  WalletTransactionTile(transaction: tx),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletEmptyState extends StatelessWidget {
  const _WalletEmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          const Icon(AppIcons.wallet, size: 40, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.walletEmptyTitle,
            style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.walletEmptyBody,
            textAlign: TextAlign.center,
            style:
                AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _WalletErrorState extends StatelessWidget {
  const _WalletErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          const Icon(AppIcons.error, size: 40, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.walletError,
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
