import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_icons.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/wallet/domain/entities/wallet.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/ltr_text.dart';
import 'package:safaria/shared/widgets/skyline_float_card.dart';

/// One row in the wallet's transaction history: icon by type, description,
/// signed amount, and date when the backend sent one.
class WalletTransactionTile extends StatelessWidget {
  const WalletTransactionTile({super.key, required this.transaction});

  final WalletTransaction transaction;

  static String titleFor(
    WalletTransaction transaction,
    AppLocalizations l10n,
  ) {
    return switch (transaction.type) {
      WalletTransactionType.deposit => l10n.walletTransactionDepositTitle,
      WalletTransactionType.withdraw => l10n.walletTransactionWithdrawTitle,
      WalletTransactionType.unknown => transaction.description,
    };
  }

  static String? subtitleFor(
    WalletTransaction transaction,
    AppLocalizations l10n,
  ) {
    if (transaction.type == WalletTransactionType.unknown) return null;
    final description = transaction.description.trim();
    if (description.isEmpty) return null;
    return description;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
    final title = titleFor(transaction, l10n);
    final subtitle = subtitleFor(transaction, l10n);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SkylineFloatCard(
        padding: const EdgeInsets.all(AppSpacing.md),
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
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.title.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
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
            LtrText(
              '$sign${transaction.amount.toStringAsFixed(2)}',
              style: AppTypography.title.copyWith(
                fontWeight: FontWeight.w800,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
