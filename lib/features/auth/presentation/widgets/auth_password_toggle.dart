import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Password visibility eye toggle with a ≥48dp hit target and a11y label.
class AuthPasswordToggle extends StatelessWidget {
  const AuthPasswordToggle({
    super.key,
    required this.obscure,
    required this.onTap,
  });

  final bool obscure;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = obscure ? l10n.authShowPassword : l10n.authHidePassword;

    return IconButton(
      onPressed: onTap,
      tooltip: label,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        obscure ? PhosphorIconsLight.eye : PhosphorIconsLight.eyeSlash,
        size: 20,
        color: AppColors.textMuted,
        semanticLabel: label,
      ),
    );
  }
}
