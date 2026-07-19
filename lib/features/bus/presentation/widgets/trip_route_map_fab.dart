import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/core/utils/external_url_launcher.dart';
import 'package:rego/core/utils/google_maps_url.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/utils/order_trip_route_stops.dart';
import 'package:rego/l10n/app_localizations.dart';

typedef ExternalUrlLauncher = Future<bool> Function(Uri uri);

/// Compact map action on the trip route card header — confirms, then opens
/// Google Maps.
class TripRouteMapFab extends StatelessWidget {
  const TripRouteMapFab({
    super.key,
    required this.boardingStops,
    required this.dropoffStops,
    this.launchUrl = launchExternalUrl,
  });

  final List<BusStop> boardingStops;
  final List<BusStop> dropoffStops;
  final ExternalUrlLauncher launchUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      label: l10n.tripDetailOpenMapsLabel,
      child: Tooltip(
        message: l10n.tripDetailOpenMapsLabel,
        child: Material(
          color: AppColors.primary,
          shape: const CircleBorder(),
          elevation: 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.25),
          child: InkWell(
            onTap: () => _onPressed(context),
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(AppIcons.map, size: 20, color: AppColors.onPrimary),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onPressed(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: Text(l10n.tripDetailOpenMapsTitle, style: AppTypography.h2),
        content: Text(
          l10n.tripDetailOpenMapsBody,
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

    final routeStops = orderTripRouteStops(
      boardingStops: boardingStops,
      dropoffStops: dropoffStops,
    );
    final route = buildGoogleMapsDirectionsUrl(stops: routeStops);
    final opened = await launchUrl(route.uri);
    if (!context.mounted) return;

    if (route.truncatedStopCount > 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n.tripDetailOpenMapsStopsTruncated(route.truncatedStopCount),
            ),
          ),
        );
    }

    if (opened) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.tripDetailOpenMapsFailed)));
  }
}
