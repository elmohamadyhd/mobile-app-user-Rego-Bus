import 'package:flutter/widgets.dart';

/// Width breakpoints (logical px), aligned with Material 3 window size classes.
///
/// REGO is phone-first **but rotates**, so a layout must also survive a short
/// height in landscape — branch on [ResponsiveContext.isLandscape] for that,
/// not just width.
abstract final class AppBreakpoints {
  /// < 600 — phones in portrait.
  static const double compact = 600;

  /// 600–839 — large phones in landscape, small tablets.
  static const double medium = 840;

  /// Beyond this, stop stretching: constrain content and center it so forms /
  /// text don't run edge-to-edge on a wide landscape screen.
  static const double maxContentWidth = 560;
}

/// Material 3 window width size class.
enum WindowSize { compact, medium, expanded }

/// Ergonomic responsive lookups off [BuildContext]. Prefer these (or
/// `LayoutBuilder`) over reading raw sizes ad hoc.
extension ResponsiveContext on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Width-based size class — drives column counts and master/detail choices.
  WindowSize get windowSize {
    final width = screenSize.width;
    if (width < AppBreakpoints.compact) return WindowSize.compact;
    if (width < AppBreakpoints.medium) return WindowSize.medium;
    return WindowSize.expanded;
  }

  bool get isCompact => windowSize == WindowSize.compact;
  bool get isMedium => windowSize == WindowSize.medium;
  bool get isExpanded => windowSize == WindowSize.expanded;

  /// The app rotates — branch on this whenever layout depends on available
  /// *height*, not just width.
  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;
  bool get isPortrait => !isLandscape;

  /// Honour the user's accessibility text-size setting.
  TextScaler get textScaler => MediaQuery.textScalerOf(this);
}
