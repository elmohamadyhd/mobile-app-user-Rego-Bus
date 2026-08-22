import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/l10n/app_localizations.dart';

class BookingTermsCheckbox extends StatelessWidget {
  const BookingTermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onOpenTerms,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenTerms;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
          ),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.confirmTermsAgreePrefix,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                GestureDetector(
                  onTap: onOpenTerms,
                  child: Text(
                    l10n.confirmTermsLink,
                    style: AppTypography.body.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                    ),
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
