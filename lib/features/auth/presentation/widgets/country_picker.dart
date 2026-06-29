import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';

/// A country dial code. Minimal static set for now; wire `/countries` later.
class CountryCode {
  const CountryCode({required this.name, required this.dial, required this.emoji});

  final String name;
  final String dial;
  final String emoji;
}

const kCountryCodes = <CountryCode>[
  CountryCode(name: 'مصر', dial: '20', emoji: '🇪🇬'),
  CountryCode(name: 'السعودية', dial: '966', emoji: '🇸🇦'),
  CountryCode(name: 'الإمارات', dial: '971', emoji: '🇦🇪'),
  CountryCode(name: 'الكويت', dial: '965', emoji: '🇰🇼'),
  CountryCode(name: 'قطر', dial: '974', emoji: '🇶🇦'),
];

const kDefaultCountry =
    CountryCode(name: 'مصر', dial: '20', emoji: '🇪🇬');

/// Bottom-sheet picker; resolves to the chosen [CountryCode] or null.
Future<CountryCode?> showCountryCodePicker(BuildContext context) {
  return showModalBottomSheet<CountryCode>(
    context: context,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          for (final c in kCountryCodes)
            ListTile(
              leading: Text(c.emoji, style: const TextStyle(fontSize: 24)),
              title: Text(c.name, style: AppTypography.title),
              trailing: Text(
                '+${c.dial}',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              onTap: () => Navigator.of(context).pop(c),
            ),
        ],
      ),
    ),
  );
}
