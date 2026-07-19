import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/l10n/app_localizations.dart';

// ── Nav-bar geometry (matches the Skyline design canvas) ─────────────────────
const double _barRadius = 28;
const double _navIconSize = 22;

const double _barPadH =
    AppSpacing.sm; // horizontal inset of items from the edge
const double _barPadV = 10; // vertical breathing room inside the bar
const double _labelGap = AppSpacing.xxs; // gap between icon and label

/// The active tile is inset from the bar edge by *less* than [_barPadV], so it
/// wraps the icon/label column with a hair of padding instead of clipping it.
const double _tileInsetV = 6;
const double _tileInsetH = 6;
const double _tileRadius = 18;

/// Inactive icons sit fractionally smaller than the active one — enough to read
/// as "less present", far too little to read as a different icon size.
const double _inactiveIconScale = 0.94;

/// Labels never scale past this — a nav bar must stay one line at any system
/// font size. Icons keep a fixed footprint regardless.
const double _maxLabelScale = 1.3;

const Duration _navAnim = Duration(milliseconds: 280);
const Curve _navCurve = Curves.easeOutCubic;
const Color _barShadowColor = Color(0x1A000000); // 10% black, soft upward lift

/// The app's primary bottom navigation — a floating, rounded "Skyline" bar of
/// equal, always-labelled segments. The active segment is marked by a soft
/// blue tint tile that *glides* between segments rather than blinking, while
/// the icon and label cross-fade to brand blue on the same curve.
///
/// This is a **controlled** component: it renders [currentIndex] and reports
/// taps through [onDestinationSelected] (fired for every tap, including the
/// already-selected tab, mirroring [NavigationBar]). It owns no selection
/// state and no navigation policy — the host (e.g. the shell scaffold) decides
/// what a tap does.
///
/// Robust by construction: full-height equal-width hit targets, theme-driven
/// colours (light/dark), clamped label scaling, ellipsised labels, RTL-safe
/// layout, and merged tab semantics. The indicator is sized as a fraction of
/// the bar rather than a measured width, so the destination count is the only
/// thing that has to change to add a tab.
class MainNavBar extends StatelessWidget {
  const MainNavBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final barColor = Theme.of(context).colorScheme.surface;

    final destinations = <(IconData, String)>[
      (AppIcons.home, l10n.navHome),
      (AppIcons.ticket, l10n.navTickets),
      (AppIcons.user, l10n.navProfile),
    ];

    final selected = currentIndex.clamp(0, destinations.length - 1);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxLabelScale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: barColor,
          borderRadius: BorderRadius.circular(_barRadius),
          boxShadow: const [
            BoxShadow(
              color: _barShadowColor,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _barPadH),
          child: Stack(
            children: [
              // The sliding tint tile, under the items. Stretched over the row
              // by Positioned.fill, so it inherits the row's measured height.
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: _tileInsetV),
                  child: _ActiveTile(
                    index: selected,
                    count: destinations.length,
                  ),
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: Row(
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      Expanded(
                        child: _NavItem(
                          icon: destinations[i].$1,
                          label: destinations[i].$2,
                          active: i == selected,
                          onTap: () => onDestinationSelected(i),
                        ),
                      ),
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

/// The soft blue tile behind the active segment. Slides between segments on
/// [AlignmentDirectional], which mirrors under RTL for free — index 0 aligns
/// to the *start* edge, which is the right-hand side in Arabic, matching the
/// [Row] that lays the items out.
class _ActiveTile extends StatelessWidget {
  const _ActiveTile({required this.index, required this.count});

  final int index;
  final int count;

  /// Maps segment [index] onto the -1..1 alignment axis. An [Align] child of
  /// width `1/count` lands on segment `i` when `x = 2i/(count - 1) - 1`.
  double get _alignX => count < 2 ? 0 : (index * 2 / (count - 1)) - 1;

  @override
  Widget build(BuildContext context) {
    return AnimatedAlign(
      alignment: AlignmentDirectional(_alignX, 0),
      duration: _navAnim,
      curve: _navCurve,
      child: FractionallySizedBox(
        widthFactor: 1 / count,
        heightFactor: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _tileInsetH),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(_tileRadius),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Merge icon + label into one selectable tab node for screen readers
    // (e.g. "الرئيسية, selected, button").
    return MergeSemantics(
      child: Semantics(
        selected: active,
        button: true,
        child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          borderRadius: BorderRadius.circular(_tileRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: _barPadV),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // One driver for both the icon tint and its scale, so they
                // resolve together with the tile arriving underneath.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: active ? 1 : 0),
                  duration: _navAnim,
                  curve: _navCurve,
                  builder: (context, t, _) => Transform.scale(
                    scale:
                        _inactiveIconScale + (1 - _inactiveIconScale) * t,
                    child: Icon(
                      icon,
                      size: _navIconSize,
                      color: Color.lerp(
                        AppColors.textMuted,
                        AppColors.primary,
                        t,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: _labelGap),
                AnimatedDefaultTextStyle(
                  duration: _navAnim,
                  curve: _navCurve,
                  style: AppTypography.overline.copyWith(
                    color: active ? AppColors.primary : AppColors.textMuted,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
