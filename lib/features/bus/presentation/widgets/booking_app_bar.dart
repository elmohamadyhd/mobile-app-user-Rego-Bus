import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class BookingAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BookingAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => Size.fromHeight(subtitle != null ? 68.0 : 56.0);

  // Leave room for the leading back button and a trailing action so the
  // centered title never paints under either control.
  static const double _titleHorizontalInset =
      kMinInteractiveDimension + AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgElevated,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: _titleHorizontalInset,
                ),
                child: subtitle != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.title
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            subtitle!,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      )
                    : Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.title
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.xs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      // Phosphor glyphs carry matchTextDirection: true, so
                      // Icon already auto-mirrors this in RTL — an extra
                      // manual flip here cancels it back out.
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
