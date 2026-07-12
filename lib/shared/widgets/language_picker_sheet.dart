import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/core/providers/locale_controller.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/l10n/app_localizations.dart';

class _LanguageOption {
  const _LanguageOption(this.locale, this.autonym);

  final Locale locale;
  final String autonym;
}

const _kLanguageOptions = [
  _LanguageOption(Locale('ar'), 'العربية'),
  _LanguageOption(Locale('en'), 'English'),
];

/// Bottom sheet for switching the app language between Arabic and English.
/// Applies the pick immediately via [localeControllerProvider], which also
/// persists it to secure storage.
Future<void> showLanguagePickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (context) => const _LanguagePickerSheet(),
  );
}

class _LanguagePickerSheet extends ConsumerWidget {
  const _LanguagePickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(localeControllerProvider).languageCode;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(l10n.profileMenuLanguage, style: AppTypography.h2),
            ),
          ),
          for (final option in _kLanguageOptions)
            ListTile(
              title: Text(option.autonym, style: AppTypography.title),
              trailing: option.locale.languageCode == current
                  ? const Icon(AppIcons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                if (option.locale.languageCode != current) {
                  ref
                      .read(localeControllerProvider.notifier)
                      .setLocale(option.locale);
                }
                Navigator.of(context).pop();
              },
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
