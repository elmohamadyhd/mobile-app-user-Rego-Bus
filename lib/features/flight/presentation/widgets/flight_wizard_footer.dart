import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Sticky total + CTA used at the bottom of flight wizard steps.
class FlightWizardFooter extends StatelessWidget {
  const FlightWizardFooter({
    super.key,
    required this.totalLabel,
    required this.totalText,
    required this.ctaLabel,
    required this.onCta,
  });

  final String totalLabel;
  final String totalText;
  final String ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: 8,
      shadowColor: AppColors.cardShadowSoft,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      totalLabel,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    totalText,
                    style: AppTypography.h2.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: ctaLabel,
                onPressed: onCta,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
