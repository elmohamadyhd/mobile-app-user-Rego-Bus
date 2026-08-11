import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Ghost CTA that opens the order review sheet.
class OrderRateTripButton extends StatelessWidget {
  const OrderRateTripButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PrimaryButton(
      label: l10n.orderRateTripCta,
      icon: PhosphorIconsLight.star,
      variant: PrimaryButtonVariant.ghost,
      compact: true,
      onPressed: onPressed,
    );
  }
}
