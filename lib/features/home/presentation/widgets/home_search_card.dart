import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/booking/presentation/providers/booking_providers.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class HomeSearchCard extends ConsumerStatefulWidget {
  const HomeSearchCard({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  @override
  ConsumerState<HomeSearchCard> createState() => _HomeSearchCardState();
}

class _HomeSearchCardState extends ConsumerState<HomeSearchCard> {
  final _from = TextEditingController();
  final _to = TextEditingController();
  var _fieldsInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fieldsInitialized) {
      final l10n = AppLocalizations.of(context);
      _from.text = l10n.homeCityCairo;
      _to.text = l10n.homeCityAlexandria;
      _fieldsInitialized = true;
    }
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _swapFields() {
    final tmp = _from.text;
    _from.text = _to.text;
    _to.text = tmp;
  }

  Future<void> _onSearch() async {
    final from = _from.text.trim().isEmpty ? 'Cairo' : _from.text.trim();
    final to = _to.text.trim().isEmpty ? 'Alexandria' : _to.text.trim();
    await ref.read(bookingFlowProvider.notifier).searchTrips(from, to, 'today');
    if (mounted) unawaited(context.push(AppRoutes.trips));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = [
      (l10n.homeTabBus, AppIcons.bus),
      (l10n.homeTabPrivate, AppIcons.private),
      (l10n.homeTabFlight, AppIcons.flight),
      (l10n.homeTabTrain, AppIcons.train),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59146CEC),
            blurRadius: 40,
            spreadRadius: -18,
            offset: Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.bgBase,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: List.generate(tabs.length, (i) {
                final (label, icon) = tabs[i];
                final active = widget.selectedTab == i;
                return Expanded(
                  child: _TransportTab(
                    label: label,
                    icon: icon,
                    active: active,
                    onTap: () {
                      widget.onTabChanged(i);
                      if (i != 0) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(l10n.homeComingSoon),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                      }
                    },
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.hairline),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  children: [
                    _SearchField(
                      controller: _from,
                      label: l10n.homeFrom,
                      iconBg: AppColors.primaryTint,
                      iconColor: AppColors.primary,
                    ),
                    const Divider(
                      color: AppColors.hairline,
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                    _SearchField(
                      controller: _to,
                      label: l10n.homeTo,
                      iconBg: AppColors.secondaryTint,
                      iconColor: const Color(0xFFD98A2B),
                    ),
                  ],
                ),
              ),
              PositionedDirectional(
                end: 14,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _SwapButton(onTap: _swapFields),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                AppIcons.calendar,
                color: AppColors.textMuted,
                size: 17,
              ),
              const SizedBox(width: 10),
              Text(
                l10n.homeTodayDate,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                l10n.homeOnePax,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PrimaryButton(label: l10n.homeSearch, onPressed: _onSearch),
        ],
      ),
    );
  }
}

class _TransportTab extends StatelessWidget {
  const _TransportTab({
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
      elevation: active ? 1 : 0,
      shadowColor: const Color(0x1A000000),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: active ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.overline.copyWith(
                  color: active ? AppColors.textPrimary : AppColors.textMuted,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.label,
    required this.iconBg,
    required this.iconColor,
  });

  final TextEditingController controller;
  final String label;
  final Color iconBg;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 56, 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(AppIcons.locationTo, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.overline.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: AppTypography.title.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.6),
            blurRadius: 16,
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              AppIcons.swap,
              color: AppColors.onPrimary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
