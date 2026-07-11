import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/l10n/app_localizations.dart';

/// A flight cabin class. Static set for now; wire API later.
class FlightClass {
  const FlightClass({required this.id});

  final String id;

  String label(AppLocalizations l10n) => switch (id) {
        'economy' => l10n.homeClassEconomy,
        'business' => l10n.homeClassBusiness,
        'first' => l10n.homeClassFirst,
        _ => id,
      };
}

const kFlightClasses = <FlightClass>[
  FlightClass(id: 'economy'),
  FlightClass(id: 'business'),
  FlightClass(id: 'first'),
];

const kDefaultFlightClass = FlightClass(id: 'economy');

/// Bottom-sheet picker; resolves to the chosen [FlightClass] or null.
Future<FlightClass?> showFlightClassPicker(
  BuildContext context, {
  required String title,
}) {
  final l10n = AppLocalizations.of(context);

  return showModalBottomSheet<FlightClass>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.title.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(AppIcons.close),
                  color: AppColors.textMuted,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.hairline, height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              children: [
                for (final flightClass in kFlightClasses)
                  ListTile(
                    title: Text(
                      flightClass.label(l10n),
                      style: AppTypography.title,
                    ),
                    onTap: () => Navigator.of(context).pop(flightClass),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
