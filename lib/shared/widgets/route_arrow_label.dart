import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_spacing.dart';

/// From → to label that stays correct in RTL.
///
/// A plain `'$from → $to'` string lets BiDi reverse the Unicode arrow in
/// Arabic. Separate widgets + Phosphor's `matchTextDirection` caret keep
/// journey direction (from → to) readable in both locales.
class RouteArrowLabel extends StatelessWidget {
  const RouteArrowLabel({
    super.key,
    required this.from,
    required this.to,
    this.style,
    this.iconSize = 16,
    this.iconColor,
    this.maxLines = 1,
  });

  final String from;
  final String to;
  final TextStyle? style;
  final double iconSize;
  final Color? iconColor;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? style?.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            from,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Icon(
            PhosphorIconsLight.caretRight,
            size: iconSize,
            color: color,
          ),
        ),
        Flexible(
          child: Text(
            to,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}
