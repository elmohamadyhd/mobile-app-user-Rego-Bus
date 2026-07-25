import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_icons.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/addresses/domain/entities/saved_address.dart';
import 'package:safaria/shared/widgets/skyline_float_card.dart';

/// One saved-address row in the addresses list.
class AddressCard extends StatelessWidget {
  const AddressCard({
    super.key,
    required this.address,
    required this.onTap,
    required this.onEdit,
    required this.iconTintIndex,
  });

  final SavedAddress address;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final int iconTintIndex;

  static const double _iconBoxSize = 42;

  Color _iconBackground(int index) {
    switch (index % 3) {
      case 0:
        return AppColors.primaryTint;
      case 1:
        return AppColors.secondaryTint;
      default:
        return AppColors.inputFill;
    }
  }

  Color _iconColor(int index) {
    switch (index % 3) {
      case 0:
        return AppColors.primary;
      case 1:
        return AppColors.secondary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = iconTintIndex % 3;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SkylineFloatCard(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: _iconBoxSize,
                    height: _iconBoxSize,
                    decoration: BoxDecoration(
                      color: _iconBackground(tint),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      AppIcons.locationTo,
                      size: 20,
                      color: _iconColor(tint),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.title.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          address.mapLocation.addressName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      AppIcons.edit,
                      color: AppColors.textMuted,
                    ),
                    onPressed: onEdit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
