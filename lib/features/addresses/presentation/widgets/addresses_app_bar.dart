import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Addresses-owned pushed-screen app bar: title, back arrow, optional trailing
/// action. Shape mirrors wallet's [WalletAppBar] without cross-feature import.
class AddressesAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AddressesAppBar({
    super.key,
    required this.title,
    this.action,
    this.onBack,
  });

  final String title;
  final Widget? action;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgElevated,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    AppTypography.title.copyWith(fontWeight: FontWeight.w700),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.xs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        PhosphorIconsLight.caretLeft,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: onBack ?? () => context.pop(),
                    ),
                    const Spacer(),
                    if (action != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          top: AppSpacing.xs,
                          end: AppSpacing.xs,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: action!,
                        ),
                      )
                    else
                      const SizedBox(width: kMinInteractiveDimension),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
