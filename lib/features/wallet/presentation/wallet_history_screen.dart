import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/features/wallet/domain/entities/wallet.dart';
import 'package:safaria/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:safaria/features/wallet/presentation/widgets/wallet_app_bar.dart';
import 'package:safaria/features/wallet/presentation/widgets/wallet_transaction_tile.dart';
import 'package:safaria/l10n/app_localizations.dart';

class WalletHistoryScreen extends ConsumerWidget {
  const WalletHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: WalletAppBar(title: l10n.walletHistoryScreenTitle),
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            l10n.walletError,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        data: (wallet) => _HistoryList(
          wallet: wallet,
          onRefresh: () => ref.read(walletProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.wallet,
    required this.onRefresh,
  });

  final Wallet wallet;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = context.isExpanded
              ? AppBreakpoints.maxContentWidth
              : constraints.maxWidth;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    children: [
                      for (final tx in wallet.transactions)
                        WalletTransactionTile(transaction: tx),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
