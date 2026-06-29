import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';

/// The soft rounded back button used on the OTP / password screens.
/// Mirrors the chevron in RTL so it always points "back".
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final radius = BorderRadius.circular(AppRadius.lg);
    return Material(
      color: AppColors.inputFill,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Transform.flip(
            flipX: isRtl,
            child: const Icon(AppIcons.back, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
