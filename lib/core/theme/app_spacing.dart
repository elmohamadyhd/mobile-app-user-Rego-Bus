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
  static const pagePadding = EdgeInsets.symmetric(horizontal: lg, vertical: md);
  static const cardPadding = EdgeInsets.all(lg);
}

/// Corner radii. Skyline uses soft, generous rounding — 24 px cards.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double card = 24;
  static const double sheet = 28; // bottom sheets / hero bottom curve
  static const double input = 15; // text fields / pill buttons (Skyline)
  static const double button = 16;
  static const double hero = 40; // curved hero bottom corners
  static const double pill = 999;
}
