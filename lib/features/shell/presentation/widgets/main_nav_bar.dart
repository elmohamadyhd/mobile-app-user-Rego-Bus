import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/l10n/app_localizations.dart';

// ── Nav-bar geometry (matches the Skyline design canvas) ─────────────────────
const double _barRadius = 40;
const double _orbSize = 56;
const double _orbIconSize = 28;
const double _iconSlotHeight = 44;
const double _navIconSize = 22;

/// How far the active orb floats above the bar. Also the height of the
/// transparent, still-tappable zone reserved above the bar so the raised orb
/// stays inside its item's hit-test box.
const double _orbLift = 18;

const double _barPadH =
    AppSpacing.sm; // horizontal inset of items from the edge
const double _barPadV = AppSpacing.sm; // vertical breathing room inside the bar
const double _labelGap = AppSpacing.xs; // gap between icon and label

/// Labels never scale past this — a nav bar must stay one line at any system
/// font size. Icons and the orb keep a fixed footprint regardless.
const double _maxLabelScale = 1.3;

const Duration _navAnim = Duration(milliseconds: 220);
const Color _barShadowColor = Color(0x1A000000); // 10% black, soft upward lift

/// The app's primary bottom navigation — a floating, rounded "Skyline" pill
/// with a raised orb marking the active tab.
///
/// This is a **controlled** component: it renders [currentIndex] and reports
/// taps through [onDestinationSelected] (fired for every tap, including the
/// already-selected tab, mirroring [NavigationBar]). It owns no selection
/// state and no navigation policy — the host (e.g. the shell scaffold) decides
/// what a tap does.
///
/// Robust by construction: full-height equal-width hit targets that include the
/// floating orb, theme-driven colours (light/dark), clamped label scaling,
/// ellipsised labels, RTL-safe layout, and merged tab semantics.
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
      (AppIcons.wallet, l10n.navWallet),
      (AppIcons.user, l10n.navProfile),
    ];

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxLabelScale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The visible bar occupies everything below the orb-lift zone, so the
          // raised orb can float over the content above it.
          Positioned(
            top: _orbLift,
            left: 0,
            right: 0,
            bottom: 0,
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
            ),
          ),
          // Full-height tap targets over the bar; orb-lift zone included.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _barPadH),
            child: Material(
              type: MaterialType.transparency,
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(
                      child: _NavItem(
                        icon: destinations[i].$1,
                        label: destinations[i].$2,
                        active: i == currentIndex,
                        onTap: () => onDestinationSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
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
          borderRadius: BorderRadius.circular(AppRadius.lg),
          // Top padding reserves the transparent orb-lift zone as tappable, so
          // the raised orb sits inside this InkWell's hit box.
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              0,
              _orbLift + _barPadV,
              0,
              _barPadV,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: _orbSize,
                  height: _iconSlotHeight,
                  child: Center(
                    child: active
                        ? Transform.translate(
                            offset: const Offset(0, -_orbLift),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.85, end: 1),
                              duration: _navAnim,
                              curve: Curves.easeOutBack,
                              builder: (_, scale, child) =>
                                  Transform.scale(scale: scale, child: child),
                              child: _NavActiveOrb(icon: icon),
                            ),
                          )
                        : Icon(
                            icon,
                            color: AppColors.textMuted,
                            size: _navIconSize,
                          ),
                  ),
                ),
                const SizedBox(height: _labelGap),
                AnimatedDefaultTextStyle(
                  duration: _navAnim,
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

class _NavActiveOrb extends StatelessWidget {
  const _NavActiveOrb({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _orbSize,
      height: _orbSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.6),
            blurRadius: 18,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, color: AppColors.onPrimary, size: _orbIconSize),
    );
  }
}
