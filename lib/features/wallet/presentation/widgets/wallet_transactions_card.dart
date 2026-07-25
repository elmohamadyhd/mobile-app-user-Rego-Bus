import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/wallet/domain/entities/wallet.dart';
import 'package:safaria/features/wallet/presentation/widgets/wallet_transaction_tile.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Grouped white card listing wallet transactions with section header.
class WalletTransactionsCard extends StatelessWidget {
  const WalletTransactionsCard({
    super.key,
    required this.transactions,
    this.emptyChild,
  });

  final List<WalletTransaction> transactions;
  final Widget? emptyChild;

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
            blurRadius: 32,
            spreadRadius: -14,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              l10n.walletHistoryTitle,
              style: AppTypography.h2.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (transactions.isEmpty)
            emptyChild ?? const SizedBox.shrink()
          else
            for (var i = 0; i < transactions.length; i++)
              WalletTransactionTile(
                transaction: transactions[i],
              ),
        ],
      ),
    );
  }
}
