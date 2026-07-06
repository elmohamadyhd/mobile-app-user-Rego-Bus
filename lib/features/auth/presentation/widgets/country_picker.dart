import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';

/// A country dial code. Minimal static set for now; wire `/countries` later.
class CountryCode {
  const CountryCode({
    required this.name,
    required this.dial,
    required this.emoji,
    required this.groupSizes,
    required this.sampleHint,
  });

  final String name;
  final String dial;
  final String emoji;

  /// National-number digit block lengths, e.g. `[3, 3, 4]` → `101 234 5678`.
  final List<int> groupSizes;

  /// Locale-neutral placeholder matching [groupSizes].
  final String sampleHint;
}

const kCountryCodes = <CountryCode>[
  CountryCode(
    name: 'مصر',
    dial: '20',
    emoji: '🇪🇬',
    groupSizes: [3, 3, 4],
    sampleHint: '101 234 5678',
  ),
  CountryCode(
    name: 'السعودية',
    dial: '966',
    emoji: '🇸🇦',
    groupSizes: [2, 3, 4],
    sampleHint: '50 123 4567',
  ),
  CountryCode(
    name: 'الإمارات',
    dial: '971',
    emoji: '🇦🇪',
    groupSizes: [2, 3, 4],
    sampleHint: '50 123 4567',
  ),
  CountryCode(
    name: 'الكويت',
    dial: '965',
    emoji: '🇰🇼',
    groupSizes: [4, 4],
    sampleHint: '1234 5678',
  ),
  CountryCode(
    name: 'قطر',
    dial: '974',
    emoji: '🇶🇦',
    groupSizes: [4, 4],
    sampleHint: '1234 5678',
  ),
];

const kDefaultCountry = CountryCode(
  name: 'مصر',
  dial: '20',
  emoji: '🇪🇬',
  groupSizes: [3, 3, 4],
  sampleHint: '101 234 5678',
);

/// Bottom-sheet picker; resolves to the chosen [CountryCode] or null.
Future<CountryCode?> showCountryCodePicker(BuildContext context) {
  return showModalBottomSheet<CountryCode>(
    context: context,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
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
