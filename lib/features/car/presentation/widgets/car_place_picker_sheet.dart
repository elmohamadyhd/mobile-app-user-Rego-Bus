import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:rego/core/places/places_client.dart';
import 'package:rego/core/places/place_prediction.dart';
import 'package:rego/core/places/places_providers.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/car/domain/entities/car_place.dart';
import 'package:rego/features/car/presentation/car_map_adjust_sheet.dart';
import 'package:rego/l10n/app_localizations.dart';

Future<CarPlace?> showCarPlacePicker(
  BuildContext context, {
  required String title,
  CarPlace? initial,
  bool showUseMyLocation = false,
}) {
  return showModalBottomSheet<CarPlace>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: _CarPlacePickerSheet(
        title: title,
        initial: initial,
        showUseMyLocation: showUseMyLocation,
      ),
    ),
  );
}

class _CarPlacePickerSheet extends ConsumerStatefulWidget {
  const _CarPlacePickerSheet({
    required this.title,
    this.initial,
    this.showUseMyLocation = false,
  });

  final String title;
  final CarPlace? initial;
  final bool showUseMyLocation;

  @override
  ConsumerState<_CarPlacePickerSheet> createState() =>
      _CarPlacePickerSheetState();
}

class _CarPlacePickerSheetState extends ConsumerState<_CarPlacePickerSheet> {
  final _query = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String _sessionToken = '';
  List<PlacePrediction> _predictions = [];
  bool _searching = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _sessionToken = PlacesClient.newSessionToken();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _newSessionToken() => PlacesClient.newSessionToken();

  void _onQueryChanged(String text) {
    setState(() {
      _errorMessage = null;
      if (text.trim().length < 2) {
        _predictions = [];
        _searching = false;
      }
    });
    _debounce?.cancel();
    if (!ref.read(placesClientProvider).isConfigured ||
        text.trim().length < 2) {
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(text));
  }

  Future<void> _search(String text) async {
    setState(() {
      _searching = true;
      _errorMessage = null;
    });
    try {
      final client = ref.read(placesClientProvider);
      final locale = Localizations.localeOf(context).languageCode;
      final results = await client.autocomplete(
        input: text,
        languageCode: locale,
        sessionToken: _sessionToken,
      );
      if (!mounted) return;
      setState(() {
        _predictions = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _errorMessage = AppLocalizations.of(context).carPlacesSearchFailed;
      });
    }
  }

  Future<void> _selectPrediction(PlacePrediction prediction) async {
    final client = ref.read(placesClientProvider);
    final locale = Localizations.localeOf(context).languageCode;
    try {
      final place = await client.placeDetails(
        placeId: prediction.placeId,
        languageCode: locale,
        sessionToken: _sessionToken,
      );
      if (!mounted) return;
      Navigator.of(context).pop(place);
    } catch (_) {
      if (!mounted) return;
      setState(
        () =>
            _errorMessage = AppLocalizations.of(context).carPlacesSearchFailed,
      );
    }
  }

  Future<void> _useMyLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    final position = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    final client = ref.read(placesClientProvider);
    final locale = Localizations.localeOf(context).languageCode;
    final place = await client.reverseGeocode(
      latitude: position.latitude,
      longitude: position.longitude,
      languageCode: locale,
    );
    if (!mounted) return;
    Navigator.of(context).pop(place);
  }

  Future<void> _adjustOnMap() async {
    final picked = await showCarMapAdjustSheet(
      context,
      title: widget.title,
      initial: widget.initial,
    );
    if (picked == null || !mounted) return;
    Navigator.of(context).pop(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showList = _query.text.trim().length >= 2;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxHeight = showList ? screenHeight * 0.75 : null;
    final mapsConfigured = ref.watch(placesClientProvider).isConfigured;

    final sheet = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetDragHandle(),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            0,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
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
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 10, 0),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              children: [
                const Icon(
                  AppIcons.search,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: TextField(
                    controller: _query,
                    focusNode: _focusNode,
                    onChanged: _onQueryChanged,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      hintText: l10n.carPlaceSearchHint,
                      hintStyle: AppTypography.body.copyWith(
                        color: AppColors.textMuted,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 15,
                      ),
                    ),
                  ),
                ),
                if (_searching)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              _errorMessage!,
              style: AppTypography.caption.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        const Divider(color: AppColors.hairline, height: 1),
        if (showList)
          Flexible(child: _buildSearchResults(l10n))
        else
          _buildIdleBody(l10n, mapsConfigured),
      ],
    );

    return SafeArea(
      child: maxHeight != null
          ? ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: sheet,
            )
          : sheet,
    );
  }

  Widget _buildIdleBody(AppLocalizations l10n, bool mapsConfigured) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.initial != null)
            _CurrentSelectionRow(
              caption: l10n.carPlaceCurrentSelection,
              label: widget.initial!.displayLabel(l10n),
            ),
          if (mapsConfigured) ...[
            if (widget.initial != null) const SizedBox(height: AppSpacing.md),
            Text(
              l10n.carPlaceQuickActions,
              style: AppTypography.overline.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (widget.showUseMyLocation)
              _QuickActionTile(
                icon: AppIcons.locationFrom,
                iconBg: AppColors.primaryTint,
                iconColor: AppColors.primary,
                label: l10n.carUseMyLocation,
                onTap: _useMyLocation,
              ),
            if (widget.showUseMyLocation) const SizedBox(height: AppSpacing.xs),
            _QuickActionTile(
              icon: AppIcons.map,
              iconBg: AppColors.secondaryTint,
              iconColor: AppColors.secondary,
              label: l10n.carAdjustOnMap,
              onTap: _adjustOnMap,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResults(AppLocalizations l10n) {
    if (_predictions.isEmpty && !_searching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                AppIcons.locationTo,
                color: AppColors.textMuted,
                size: 32,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.carPlacesNoResults,
                style: AppTypography.body.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_predictions.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemCount: _predictions.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        color: AppColors.hairline,
        indent: AppSpacing.md,
        endIndent: AppSpacing.md,
      ),
      itemBuilder: (context, index) {
        final prediction = _predictions[index];
        return _PredictionRow(
          description: prediction.description,
          onTap: () => _selectPrediction(prediction),
        );
      },
    );
  }
}

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
    );
  }
}

class _CurrentSelectionRow extends StatelessWidget {
  const _CurrentSelectionRow({
    required this.caption,
    required this.label,
  });

  final String caption;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgBase,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              AppIcons.locationTo,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caption,
                  style: AppTypography.overline.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.title.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
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

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgBase,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.title.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                AppIcons.chevronDown,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PredictionRow extends StatelessWidget {
  const _PredictionRow({
    required this.description,
    required this.onTap,
  });

  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.bgBase,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  AppIcons.locationTo,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.title.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
