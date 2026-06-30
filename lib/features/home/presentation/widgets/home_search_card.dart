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
      l10n.homeTabBus,
      l10n.homeTabPrivate,
      l10n.homeTabFlight,
      l10n.homeTabTrain,
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Transport tabs
          Row(
            children: List.generate(tabs.length, (i) {
              final active = widget.selectedTab == i;
              return Expanded(
                child: Material(
                  color: active ? AppColors.primary : AppColors.bgBase,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    onTap: () {
                      widget.onTabChanged(i);
                      if (i != 0) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(content: Text(l10n.homeComingSoon)),
                          );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      child: Text(
                        tabs[i],
                        style: AppTypography.caption.copyWith(
                          color: active ? Colors.white : AppColors.textMuted,
                          fontWeight:
                              active ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          // From / To fields with swap
          Stack(
            children: [
              Column(
                children: [
                  _SearchField(
                    controller: _from,
                    hint: l10n.homeFrom,
                    icon: AppIcons.locationTo,
                  ),
                  const Divider(
                    color: AppColors.hairline,
                    height: 1,
                    indent: 44,
                  ),
                  _SearchField(
                    controller: _to,
                    hint: l10n.homeTo,
                    icon: AppIcons.locationTo,
                  ),
                ],
              ),
              PositionedDirectional(
                end: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _SwapButton(onTap: _swapFields),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Date / pax row
          Row(
            children: [
              const Icon(AppIcons.calendar, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                l10n.homeTodayDate,
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                l10n.homeOnePax,
                style: AppTypography.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Search button
          PrimaryButton(label: l10n.homeSearch, onPressed: _onSearch),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.icon,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  AppTypography.body.copyWith(color: AppColors.textMuted),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            style: AppTypography.body,
          ),
        ),
      ],
    );
  }
}

class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryTint,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(AppIcons.swap, color: AppColors.primary, size: 18),
        ),
      ),
    );
  }
}
