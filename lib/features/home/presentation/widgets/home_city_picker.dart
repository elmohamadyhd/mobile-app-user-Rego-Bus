import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/l10n/app_localizations.dart';

/// A bus city. Static set for now; wire `/cities` later.
class HomeCity {
  const HomeCity({required this.id, required this.apiName});

  final String id;
  final String apiName;

  String label(AppLocalizations l10n) => switch (id) {
        'cairo' => l10n.homeCityCairo,
        'alexandria' => l10n.homeCityAlexandria,
        'luxor' => l10n.homeCityLuxor,
        'aswan' => l10n.homeCityAswan,
        _ => apiName,
      };

  bool matchesQuery(AppLocalizations l10n, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return label(l10n).toLowerCase().contains(q) ||
        apiName.toLowerCase().contains(q);
  }
}

const kHomeCities = <HomeCity>[
  HomeCity(id: 'cairo', apiName: 'Cairo'),
  HomeCity(id: 'alexandria', apiName: 'Alexandria'),
  HomeCity(id: 'luxor', apiName: 'Luxor'),
  HomeCity(id: 'aswan', apiName: 'Aswan'),
];

const kDefaultFromCity = HomeCity(id: 'cairo', apiName: 'Cairo');
const kDefaultToCity = HomeCity(id: 'alexandria', apiName: 'Alexandria');

/// Bottom-sheet picker; resolves to the chosen [HomeCity] or null.
Future<HomeCity?> showHomeCityPicker(
  BuildContext context, {
  required String title,
  HomeCity? exclude,
}) {
  final cities = exclude == null
      ? kHomeCities
      : kHomeCities.where((c) => c.id != exclude.id).toList();

  return showModalBottomSheet<HomeCity>(
    context: context,
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
      child: _HomeCityPickerSheet(title: title, cities: cities),
    ),
  );
}

class _HomeCityPickerSheet extends StatefulWidget {
  const _HomeCityPickerSheet({
    required this.title,
    required this.cities,
  });

  final String title;
  final List<HomeCity> cities;

  @override
  State<_HomeCityPickerSheet> createState() => _HomeCityPickerSheetState();
}

class _HomeCityPickerSheetState extends State<_HomeCityPickerSheet> {
  final _query = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _query.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<HomeCity> _filtered(AppLocalizations l10n) {
    final q = _query.text.trim();
    return widget.cities.where((c) => c.matchesQuery(l10n, q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filtered = _filtered(l10n);
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
              child: filtered.isEmpty
                  ? Center(
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
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final city = filtered[index];
                        return ListTile(
                          title: Text(
                            city.label(l10n),
                            style: AppTypography.title,
                          ),
                          onTap: () => Navigator.of(context).pop(city),
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
