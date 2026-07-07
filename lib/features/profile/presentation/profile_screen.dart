import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/auth/domain/entities/auth_user.dart';
import 'package:rego/features/auth/presentation/auth_flow_args.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/ltr_text.dart';
import 'package:rego/shared/widgets/shell_tab_scroll_view.dart';
import 'package:rego/shared/widgets/skyline_tab_hero.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(sessionControllerProvider).value?.user;
    final isGuest = ref.watch(guestModeProvider).value ?? false;

    return ShellTabScrollView(
      hero: SkylineTabHero(
        child: _ProfileHeroContent(user: user),
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileMenuCard(
              items: [
                _ProfileMenuItem(
                  icon: AppIcons.ticket,
                  label: l10n.profileMenuTrips,
                  onTap: () => _showComingSoon(context, l10n),
                ),
                _ProfileMenuItem(
                  icon: AppIcons.locationTo,
                  label: l10n.profileMenuAddresses,
                  onTap: () => _showComingSoon(context, l10n),
                ),
                _ProfileMenuItem(
                  icon: AppIcons.wallet,
                  label: l10n.profileMenuWallet,
                  onTap: () => _showComingSoon(context, l10n),
                ),
                _ProfileMenuItem(
                  icon: AppIcons.language,
                  label: l10n.profileMenuLanguage,
                  onTap: () => _showComingSoon(context, l10n),
                ),
                _ProfileMenuItem(
                  icon: AppIcons.settings,
                  label: l10n.profileMenuSettings,
                  onTap: () => _showComingSoon(context, l10n),
                ),
                _ProfileMenuItem(
                  icon: AppIcons.help,
                  label: l10n.profileMenuHelp,
                  onTap: () => _showComingSoon(context, l10n),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            isGuest
                ? _ProfileSignInCard(
                    label: l10n.profileGuestSignInCta,
                    onTap: () => context.go(
                      AppRoutes.login,
                      extra: const AuthGateArgs(returnTo: AppRoutes.profile),
                    ),
                  )
                : _ProfileLogoutCard(
                    label: l10n.profileMenuLogout,
                    onTap: () => _confirmLogout(context, ref),
                  ),
          ],
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, AppLocalizations l10n) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.profileComingSoon)));
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: Text(l10n.profileLogoutTitle, style: AppTypography.h2),
        content: Text(
          l10n.profileLogoutMessage,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              l10n.profileLogoutCancel,
              style: AppTypography.title.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.profileLogoutConfirm,
              style: AppTypography.title.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(sessionControllerProvider.notifier).logout();
    }
  }
}

class _ProfileHeroContent extends StatelessWidget {
  const _ProfileHeroContent({required this.user});

  static const double _avatarSize = 56;

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = (user?.name?.trim().isNotEmpty ?? false)
        ? user!.name!
        : l10n.profileGuest;
    final initial = name.isNotEmpty ? name.substring(0, 1) : '?';
    final phone = _formatPhone(user);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ProfileAvatar(
          avatarUrl: user?.avatarUrl,
          initial: initial,
          size: _avatarSize,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: AppTypography.h2.copyWith(
                  color: AppColors.onHero,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (phone != null) ...[
                const SizedBox(height: AppSpacing.xs),
                LtrText(
                  phone,
                  style: AppTypography.body.copyWith(
                    color: AppColors.onHero.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String? _formatPhone(AuthUser? user) {
    final mobile = user?.mobile?.trim();
    if (mobile == null || mobile.isEmpty) return null;
    final code = user?.phoneCode?.trim();
    if (code != null && code.isNotEmpty) return '+$code $mobile';
    return mobile;
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.avatarUrl,
    required this.initial,
    required this.size,
  });

  final String? avatarUrl;
  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          avatarUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _InitialAvatar(initial: initial, size: size),
        ),
      );
    }

    return _InitialAvatar(initial: initial, size: size);
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.initial, required this.size});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTypography.h1.copyWith(
          color: AppColors.onHero,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProfileMenuItem {
  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _ProfileMenuCard extends StatelessWidget {
  const _ProfileMenuCard({required this.items});

  final List<_ProfileMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.20),
            blurRadius: 40,
            spreadRadius: -18,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _ProfileMenuTile(
              icon: items[i].icon,
              label: items[i].label,
              onTap: items[i].onTap,
            ),
            if (i != items.length - 1)
              const Divider(
                color: AppColors.hairline,
                height: 1,
                indent: AppSpacing.lg + 40 + AppSpacing.md,
              ),
          ],
        ],
      ),
    );
  }
}

class _ProfileLogoutCard extends StatelessWidget {
  const _ProfileLogoutCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: -12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _ProfileMenuTile(
        icon: AppIcons.logout,
        label: label,
        onTap: onTap,
        destructive: true,
      ),
    );
  }
}

class _ProfileSignInCard extends StatelessWidget {
  const _ProfileSignInCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: -12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _ProfileMenuTile(
        icon: AppIcons.user,
        label: label,
        onTap: onTap,
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final iconColor = destructive ? AppColors.error : AppColors.primary;
    final textColor = destructive ? AppColors.error : AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: destructive
                      ? AppColors.error.withValues(alpha: 0.10)
                      : AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.title.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Transform.flip(
                flipX: isRtl,
                child: Icon(
                  AppIcons.forward,
                  size: 20,
                  color: destructive
                      ? AppColors.error.withValues(alpha: 0.6)
                      : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
