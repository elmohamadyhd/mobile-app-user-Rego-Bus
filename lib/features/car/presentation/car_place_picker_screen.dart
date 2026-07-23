import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:rego/core/places/google_maps_capabilities.dart';
import 'package:rego/core/places/place_prediction.dart';
import 'package:rego/core/places/places_client.dart';
import 'package:rego/core/places/places_providers.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/core/utils/responsive.dart';
import 'package:rego/features/auth/presentation/widgets/auth_back_button.dart';
import 'package:rego/features/car/domain/entities/car_place.dart';
import 'package:rego/features/car/presentation/car_place_picker_args.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class CarPlacePickerScreen extends ConsumerStatefulWidget {
  const CarPlacePickerScreen({
    super.key,
    required this.args,
    @visibleForTesting this.onPickedForTest,
  });

  final CarPlacePickerArgs args;
  final void Function(CarPlace place)? onPickedForTest;

  @override
  ConsumerState<CarPlacePickerScreen> createState() =>
      _CarPlacePickerScreenState();
}

class _CarPlacePickerScreenState extends ConsumerState<CarPlacePickerScreen>
    with WidgetsBindingObserver {
  static const _cairo = LatLng(30.0444, 31.2357);
  static const _sheetPeek = 0.34;
  static const _sheetPeekKeyboard = 0.55;
  static const _sheetExpanded = 0.85;
  static const _sheetMaxKeyboard = 0.92;
  static const _sheetMin = 0.24;
  static const _sheetMinKeyboard = 0.45;
  static const _sheetMaxIdle = 0.5;

  GoogleMapController? _mapController;
  final _sheetController = DraggableScrollableController();
  LatLng _center = _cairo;
  CarPlace? _draft;
  final _query = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _searchDebounce;
  Timer? _geocodeDebounce;
  String _sessionToken = '';
  List<PlacePrediction> _predictions = [];
  bool _searching = false;
  String? _errorMessage;
  bool _locating = false;
  int _draftVersion = 0;
  bool _ignoreMapEvents = false;
  bool _mapCreated = false;
  Timer? _mapCreateTimeout;

  bool get _isSearching => _query.text.trim().length >= 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode.addListener(_onSearchFocusChanged);
    _sessionToken = PlacesClient.newSessionToken();
    final initial = widget.args.initial;
    if (initial != null) {
      _center = LatLng(initial.latitude, initial.longitude);
      _draft = initial;
    } else {
      _draft = const CarPlace(
        latitude: 30.0444,
        longitude: 31.2357,
        label: '',
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (GoogleMapsCapabilities.mapRenderingAvailable) {
        _mapCreateTimeout = Timer(const Duration(seconds: 3), () {
          if (!mounted || _mapCreated) return;
          GoogleMapsCapabilities.markMapUnavailable();
          setState(() {});
        });
      }
      if (initial == null && widget.args.showUseMyLocation) {
        unawaited(_centerOnMyLocation(silent: true));
      } else if (_draft?.label.isEmpty ?? false) {
        unawaited(_reverseGeocode());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_onSearchFocusChanged);
    _searchDebounce?.cancel();
    _geocodeDebounce?.cancel();
    _mapCreateTimeout?.cancel();
    _query.dispose();
    _focusNode.dispose();
    _sheetController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted || !_sheetController.isAttached) return;
    final keyboardInset = View.of(context).viewInsets.bottom;
    if (keyboardInset > 0) {
      if (_sheetController.size < _sheetPeekKeyboard) {
        unawaited(
          _sheetController.animateTo(
            _sheetPeekKeyboard,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
        );
      }
    } else if (!_focusNode.hasFocus && _sheetController.size > _sheetPeek) {
      unawaited(
        _sheetController.animateTo(
          _sheetPeek,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  void _onSearchFocusChanged() {
    if (!mounted || !_sheetController.isAttached) return;
    if (_focusNode.hasFocus) {
      unawaited(
        _sheetController.animateTo(
          _sheetPeekKeyboard,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    } else if (View.of(context).viewInsets.bottom == 0) {
      unawaited(
        _sheetController.animateTo(
          _sheetPeek,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  void _newSessionToken() => _sessionToken = PlacesClient.newSessionToken();

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapCreated = true;
    _mapCreateTimeout?.cancel();
  }

  void _setDraft(CarPlace place) {
    setState(() {
      _draft = place;
      _draftVersion++;
      _center = LatLng(place.latitude, place.longitude);
    });
  }

  Future<void> _animateTo(LatLng target) async {
    if (!GoogleMapsCapabilities.mapRenderingAvailable) return;
    _ignoreMapEvents = true;
    _center = target;
    try {
      await _mapController
          ?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: target, zoom: 15),
            ),
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Map unavailable or animation failed — draft coords already set.
    } finally {
      if (mounted) {
        setState(() => _ignoreMapEvents = false);
      }
    }
  }

  Future<void> _reverseGeocode() async {
    if (_ignoreMapEvents) return;
    final client = ref.read(placesClientProvider);
    if (!client.isConfigured) return;
    final locale = Localizations.localeOf(context).languageCode;
    final versionAtStart = _draftVersion;
    try {
      final place = await client.reverseGeocode(
        latitude: _center.latitude,
        longitude: _center.longitude,
        languageCode: locale,
      );
      if (!mounted || _ignoreMapEvents || versionAtStart != _draftVersion) {
        return;
      }
      _setDraft(place);
    } catch (_) {
      if (!mounted || _ignoreMapEvents || versionAtStart != _draftVersion) {
        return;
      }
      _setDraft(
        CarPlace(
          latitude: _center.latitude,
          longitude: _center.longitude,
          label: '',
        ),
      );
    }
  }

  void _onCameraIdle() {
    if (_ignoreMapEvents || !GoogleMapsCapabilities.mapRenderingAvailable) {
      return;
    }
    final draft = _draft;
    if (draft != null &&
        draft.sameCoordinates(
          CarPlace(
            latitude: _center.latitude,
            longitude: _center.longitude,
            label: '',
          ),
        )) {
      return;
    }
    _geocodeDebounce?.cancel();
    _geocodeDebounce =
        Timer(const Duration(milliseconds: 400), _reverseGeocode);
  }

  void _onQueryChanged(String text) {
    setState(() {
      _errorMessage = null;
      if (text.trim().length < 2) {
        _predictions = [];
        _searching = false;
      }
    });
    _searchDebounce?.cancel();
    if (!ref.read(placesClientProvider).isConfigured ||
        text.trim().length < 2) {
      return;
    }
    _searchDebounce =
        Timer(const Duration(milliseconds: 300), () => _search(text));
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
      _newSessionToken();
      _query.clear();
      _focusNode.unfocus();
      _geocodeDebounce?.cancel();
      _geocodeDebounce = null;
      setState(() {
        _predictions = [];
      });
      _setDraft(place);
      if (GoogleMapsCapabilities.mapRenderingAvailable) {
        await _animateTo(LatLng(place.latitude, place.longitude));
      }
    } catch (_) {
      if (!mounted) return;
      setState(
        () =>
            _errorMessage = AppLocalizations.of(context).carPlacesSearchFailed,
      );
    }
  }

  Future<void> _centerOnMyLocation({bool silent = false}) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
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
      final gps = LatLng(position.latitude, position.longitude);
      _center = gps;
      _setDraft(
        CarPlace(
          latitude: gps.latitude,
          longitude: gps.longitude,
          label: _draft?.label ?? '',
        ),
      );
      if (GoogleMapsCapabilities.mapRenderingAvailable) {
        await _animateTo(gps);
      }
      await _reverseGeocode();
    } catch (_) {
      if (!silent && mounted) {
        // Permission / GPS failures are silent per spec.
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _confirm() async {
    if (_draft == null) return;
    await _flushPendingGeocode();
    if (!mounted || _draft == null) return;
    widget.onPickedForTest?.call(_draft!);
    if (!mounted) return;
    context.pop(_draft!);
  }

  Future<void> _flushPendingGeocode() async {
    if (_geocodeDebounce == null) return;
    _geocodeDebounce?.cancel();
    _geocodeDebounce = null;
    if (_ignoreMapEvents) return;
    await _reverseGeocode();
  }

  void _onConfirmPressed() => unawaited(_confirm());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardVisible = keyboardInset > 0;
    final sideBySide = GoogleMapsCapabilities.mapRenderingAvailable &&
        context.isLandscape &&
        context.screenSize.width >= AppBreakpoints.compact;
    final showMap = GoogleMapsCapabilities.mapRenderingAvailable;

    Widget buildPanel({
      required bool showDragHandle,
      required bool showTitle,
      ScrollController? scrollController,
      bool keyboardScrollPadding = false,
    }) {
      return _PickerPanel(
        title: widget.args.title,
        l10n: l10n,
        query: _query,
        focusNode: _focusNode,
        searching: _searching,
        isSearching: _isSearching,
        predictions: _predictions,
        errorMessage: _errorMessage,
        draft: _draft,
        initial: widget.args.initial,
        onQueryChanged: _onQueryChanged,
        onSelectPrediction: _selectPrediction,
        onConfirm: _onConfirmPressed,
        scrollController: scrollController,
        showDragHandle: showDragHandle,
        showTitle: showTitle,
        keyboardVisible: keyboardVisible,
        keyboardScrollPadding: keyboardScrollPadding,
      );
    }

    if (!showMap) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: Row(
                  children: [
                    AuthBackButton(onTap: () => context.pop()),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        widget.args.title,
                        style: AppTypography.title.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.args.showUseMyLocation)
                      _GpsFab(
                        loading: _locating,
                        onTap: () => unawaited(_centerOnMyLocation()),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: buildPanel(showDragHandle: false, showTitle: false),
              ),
            ],
          ),
        ),
      );
    }

    final mapLayer = _MapLayer(
      center: _center,
      onMapCreated: _onMapCreated,
      onCameraMove: (position) {
        if (!_ignoreMapEvents) {
          _center = position.target;
        }
      },
      onCameraIdle: _onCameraIdle,
    );

    if (sideBySide) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        body: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    mapLayer,
                    const _CenterPin(),
                    PositionedDirectional(
                      top: AppSpacing.sm,
                      start: AppSpacing.md,
                      child: AuthBackButton(
                        onTap: () => context.pop(),
                      ),
                    ),
                    if (widget.args.showUseMyLocation)
                      PositionedDirectional(
                        end: AppSpacing.md,
                        bottom: AppSpacing.md,
                        child: _GpsFab(
                          loading: _locating,
                          onTap: () => unawaited(_centerOnMyLocation()),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppBreakpoints.maxContentWidth,
                    ),
                    child: buildPanel(
                      showDragHandle: false,
                      showTitle: true,
                      keyboardScrollPadding: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final panelPeek = MediaQuery.sizeOf(context).height * _sheetPeek;
    final sheetMin =
        keyboardVisible ? _sheetMinKeyboard : _sheetMin;
    final sheetMax = keyboardVisible
        ? _sheetMaxKeyboard
        : (_isSearching ? _sheetExpanded : _sheetMaxIdle);
    final sheetSnapSizes = keyboardVisible
        ? const [_sheetPeekKeyboard, _sheetMaxKeyboard]
        : (_isSearching
            ? const [_sheetPeek, _sheetExpanded]
            : const [_sheetPeek, _sheetMaxIdle]);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          mapLayer,
          const _CenterPin(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Row(
                children: [
                  AuthBackButton(onTap: () => context.pop()),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.args.title,
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.args.showUseMyLocation && !keyboardVisible)
            PositionedDirectional(
              end: AppSpacing.md,
              bottom: panelPeek + AppSpacing.md,
              child: _GpsFab(
                loading: _locating,
                onTap: () => unawaited(_centerOnMyLocation()),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: keyboardInset,
            child: DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize:
                  keyboardVisible ? _sheetPeekKeyboard : _sheetPeek,
              minChildSize: sheetMin,
              maxChildSize: sheetMax,
              snap: true,
              snapSizes: sheetSnapSizes,
              builder: (context, scrollController) {
                return Material(
                  color: AppColors.bgCard,
                  elevation: 8,
                  shadowColor: Colors.black26,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.sheet),
                  ),
                  child: _PickerPanel(
                    title: widget.args.title,
                    l10n: l10n,
                    query: _query,
                    focusNode: _focusNode,
                    searching: _searching,
                    isSearching: _isSearching,
                    predictions: _predictions,
                    errorMessage: _errorMessage,
                    draft: _draft,
                    initial: widget.args.initial,
                    onQueryChanged: _onQueryChanged,
                    onSelectPrediction: _selectPrediction,
                    onConfirm: _onConfirmPressed,
                    scrollController: scrollController,
                    showDragHandle: true,
                    showTitle: false,
                    keyboardVisible: keyboardVisible,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MapLayer extends StatelessWidget {
  const _MapLayer({
    required this.center,
    required this.onMapCreated,
    required this.onCameraMove,
    required this.onCameraIdle,
  });

  final LatLng center;
  final ValueChanged<GoogleMapController> onMapCreated;
  final ValueChanged<CameraPosition> onCameraMove;
  final VoidCallback onCameraIdle;

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: 14),
      onMapCreated: onMapCreated,
      onCameraMove: onCameraMove,
      onCameraIdle: onCameraIdle,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
    );
  }
}

class _CenterPin extends StatelessWidget {
  const _CenterPin();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: 28),
          child: Icon(
            AppIcons.locationTo,
            size: 40,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _GpsFab extends StatelessWidget {
  const _GpsFab({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCard,
      elevation: 4,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? null : onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  AppIcons.locationFrom,
                  color: AppColors.primary,
                ),
        ),
      ),
    );
  }
}

class _PickerPanel extends StatelessWidget {
  const _PickerPanel({
    required this.title,
    required this.l10n,
    required this.query,
    required this.focusNode,
    required this.searching,
    required this.isSearching,
    required this.predictions,
    required this.errorMessage,
    required this.draft,
    required this.initial,
    required this.onQueryChanged,
    required this.onSelectPrediction,
    required this.onConfirm,
    this.scrollController,
    this.showDragHandle = true,
    this.showTitle = true,
    this.keyboardVisible = false,
    this.keyboardScrollPadding = false,
  });

  final String title;
  final AppLocalizations l10n;
  final TextEditingController query;
  final FocusNode focusNode;
  final bool searching;
  final bool isSearching;
  final List<PlacePrediction> predictions;
  final String? errorMessage;
  final CarPlace? draft;
  final CarPlace? initial;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<PlacePrediction> onSelectPrediction;
  final VoidCallback onConfirm;
  final ScrollController? scrollController;
  final bool showDragHandle;
  final bool showTitle;
  final bool keyboardVisible;
  final bool keyboardScrollPadding;

  @override
  Widget build(BuildContext context) {
    final draftLabel = draft?.displayLabel(l10n);
    final canConfirm = draft != null;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final listBottomPadding = keyboardScrollPadding && keyboardInset > 0
        ? keyboardInset + AppSpacing.sm
        : AppSpacing.sm;

    final bodyChildren = <Widget>[
      if (showDragHandle)
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.xs,
          ),
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
        ),
      if (showTitle)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            0,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Text(
            title,
            style: AppTypography.title.copyWith(fontWeight: FontWeight.w800),
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
                  controller: query,
                  focusNode: focusNode,
                  onChanged: onQueryChanged,
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              if (searching)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
      if (errorMessage != null)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Text(
            errorMessage!,
            style: AppTypography.caption.copyWith(color: AppColors.error),
          ),
        ),
      if (draftLabel != null && !isSearching && !keyboardVisible)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: _CurrentSelectionRow(
            caption: l10n.carPlaceCurrentSelection,
            label: draftLabel,
          ),
        ),
      ..._SearchResults.children(
        l10n: l10n,
        predictions: predictions,
        searching: searching,
        isSearching: isSearching,
        onSelect: onSelectPrediction,
      ),
      if (!isSearching && initial != null && draft == null && !keyboardVisible)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: _CurrentSelectionRow(
            caption: l10n.carPlaceCurrentSelection,
            label: initial!.displayLabel(l10n),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: EdgeInsetsDirectional.only(bottom: listBottomPadding),
            children: bodyChildren,
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: PrimaryButton(
            label: l10n.carConfirmLocation,
            onPressed: canConfirm ? onConfirm : null,
          ),
        ),
      ],
    );
  }
}

abstract final class _SearchResults {
  _SearchResults._();

  static List<Widget> children({
    required AppLocalizations l10n,
    required List<PlacePrediction> predictions,
    required bool searching,
    required bool isSearching,
    required ValueChanged<PlacePrediction> onSelect,
  }) {
    if (!isSearching) return const [];

    if (predictions.isEmpty && !searching) {
      return [
        Center(
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
                  style: AppTypography.body.copyWith(
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (predictions.isEmpty) return const [];

    return [
      for (var i = 0; i < predictions.length; i++) ...[
        if (i > 0)
          const Divider(
            height: 1,
            color: AppColors.hairline,
            indent: AppSpacing.md,
            endIndent: AppSpacing.md,
          ),
        _PredictionRow(
          description: predictions[i].description,
          onTap: () => onSelect(predictions[i]),
        ),
      ],
    ];
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
