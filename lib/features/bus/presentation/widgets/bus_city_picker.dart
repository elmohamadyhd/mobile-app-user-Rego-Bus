import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/bus_location.dart';
import 'package:rego/features/bus/presentation/providers/bus_locations_provider.dart';
import 'package:rego/l10n/app_localizations.dart';

/// Bottom-sheet picker backed by the cached `/buses/locations` list.
Future<BusLocation?> showBusCityPicker(
  BuildContext context, {
  required String title,
  int? excludeCityId,
}) {
  return showModalBottomSheet<BusLocation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: _BusCityPickerSheet(
        title: title,
        excludeCityId: excludeCityId,
      ),
    ),
  );
}

class _BusCityPickerSheet extends ConsumerStatefulWidget {
  const _BusCityPickerSheet({
    required this.title,
    this.excludeCityId,
  });

  final String title;
  final int? excludeCityId;

  @override
  ConsumerState<_BusCityPickerSheet> createState() =>
      _BusCityPickerSheetState();
}

class _BusCityPickerSheetState extends ConsumerState<_BusCityPickerSheet> {
  final _query = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _query.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<BusLocation> _filtered(
    List<BusLocation> locations,
    String languageCode,
  ) {
    return locations
        .where((l) => widget.excludeCityId == null || l.id != widget.excludeCityId)
        .where((l) => l.matchesQuery(_query.text, languageCode))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final locationsAsync = ref.watch(busLocationsProvider);
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
                padding: const EdgeInsets.symmetric(horizontal: 14),
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
                        onChanged: (_) => setState(() {}),
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
                          hintText: l10n.homeCitySearchHint,
                          hintStyle: AppTypography.body.copyWith(
                            color: AppColors.textMuted,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: AppColors.hairline, height: 1),
            Flexible(
              child: locationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _ErrorBody(
                  message: l10n.tripResultsError,
                  retryLabel: l10n.tripResultsRetry,
                  onRetry: () => ref.invalidate(busLocationsProvider),
                ),
                data: (locations) {
                  final filtered = _filtered(locations, languageCode);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          l10n.homeCitySearchEmpty,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final city = filtered[index];
                      return ListTile(
                        title: Text(
                          city.displayName(languageCode),
                          style: AppTypography.title,
                        ),
                        onTap: () => Navigator.of(context).pop(city),
                      );
                    },
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

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
