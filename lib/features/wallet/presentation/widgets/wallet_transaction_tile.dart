import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/wallet/domain/entities/wallet.dart';

/// One row in the wallet's transaction history: icon by type, description,
/// signed amount, and date when the backend sent one.
class WalletTransactionTile extends StatelessWidget {
  const WalletTransactionTile({super.key, required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isDeposit = transaction.type == WalletTransactionType.deposit;
    final isWithdraw = transaction.type == WalletTransactionType.withdraw;
    final amountColor = isDeposit
        ? AppColors.success
        : isWithdraw
            ? AppColors.error
            : AppColors.textPrimary;
    final sign = isDeposit ? '+' : (isWithdraw ? '−' : '');
    final createdAt = transaction.createdAt;
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDeposit
                  ? AppColors.success.withValues(alpha: 0.12)
                  : isWithdraw
                      ? AppColors.error.withValues(alpha: 0.12)
                      : AppColors.primaryTint,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              isDeposit
                  ? AppIcons.walletDeposit
                  : isWithdraw
                      ? AppIcons.walletWithdraw
                      : AppIcons.wallet,
              size: 20,
              color: isDeposit
                  ? AppColors.success
                  : isWithdraw
                      ? AppColors.error
                      : AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.title.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d MMM, HH:mm', locale).format(createdAt),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$sign${transaction.amount.toStringAsFixed(2)}',
            style: AppTypography.title.copyWith(
              fontWeight: FontWeight.w800,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}
