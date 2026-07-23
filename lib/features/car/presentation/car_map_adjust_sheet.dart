import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:rego/core/config/app_config.dart';
import 'package:rego/core/places/places_providers.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/car/domain/entities/car_place.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

Future<CarPlace?> showCarMapAdjustSheet(
  BuildContext context, {
  required String title,
  CarPlace? initial,
}) {
  if (!AppConfig.isGoogleMapsConfigured) {
    return Future.value(null);
  }
  return showModalBottomSheet<CarPlace>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CarMapAdjustSheet(title: title, initial: initial),
  );
}

class _CarMapAdjustSheet extends ConsumerStatefulWidget {
  const _CarMapAdjustSheet({required this.title, this.initial});

  final String title;
  final CarPlace? initial;

  @override
  ConsumerState<_CarMapAdjustSheet> createState() => _CarMapAdjustSheetState();
}

class _CarMapAdjustSheetState extends ConsumerState<_CarMapAdjustSheet> {
  static const _cairo = LatLng(30.0444, 31.2357);

  GoogleMapController? _mapController;
  LatLng _center = _cairo;
  String _label = '';
  Timer? _geocodeDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _center = LatLng(widget.initial!.latitude, widget.initial!.longitude);
      _label = widget.initial!.label;
    }
    if (_label.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reverseGeocode());
    }
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode() async {
    final client = ref.read(placesClientProvider);
    if (!client.isConfigured) return;
    final locale = Localizations.localeOf(context).languageCode;
    final place = await client.reverseGeocode(
      latitude: _center.latitude,
      longitude: _center.longitude,
      languageCode: locale,
    );
    if (mounted) setState(() => _label = place.label);
  }

  void _onCameraIdle() {
    _geocodeDebounce?.cancel();
    _geocodeDebounce =
        Timer(const Duration(milliseconds: 400), _reverseGeocode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final height = MediaQuery.sizeOf(context).height * 0.6;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.title,
                    style: AppTypography.title.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CarPlace(
                      latitude: _center.latitude,
                      longitude: _center.longitude,
                      label: _label,
                    ).displayLabel(l10n),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _center,
                      zoom: 14,
                    ),
                    onMapCreated: (controller) => _mapController = controller,
                    onCameraMove: (position) => _center = position.target,
                    onCameraIdle: _onCameraIdle,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                  ),
                  const Icon(
                    AppIcons.locationTo,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                MediaQuery.paddingOf(context).bottom + AppSpacing.md,
              ),
              child: PrimaryButton(
                label: l10n.carConfirmLocation,
                onPressed: () {
                  Navigator.of(context).pop(
                    CarPlace(
                      latitude: _center.latitude,
                      longitude: _center.longitude,
                      label: _label,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
