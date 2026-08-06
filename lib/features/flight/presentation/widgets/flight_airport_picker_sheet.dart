import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_airport_suggestion.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Bottom-sheet picker backed by a debounced `GET /flights/airports/search`.
/// Structurally like `showBusCityPicker`, but the list comes from a live
/// network call instead of a client-filtered cached list.
Future<FlightAirportSuggestion?> showFlightAirportPicker(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<FlightAirportSuggestion>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _FlightAirportPickerSheet(title: title),
    ),
  );
}

class _FlightAirportPickerSheet extends ConsumerStatefulWidget {
  const _FlightAirportPickerSheet({required this.title});

  final String title;

  @override
  ConsumerState<_FlightAirportPickerSheet> createState() =>
      _FlightAirportPickerSheetState();
}

class _FlightAirportPickerSheetState
    extends ConsumerState<_FlightAirportPickerSheet> {
  static const _minChars = 2;
  static const _debounceDuration = Duration(milliseconds: 300);

  final _query = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<FlightAirportSuggestion>? _results;
  bool _loading = false;
  Object? _error;
  String? _lastTerm;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final term = value.trim();
    if (term.length < _minChars) {
      setState(() {
        _results = null;
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(_debounceDuration, () => _search(term));
  }

  Future<void> _search(String term) async {
    _lastTerm = term;
    try {
      final results = await ref
          .read(flightRepositoryProvider)
          .searchAirportSuggestions(term: term);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _retry() {
    final term = _lastTerm;
    if (term != null) _search(term);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
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
                      widget.title,
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(PhosphorIconsLight.x),
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
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    const Icon(
                      PhosphorIconsLight.magnifyingGlass,
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
                          hintText: l10n.flightAirportSearchHint,
                          hintStyle: AppTypography.body.copyWith(
                            color: AppColors.textMuted,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: AppColors.hairline, height: 1),
            Flexible(child: _body(l10n)),
          ],
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l10n) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.tripResultsError,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: _retry,
              child: Text(l10n.tripResultsRetry),
            ),
          ],
        ),
      );
    }
    final results = _results;
    if (results == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          l10n.flightAirportTypeToSearch,
          style: AppTypography.body.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          l10n.flightAirportSearchEmpty,
          style: AppTypography.body.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: results.length,
      itemBuilder: (context, index) {
        final airport = results[index];
        final subtitle = airport.isAllAirport
            ? l10n.flightAllAirportsIn(airport.city)
            : '${airport.city}, ${airport.country}';
        return ListTile(
          title: Text(airport.name, style: AppTypography.title),
          subtitle: Text(
            subtitle,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          trailing: Text(
            airport.iataCode,
            style: AppTypography.title.copyWith(fontWeight: FontWeight.w800),
          ),
          onTap: () => Navigator.of(context).pop(airport),
        );
      },
    );
  }
}
