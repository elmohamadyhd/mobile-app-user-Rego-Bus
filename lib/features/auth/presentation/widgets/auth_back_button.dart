import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// The soft rounded back button used on the OTP / password screens.
/// `caretLeft` carries `matchTextDirection: true`, so [Icon] already mirrors
/// it to point "back" in RTL on its own — don't wrap it in another flip.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    return Material(
      color: AppColors.inputFill,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(PhosphorIconsLight.caretLeft, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
