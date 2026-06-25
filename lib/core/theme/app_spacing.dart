import 'package:flutter/material.dart';

/// Spacing scale (multiples of 4 px).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // ── Edge insets ──────────────────────────────────────────────────────────
  static const pagePadding = EdgeInsets.symmetric(horizontal: md, vertical: md);
  static const cardPadding = EdgeInsets.all(md);
}

abstract final class AppRadius {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double card = 12;
  static const double button = 8;
  static const double pill = 999;
}
