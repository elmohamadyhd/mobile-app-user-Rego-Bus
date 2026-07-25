import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_icons.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Full-width primary Top-up CTA on the page background below the hero.
///
/// Sits fully on [AppColors.bgBase] so the blue button has clear contrast
/// against the light body — never overlapping the gradient header.
class WalletTopUpActionCard extends StatelessWidget {
  const WalletTopUpActionCard({
    super.key,
    required this.onTopUp,
  });

  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PrimaryButton(
      label: l10n.walletTopUpCta,
      icon: AppIcons.plus,
      iconInSquare: true,
      onPressed: onTopUp,
    );
  }
}
