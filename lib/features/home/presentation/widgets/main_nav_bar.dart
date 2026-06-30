import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/booking/presentation/providers/booking_providers.dart';
import 'package:rego/l10n/app_localizations.dart';

class MainNavBar extends ConsumerStatefulWidget {
  const MainNavBar({super.key, this.initialIndex = 0});

  final int initialIndex;

  /// Space below scroll content so the last item can clear the overlay nav.
  static double scrollBottomPadding(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return safeBottom + 100;
  }

  @override
  ConsumerState<MainNavBar> createState() => _MainNavBarState();
}

class _MainNavBarState extends ConsumerState<MainNavBar> {
  late int _active = widget.initialIndex;

  void _onTap(int index) {
    if (index == _active) return;
    setState(() => _active = index);
    if (index != 0) {
      ref.read(bookingFlowProvider.notifier).reset();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).homeComingSoon),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            active: _active == 0,
            onTap: () => _onTap(0),
          ),
          _NavItem(
            icon: AppIcons.ticket,
            label: l10n.navTickets,
            active: _active == 1,
            onTap: () => _onTap(1),
          ),
          _NavItem(
            icon: AppIcons.search,
            label: l10n.navSearch,
            active: _active == 2,
            onTap: () => _onTap(2),
          ),
          _NavItem(
            icon: AppIcons.wallet,
            label: l10n.navWallet,
            active: _active == 3,
            onTap: () => _onTap(3),
          ),
          _NavItem(
            icon: AppIcons.user,
            label: l10n.navProfile,
            active: _active == 4,
            onTap: () => _onTap(4),
          ),
        ],
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
      width: 48,
      height: 48,
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
      child: Icon(icon, color: AppColors.onPrimary, size: 24),
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
          SizedBox(
            width: 48,
            height: 44,
            child: Center(
              child: active
                  ? Transform.translate(
                      offset: const Offset(0, -16),
                      child: _NavActiveOrb(icon: icon),
                    )
                  : Icon(icon, color: AppColors.textMuted, size: 22),
            ),
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
