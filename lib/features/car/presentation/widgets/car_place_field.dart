import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/places/places_providers.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/car/domain/entities/car_place.dart';
import 'package:rego/features/car/presentation/car_place_picker_args.dart';
import 'package:rego/features/car/presentation/car_routes.dart';
import 'package:rego/l10n/app_localizations.dart';

class CarPlaceField extends ConsumerWidget {
  const CarPlaceField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.iconBg,
    required this.iconColor,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.showUseMyLocation = false,
  });

  final String label;
  final String placeholder;
  final Color iconBg;
  final Color iconColor;
  final IconData icon;
  final CarPlace? value;
  final ValueChanged<CarPlace?> onChanged;
  final bool showUseMyLocation;

  Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    if (!ref.read(placesClientProvider).isConfigured) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.carMapsNotConfigured),
            duration: const Duration(seconds: 2),
          ),
        );
      return;
    }

    final picked = await context.push<CarPlace>(
      CarRoutes.placePicker,
      extra: CarPlacePickerArgs(
        title: label,
        initial: value,
        showUseMyLocation: showUseMyLocation,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final displayText = value != null ? value!.displayLabel(l10n) : placeholder;
    final hasValue = value != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPicker(context, ref),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 56, 14),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.overline.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      displayText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.title.copyWith(
                        color: hasValue
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
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
