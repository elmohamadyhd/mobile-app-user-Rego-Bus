import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/features/bus/presentation/widgets/bus_images_sheet.dart';
import 'package:rego/l10n/app_localizations.dart';

/// Floating action on seat selection — opens bus photos when available.
class BusImagesFab extends StatelessWidget {
  const BusImagesFab({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      label: l10n.seatSelectionBusImagesLabel,
      child: Tooltip(
        message: l10n.seatSelectionBusImagesLabel,
        child: Material(
          color: AppColors.primary.withValues(alpha: 0.7),
          shape: const CircleBorder(),
          elevation: 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.25),
          child: InkWell(
            onTap: () => showBusImagesSheet(context, imageUrl: imageUrl),
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(AppIcons.eye, size: 20, color: AppColors.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
