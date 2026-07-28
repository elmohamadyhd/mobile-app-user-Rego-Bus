import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Segmented transport-mode selector shared by Home search and Tickets.
class TransportModeTabBar extends StatelessWidget {
  const TransportModeTabBar({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  static const int busTabIndex = 0;
  static const int privateTabIndex = 1;
  static const int flightTabIndex = 2;

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = [
      (l10n.homeTabBus, PhosphorIconsLight.bus),
      (l10n.homeTabPrivate, PhosphorIconsLight.diamond),
      (l10n.homeTabFlight, PhosphorIconsLight.airplane),
      (l10n.homeTabTrain, PhosphorIconsLight.train),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgBase,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final (label, icon) = tabs[i];
          final active = selectedIndex == i;
          return Expanded(
            child: _TransportModeTab(
              label: label,
              icon: icon,
              active: active,
              onTap: () => onChanged(i),
            ),
          );
        }),
      ),
    );
  }
}

class _TransportModeTab extends StatelessWidget {
  const _TransportModeTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      elevation: active ? 2 : 0,
      shadowColor: AppColors.primary.withValues(alpha: 0.18),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.overline.copyWith(
                  color: active ? AppColors.primary : AppColors.textMuted,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
