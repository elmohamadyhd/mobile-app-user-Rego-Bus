import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/shared/widgets/ltr_icon.dart';

/// Visible label above a control. Placeholders are not labels.
class FlightFieldLabel extends StatelessWidget {
  const FlightFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.caption.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// White filled control on [AppColors.bgBase]. `inputFill` matches the page
/// wash and disappears; elevated + [AppColors.border] is the readable pair.
InputDecoration flightFormDecoration({
  String? hintText,
  String? errorText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    errorText: errorText,
    filled: true,
    fillColor: AppColors.bgElevated,
    suffixIcon: suffixIcon,
  );
}

class FlightSectionHeader extends StatelessWidget {
  const FlightSectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        text,
        style: AppTypography.title.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Tappable select/date row that matches [flightFormDecoration] text fields.
class FlightFormPicker extends StatelessWidget {
  const FlightFormPicker({
    super.key,
    required this.label,
    required this.hintText,
    required this.icon,
    required this.onTap,
    this.valueText,
    this.errorText,
  });

  final String label;
  final String hintText;
  final IconData icon;
  final VoidCallback onTap;
  final String? valueText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasValue = valueText != null && valueText!.trim().isNotEmpty;
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlightFieldLabel(label),
        const SizedBox(height: AppSpacing.xs),
        Material(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.input),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  border: Border.all(
                    color: hasError ? AppColors.error : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    LtrIcon(icon, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        hasValue ? valueText! : hintText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          color: hasValue
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontWeight:
                              hasValue ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                    const LtrIcon(
                      PhosphorIconsLight.caretDown,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
            child: Text(
              errorText!,
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}
