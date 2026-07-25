import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Section header for wallet transaction lists with an optional "See all" link.
class WalletTransactionsHeader extends StatelessWidget {
  const WalletTransactionsHeader({
    super.key,
    required this.showSeeAll,
    this.onSeeAll,
  });

  final bool showSeeAll;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(l10n.walletHistoryTitle, style: AppTypography.h2),
        ),
        if (showSeeAll)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.sm,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l10n.walletSeeAll,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

/// Maximum transactions shown on the wallet home screen before "See all".
const int walletPreviewLimit = 5;
