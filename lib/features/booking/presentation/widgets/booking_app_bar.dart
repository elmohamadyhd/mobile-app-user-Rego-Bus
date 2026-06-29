import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_typography.dart';

class BookingAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BookingAppBar({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

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
          child: Row(
            children: [
              IconButton(
                icon: const Icon(AppIcons.back, color: AppColors.textPrimary),
                onPressed: () => context.pop(),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(width: 48, child: action),
            ],
          ),
        ),
      ),
    );
  }
}
