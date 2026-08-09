import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';

class BookingAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BookingAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.subtitleWidget,
    this.action,
    this.onBack,
  }) : assert(
          title != null || titleWidget != null,
          'Provide title or titleWidget',
        );

  /// Plain centered title. Ignored when [titleWidget] is set.
  final String? title;

  /// Custom title (e.g. [RouteArrowLabel]) — preferred for from→to routes.
  final Widget? titleWidget;

  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? action;
  final VoidCallback? onBack;

  @override
  Size get preferredSize =>
      Size.fromHeight(subtitle != null || subtitleWidget != null ? 68.0 : 56.0);

  // Leave room for the leading back button and a trailing action so the
  // centered title never paints under either control.
  static const double _titleHorizontalInset =
      kMinInteractiveDimension + AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle != null || subtitleWidget != null;
    final titleStyle =
        AppTypography.title.copyWith(fontWeight: FontWeight.w700);
    final subtitleStyle =
        AppTypography.caption.copyWith(color: AppColors.textMuted);

    final resolvedTitle = titleWidget ??
        Text(
          title!,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        );

    final resolvedSubtitle = !hasSubtitle
        ? null
        : (subtitleWidget ??
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: subtitleStyle,
            ));

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
                child: resolvedSubtitle != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DefaultTextStyle.merge(
                            style: titleStyle,
                            child: resolvedTitle,
                          ),
                          DefaultTextStyle.merge(
                            style: subtitleStyle,
                            child: resolvedSubtitle,
                          ),
                        ],
                      )
                    : DefaultTextStyle.merge(
                        style: titleStyle,
                        child: resolvedTitle,
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
