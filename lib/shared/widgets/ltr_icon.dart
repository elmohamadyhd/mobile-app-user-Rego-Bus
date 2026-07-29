import 'package:flutter/material.dart';

/// Neutralizes Phosphor's [IconData.matchTextDirection] auto-mirroring.
///
/// `phosphoricons_flutter` marks every glyph with `matchTextDirection: true`,
/// so non-directional icons (check, etc.) look flipped in Arabic RTL. Wrap
/// them here — or when you pick left/right carets yourself from the locale.
class LtrIcon extends StatelessWidget {
  const LtrIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
  });

  final IconData icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Icon(icon, size: size, color: color),
    );
  }
}
