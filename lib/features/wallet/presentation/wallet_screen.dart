import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_icons.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/features/wallet/domain/entities/wallet.dart';
import 'package:safaria/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:safaria/features/wallet/presentation/wallet_routes.dart';
import 'package:safaria/features/wallet/presentation/widgets/wallet_hero_header.dart';
import 'package:safaria/features/wallet/presentation/widgets/wallet_top_up_action_card.dart';
import 'package:safaria/features/wallet/presentation/widgets/wallet_transaction_tile.dart';
import 'package:safaria/features/wallet/presentation/widgets/wallet_transactions_header.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/skyline_float_card.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: walletAsync.when(
        loading: () => const _WalletLoadingBody(),
        error: (error, _) => _WalletErrorBody(
          onRetry: () => ref.invalidate(walletProvider),
        ),
        data: (wallet) => _WalletLoadedBody(
          wallet: wallet,
          onRefresh: () => ref.read(walletProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

class _WalletLoadedBody extends StatelessWidget {
  const _WalletLoadedBody({
    required this.wallet,
    required this.onRefresh,
  });

  final Wallet wallet;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preview = wallet.transactions.take(walletPreviewLimit).toList();
    final showSeeAll = wallet.transactions.length > walletPreviewLimit;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = context.isExpanded
              ? AppBreakpoints.maxContentWidth
              : constraints.maxWidth;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    WalletHeroHeader(
                      balance: wallet.balance,
                      currency: wallet.currency,
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        0,
                      ),
                      child: WalletTopUpActionCard(
                        onTopUp: () => context.push(WalletRoutes.topUp),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          WalletTransactionsHeader(
                            showSeeAll: showSeeAll,
                            onSeeAll: showSeeAll
                                ? () => context.push(WalletRoutes.history)
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (preview.isEmpty)
                            _WalletEmptyState(l10n: l10n)
                          else
                            for (final tx in preview)
                              WalletTransactionTile(transaction: tx),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WalletLoadingBody extends StatelessWidget {
  const _WalletLoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        WalletHeroHeader(balance: 0, currency: 'EGP'),
        Expanded(
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

class _WalletErrorBody extends StatelessWidget {
  const _WalletErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        const WalletHeroHeader(balance: 0, currency: 'EGP'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SkylineFloatCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.error, size: 40, color: AppColors.error),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.walletError,
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
          ),
        ),
      ],
    );
  }
}

class _WalletEmptyState extends StatelessWidget {
  const _WalletEmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SkylineFloatCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xl,
        horizontal: AppSpacing.lg,
      ),
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
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
