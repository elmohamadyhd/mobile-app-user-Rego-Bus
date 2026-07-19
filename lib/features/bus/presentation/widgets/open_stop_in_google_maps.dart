import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/core/utils/external_url_launcher.dart';
import 'package:rego/core/utils/google_maps_url.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/l10n/app_localizations.dart';

/// Confirms with the user, then opens [stop] in Google Maps with a map pin.
Future<void> confirmAndOpenStopInGoogleMaps(
  BuildContext context, {
  required BusStop stop,
  ExternalUrlLauncher launchUrl = launchExternalUrl,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      title: Text(
        l10n.tripDetailOpenMapsStopTitle(stop.name),
        style: AppTypography.h2,
      ),
      content: Text(
        l10n.tripDetailOpenMapsStopBody,
        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            l10n.tripDetailOpenMapsCancel,
            style: AppTypography.title.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            l10n.tripDetailOpenMapsConfirm,
            style: AppTypography.title.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final uri = buildGoogleMapsSearchUrl(stop);
  final opened = await launchUrl(uri);
  if (!context.mounted || opened) return;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.tripDetailOpenMapsFailed)));
}
