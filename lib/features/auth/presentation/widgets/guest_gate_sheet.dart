import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/auth/presentation/auth_flow_args.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

/// Shows the guest sign-in gate as a bottom sheet over whatever screen
/// [context] belongs to. [returnTo] is the route to land on after a
/// successful sign-in or registration (typically the screen the guest was
/// gated from, e.g. the booking confirm screen).
Future<void> showGuestGate(BuildContext context, {required String returnTo}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _GuestGateSheet(returnTo: returnTo),
  );
}

class _GuestGateSheet extends StatelessWidget {
  const _GuestGateSheet({required this.returnTo});

  final String returnTo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.secondaryTint,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              alignment: Alignment.center,
              child: const Icon(
                AppIcons.lock,
                color: AppColors.secondary,
                size: 26,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.guestGateTitle,
              textAlign: TextAlign.center,
              style: AppTypography.h2.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.guestGateBody,
              textAlign: TextAlign.center,
              style:
                  AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: l10n.guestGateSignIn,
              onPressed: () {
                Navigator.of(context).pop();
                context.push(
                  AppRoutes.login,
                  extra: AuthGateArgs(returnTo: returnTo),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: l10n.guestGateCreate,
              variant: PrimaryButtonVariant.ghost,
              onPressed: () {
                Navigator.of(context).pop();
                context.push(
                  AppRoutes.register,
                  extra: AuthGateArgs(returnTo: returnTo),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  AppIcons.checkCircle,
                  size: 16,
                  color: AppColors.success,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.guestGateReassure,
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
