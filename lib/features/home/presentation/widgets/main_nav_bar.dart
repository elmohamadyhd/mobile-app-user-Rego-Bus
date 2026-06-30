import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/booking/presentation/providers/booking_providers.dart';
import 'package:rego/l10n/app_localizations.dart';

class MainNavBar extends ConsumerWidget {
  const MainNavBar({
    super.key,
    required this.activeTab,
    required this.onTabTap,
  });

  final int activeTab;
  final ValueChanged<int> onTabTap;

  void _onTap(BuildContext context, WidgetRef ref, int index) {
    if (index == 0) {
      onTabTap(0);
      return;
    }
    ref.read(bookingFlowProvider.notifier).reset();
    onTabTap(index);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).homeComingSoon),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: AppIcons.home,
            label: l10n.navHome,
            active: activeTab == 0,
            onTap: () => _onTap(context, ref, 0),
          ),
          _NavItem(
            icon: AppIcons.ticket,
            label: l10n.navTickets,
            active: activeTab == 1,
            onTap: () => _onTap(context, ref, 1),
          ),
          _SearchFab(onTap: () => _onTap(context, ref, 2)),
          _NavItem(
            icon: AppIcons.wallet,
            label: l10n.navWallet,
            active: activeTab == 3,
            onTap: () => _onTap(context, ref, 3),
          ),
          _NavItem(
            icon: AppIcons.user,
            label: l10n.navProfile,
            active: activeTab == 4,
            onTap: () => _onTap(context, ref, 4),
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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: active ? AppColors.primary : AppColors.textMuted,
            size: 22,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.overline.copyWith(
              color: active ? AppColors.primary : AppColors.textMuted,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchFab extends StatelessWidget {
  const _SearchFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -18),
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 52,
            height: 52,
            child: Icon(AppIcons.search, color: AppColors.onPrimary, size: 24),
          ),
        ),
      ),
    );
  }
}
