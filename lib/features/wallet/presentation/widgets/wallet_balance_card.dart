import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

/// Balance display + "Top up" call to action at the top of the wallet screen.
class WalletBalanceCard extends StatelessWidget {
  const WalletBalanceCard({
    super.key,
    required this.balance,
    required this.currency,
    required this.onTopUp,
  });

  final double balance;
  final String currency;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.walletBalanceLabel,
            style:
                AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${balance.toStringAsFixed(2)} $currency',
            style:
                AppTypography.display.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(label: l10n.walletTopUpCta, onPressed: onTopUp),
        ],
      ),
    );
  }
}
