import 'package:flutter/material.dart';

/// A rounded tinted square holding an outline icon — the illustration motif on
/// the OTP / forgot / new-password screens.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    this.size = 84,
    this.iconSize = 40,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Icon(icon, size: iconSize, color: foreground),
    );
  }
}
